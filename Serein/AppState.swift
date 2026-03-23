// AppState.swift
// Life Compass — Global Application State
//
// Single source of truth for all data.
// Injected at the root via .environmentObject(appState)
// and consumed by any view via @EnvironmentObject var appState: AppState.

import SwiftUI
import Combine
import UserNotifications

// ============================================================
// MARK: - MilestoneToggleResult
// ============================================================

enum MilestoneToggleResult {
    case noChange
    case unchecked
    case completed(xp: Double, goalComplete: Bool)
}

// ============================================================
// MARK: - AppState
// ============================================================

@MainActor
final class AppState: ObservableObject {

    // ── Core data ─────────────────────────────────────────────
    @Published var userProfile:     UserProfile?       = nil
    @Published var lifeAreas:       [LifeArea]         = []
    @Published var goals:           [Goal]             = []   // real goals only — persisted
    @Published var reflections:     [WeeklyReflection] = []
    @Published var dailyActivities: [DailyActivity]    = []
    @Published var futureVision:    FutureVision       = .placeholder

    // ── Mock goals — transient, never persisted ────────────────
    // Generated per life area when that area has no real goals.
    // Auto-disappear the moment a real goal is added.
    var mockGoals: [Goal] {
        lifeAreas.flatMap { area -> [Goal] in
            let hasReal = goals.contains {
                $0.lifeAreaId == area.id && !$0.isArchived
            }
            return hasReal ? [] : MockGoalProvider.goals(for: area.id)
        }
    }

    /// Goals as shown in the UI: real goals merged with per-area example goals.
    var displayGoals: [Goal] { goals + mockGoals }

    // ── Derived state ─────────────────────────────────────────
    @Published private(set) var todaySteps:                 [TodayStepItem] = []
    @Published private(set) var streak:                     Int    = 0
    @Published private(set) var dailyFocusGoal:             Goal?  = nil
    @Published private(set) var hasActivityToday:           Bool   = false
    @Published private(set) var totalXPToday:               Double = 0
    @Published private(set) var shouldShowReflectionPrompt: Bool   = false

    // ── Cross-tab navigation ──────────────────────────────────
    /// Set by LifeDashboardView when the user taps a life-area card.
    /// GoalsView observes this and scrolls to the matching area section.
    @Published var dashboardFocusAreaId: UUID? = nil

    // ── App Store review ──────────────────────────────────────
    /// Fires once — after the user saves their first step in their first goal.
    /// MainTabView watches this and calls requestReview().
    @Published var shouldRequestReview: Bool = false

    // ── App settings ──────────────────────────────────────────
    @AppStorage("lc.onboardingComplete") var onboardingComplete: Bool = false
    @AppStorage("lc.currentAge")         var currentAge: Int = 25
    @AppStorage("lc.reviewRequested")    var reviewRequested:    Bool = false

    // ── Init ──────────────────────────────────────────────────
    init() { load() }

    // ============================================================
    // MARK: - Load
    // ============================================================

    func load() {
        userProfile = UserProfile.load()

        // Merge static area definitions with persisted progress
        let progress = LifeArea.loadProgress()
        lifeAreas    = LifeArea.samples.map { area in
            guard let p = progress[area.id] else { return area }
            var updated       = area
            updated.level     = p.level
            updated.currentXP = p.currentXP
            updated.maxXP     = p.maxXP
            return updated
        }

        goals           = Goal.loadPersisted() ?? Goal.samples
        reflections     = WeeklyReflection.loadAll()
        dailyActivities = DailyActivity.loadAll()
        futureVision    = FutureVision.load()
        recompute()
    }

    // ============================================================
    // MARK: - Daily Engine
    // ============================================================

    /// Call on launch and every foreground transition.
    /// Promotes tomorrow→today steps and resets recurring steps when a new day begins.
    func handleNewDayIfNeeded() {
        guard DailyManager.isNewDay() else { return }
        promoteTomorrowSteps()
        resetRecurringSteps()
        DailyManager.markToday()
        persistGoals()
        recompute()
    }

    func promoteTomorrowSteps() {
        for i in goals.indices {
            for j in goals[i].steps.indices {
                if goals[i].steps[j].type == .tomorrow {
                    goals[i].steps[j].type = .today
                }
            }
        }
    }

    func resetRecurringSteps() {
        for i in goals.indices {
            for j in goals[i].steps.indices {
                if goals[i].steps[j].type == .recurringDaily {
                    goals[i].steps[j].isCompleted = false
                    goals[i].steps[j].completedAt = nil
                }
            }
        }
    }

    // ============================================================
    // MARK: - Goal Step Mutations
    // ============================================================

    func addStep(_ step: GoalStep, to goalId: UUID) {
        // Capture whether this is the very first step the user has ever added,
        // before mutating the array. One-shot: guarded by the persisted flag.
        let isFirstStep = !reviewRequested && goals.flatMap(\.steps).isEmpty

        guard let idx = goals.firstIndex(where: { $0.id == goalId }) else { return }
        withAnimation(.lcSoftAppear) { goals[idx].steps.append(step) }
        persistGoals()
        recompute()

        if isFirstStep {
            reviewRequested = true           // persisted — never fires again
            // Small delay so the AddStep sheet dismisses and the UI settles
            // before the system dialog appears.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.shouldRequestReview = true
            }
        }
    }

    func completeStep(goalId: UUID, stepId: UUID) {
        guard let goalIdx = goals.firstIndex(where: { $0.id == goalId }),
              let stepIdx = goals[goalIdx].steps.firstIndex(where: { $0.id == stepId })
        else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            goals[goalIdx].steps[stepIdx].isCompleted = true
            goals[goalIdx].steps[stepIdx].completedAt = Date()
        }

        let lifeAreaId = goals[goalIdx].lifeAreaId
        persistGoals()
        recordStepCompletion(xp: 25, lifeAreaId: lifeAreaId)
        // recompute() called inside recordStepCompletion
    }

    func uncompleteStep(goalId: UUID, stepId: UUID) {
        guard let goalIdx = goals.firstIndex(where: { $0.id == goalId }),
              let stepIdx = goals[goalIdx].steps.firstIndex(where: { $0.id == stepId })
        else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            goals[goalIdx].steps[stepIdx].isCompleted = false
            goals[goalIdx].steps[stepIdx].completedAt = nil
        }
        persistGoals()
        recompute()
    }

    // ============================================================
    // MARK: - Goal Mutations
    // ============================================================

    func updateGoal(_ updated: Goal) {
        guard let idx = goals.firstIndex(where: { $0.id == updated.id }) else { return }
        withAnimation(.lcSoftAppear) { goals[idx] = updated }
        persistGoals()
        recompute()
    }

    func addGoal(_ goal: Goal) {
        // Mock goals for this area auto-disappear because displayGoals
        // recomputes from the real goals array — no cleanup needed.
        var realGoal = goal
        realGoal.isMock = false
        withAnimation(.lcSoftAppear) { goals.append(realGoal) }
        persistGoals()
        recompute()
    }

    /// True when the user is allowed to add another goal to the given life area.
    func canAddGoal(in areaId: UUID) -> Bool {
        FeatureAccessManager.shared.canAddGoal(in: areaId, goals: goals)
    }

    func markAsFocus(_ goal: Goal) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.lcCardLift) {
            for i in goals.indices { goals[i].isFocusGoal = false }
            if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[idx].isFocusGoal = true
            }
        }
        persistGoals()
        recompute()
    }

    func pinGoal(_ goal: Goal) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let idx = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        withAnimation(.lcCardLift) {
            let nowPinned = !goals[idx].isPinned
            goals[idx].isPinned = nowPinned
            if nowPinned {
                let maxOrder = goals.filter(\.isPinned).map(\.orderIndex).max() ?? -1
                goals[idx].orderIndex = maxOrder + 1
            }
        }
        persistGoals()
        recompute()
    }

    func archiveGoal(_ goal: Goal) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard let idx = goals.firstIndex(where: { $0.id == goal.id }) else { return }
        withAnimation(.lcSoftAppear) { goals[idx].isArchived = true }
        persistGoals()
        recompute()
    }

    func deleteGoal(_ goal: Goal) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.lcSoftAppear) {
            goals.removeAll { $0.id == goal.id }
        }
        persistGoals()
        recompute()
    }

    // ============================================================
    // MARK: - Reflection
    // ============================================================

    func saveReflection(_ reflection: WeeklyReflection) {
        var all = reflections
        let cal = Calendar.current
        all.removeAll { cal.isDate($0.weekStartDate, inSameDayAs: reflection.weekStartDate) }
        all.append(reflection)
        reflections = all
        WeeklyReflection.save(all)
        recordXP(reflection.xpEarned)
        recompute()
    }

    var reflectionStreak: Int {
        WeeklyReflection.currentStreak(from: reflections)
    }

    // ============================================================
    // MARK: - Future Vision
    // ============================================================

    func saveFutureVision(_ vision: FutureVision) {
        futureVision = vision
        vision.save()
    }

    // ============================================================
    // MARK: - Daily Activity + XP
    // ============================================================

    /// Record a completed milestone: updates daily activity AND awards XP to the life area.
    func recordMilestoneCompletion(xp: Double, lifeAreaId: UUID) {
        recordDailyMilestone(xp: xp)
        awardXP(xp, to: lifeAreaId)
        recompute()
    }

    /// Generic XP recording (e.g. for reflections) — no life-area attribution.
    func recordXP(_ xp: Double) {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = dailyActivities.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) {
            dailyActivities[idx].xpEarned += xp
        } else {
            dailyActivities.append(DailyActivity(date: today, xpEarned: xp))
        }
        DailyActivity.save(dailyActivities)
        recompute()
    }

    // ============================================================
    // MARK: - User Profile
    // ============================================================

    func saveUserProfile(_ profile: UserProfile) {
        userProfile = profile
        profile.save()
    }

    // ============================================================
    // MARK: - Reset
    // ============================================================

    func resetAllData() {
        userProfile     = nil
        lifeAreas       = LifeArea.samples
        goals           = Goal.samples
        reflections     = []
        dailyActivities = []
        futureVision    = .placeholder
        onboardingComplete = false

        let keys = ["lc.goals", "lc.dailyActivities",
                    "lc.futureVision", "lc.reflections",
                    DailyManager.lastActiveDateKey]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        LifeArea.clearProgress()
        UserProfile.delete()

        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        persistGoals()
        recompute()
    }

    // ============================================================
    // MARK: - Helpers (public)
    // ============================================================

    func area(for goal: Goal) -> LifeArea? {
        lifeAreas.first { $0.id == goal.lifeAreaId }
    }

    var activeGoalsCount: Int {
        goals.filter { !$0.isComplete && !$0.isArchived }.count
    }

    var completedGoalsCount: Int {
        goals.filter { $0.isComplete && !$0.isArchived }.count
    }

    var overallBalance: Double {
        guard !lifeAreas.isEmpty else { return 0 }
        return lifeAreas.map(\.progress).reduce(0, +) / Double(lifeAreas.count)
    }

    var overallLevel: Int {
        guard !lifeAreas.isEmpty else { return 0 }
        return lifeAreas.map(\.level).reduce(0, +) / lifeAreas.count
    }

    // ============================================================
    // MARK: - Daily Focus Selection
    // ============================================================

    func selectDailyFocusGoal() -> Goal? {
        let active = goals.filter { !$0.isComplete && !$0.isArchived }
        // Pinned goals take top priority
        if let pinned = active.first(where: { $0.isPinned }) { return pinned }
        // Manual focus next
        if let manual = active.first(where: { $0.isFocusGoal }) { return manual }
        // Fall back to least-progress goal that has remaining milestones
        return active
            .filter { !$0.milestones.filter { !$0.isCompleted }.isEmpty }
            .min(by: { $0.progress < $1.progress })
    }

    // ============================================================
    // MARK: - Private — Today Steps
    // ============================================================

    private func buildTodaySteps() -> [TodayStepItem] {
        var items: [TodayStepItem] = []
        for goal in goals where !goal.isArchived && !goal.isComplete {
            guard let area = lifeAreas.first(where: { $0.id == goal.lifeAreaId }) else { continue }
            for step in goal.steps.forToday() {
                items.append(TodayStepItem(id: step.id, goal: goal, area: area, step: step))
            }
        }

        // Sort: pinned goal first → step type priority → createdAt
        let sorted = items.sorted { a, b in
            if a.goal.isPinned != b.goal.isPinned { return a.goal.isPinned }
            if a.step.type.sortPriority != b.step.type.sortPriority {
                return a.step.type.sortPriority < b.step.type.sortPriority
            }
            return a.step.createdAt < b.step.createdAt
        }

        return Array(sorted.prefix(5))  // max 5 actionable items
    }

    // ============================================================
    // MARK: - Private — Step XP
    // ============================================================

    private func recordStepCompletion(xp: Double, lifeAreaId: UUID) {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = dailyActivities.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) {
            dailyActivities[idx].completedStepCount += 1
            dailyActivities[idx].xpEarned += xp
        } else {
            dailyActivities.append(
                DailyActivity(date: today, completedStepCount: 1, xpEarned: xp)
            )
        }
        DailyActivity.save(dailyActivities)
        awardXP(xp, to: lifeAreaId)
        recompute()
    }

    // ============================================================
    // MARK: - Private — Daily Activity
    // ============================================================

    private func recordDailyMilestone(xp: Double) {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = dailyActivities.firstIndex(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) {
            dailyActivities[idx].completedMilestoneCount += 1
            dailyActivities[idx].xpEarned += xp
        } else {
            dailyActivities.append(
                DailyActivity(date: today, completedMilestoneCount: 1, xpEarned: xp)
            )
        }
        DailyActivity.save(dailyActivities)
    }

    // ============================================================
    // MARK: - Private — Life Area XP
    // ============================================================

    private func awardXP(_ xp: Double, to lifeAreaId: UUID) {
        guard let idx = lifeAreas.firstIndex(where: { $0.id == lifeAreaId }) else { return }

        withAnimation(.lcProgressFill) {
            lifeAreas[idx].currentXP += xp
            while lifeAreas[idx].currentXP >= lifeAreas[idx].maxXP {
                lifeAreas[idx].currentXP -= lifeAreas[idx].maxXP
                lifeAreas[idx].level     += 1
                lifeAreas[idx].maxXP      = Double(lifeAreas[idx].level + 1) * 600
            }
        }

        LifeArea.saveProgress(lifeAreas)
    }

    // ============================================================
    // MARK: - Private — Recompute
    // ============================================================

    private func recompute() {
        let todayActivity = dailyActivities.first { $0.isToday }
        todaySteps                 = buildTodaySteps()
        streak                     = computeStreak()
        dailyFocusGoal             = selectDailyFocusGoal()
        hasActivityToday           = (todayActivity?.completedMilestoneCount ?? 0) > 0
                                  || (todayActivity?.completedStepCount ?? 0) > 0
        totalXPToday               = todayActivity?.xpEarned ?? 0
        shouldShowReflectionPrompt = computeReflectionPrompt()
    }

    private func computeStreak() -> Int {
        let cal    = Calendar.current
        let today  = cal.startOfDay(for: Date())
        let activeDays = Set(
            dailyActivities
                .filter { $0.completedMilestoneCount > 0 || $0.completedStepCount > 0 }
                .map    { cal.startOfDay(for: $0.date) }
        )

        var count = 0
        var check = today

        if activeDays.contains(check) {
            count = 1
            check = cal.date(byAdding: .day, value: -1, to: check)!
        } else {
            check = cal.date(byAdding: .day, value: -1, to: check)!
        }

        while activeDays.contains(check) {
            count += 1
            check  = cal.date(byAdding: .day, value: -1, to: check)!
        }

        return count
    }

    private func computeReflectionPrompt() -> Bool {
        let cal = Calendar.current
        guard let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: Date()) else { return false }
        let recentActive = dailyActivities.filter {
            $0.date >= sevenDaysAgo
            && ($0.completedMilestoneCount > 0 || $0.completedStepCount > 0)
        }
        guard recentActive.count >= 3 else { return false }
        let weekStart = cal.startOfWeek(for: Date())
        return !reflections.contains { $0.weekStartDate >= weekStart }
    }

    private func persistGoals() {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        UserDefaults.standard.set(data, forKey: "lc.goals")
    }
}

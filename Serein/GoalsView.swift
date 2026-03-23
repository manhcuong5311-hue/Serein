// GoalsView.swift
// Life Compass — Goals Screen
//
// Goals feel like life-direction anchors, not a to-do list.
// All data sourced from AppState via @EnvironmentObject.
//
// Layout
//   📌 Pinned section  — sorted by orderIndex (swipe → unpin)
//   Active sections    — grouped by life area (swipe → pin or archive)
//   Completed section  — collapsible
//
// Interactions
//   Tap card           → GoalDetailView (push)
//   Swipe leading (→)  → Pin / Unpin
//   Swipe trailing (←) → Archive

import SwiftUI

// ============================================================
// MARK: - GoalsView
// ============================================================

struct GoalsView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject private var access = FeatureAccessManager.shared

    @State private var navItem:     GoalNavItem?
    @State private var appeared:    Bool = false
    @State private var showAddGoal: Bool = false
    @State private var showPremium: Bool = false
    @State private var showEditGoal:   Bool    = false
    @State private var goalToEdit:     Goal?   = nil
    @State private var showDeleteAlert: Bool   = false
    @State private var goalToDelete:   Goal?   = nil

    // ── Computed from AppState ─────────────────────────────────
    // Pinned sections use real goals only (mocks can't be pinned).

    private var pinnedGoals: [Goal] {
        appState.goals
            .filter { $0.isPinned && !$0.isArchived && !$0.isComplete }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private var activeGroups: [GoalGroup] {
        buildGroups(from: appState.displayGoals.filter { !$0.isArchived && !$0.isComplete && !$0.isPinned })
    }

    private var completedGoals: [Goal] {
        appState.goals.filter { $0.isComplete && !$0.isArchived }
    }

    // Stats count real goals only — mocks are not user achievements.
    private var totalActive:    Int { appState.goals.filter { !$0.isArchived && !$0.isComplete }.count }
    private var totalCompleted: Int { completedGoals.count }

    var body: some View {
        NavigationStack {
            ZStack {
                LCBackground(showNoise: true)

                ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: LCSpacing.xl) {

                        GoalsScreenHeader(
                            totalCompleted: totalCompleted,
                            totalActive:    totalActive,
                            appeared:       appeared,
                            onAdd: {
                                // Check global premium gate — user can always
                                // reach AddGoalView; per-area gate is checked there.
                                showAddGoal = true
                            }
                        )

                        if !appeared {
                            GoalsSkeletonSection()
                                .softAppear(delay: 0.05)
                        } else if appState.displayGoals.filter({ !$0.isArchived }).isEmpty {
                            GoalsEmptyState(onAdd: { showAddGoal = true })
                                .softAppear(delay: 0.10)
                        } else {

                            // ── Pinned Goals section ───────────────
                            if !pinnedGoals.isEmpty {
                                PinnedGoalsSection(
                                    goals:     pinnedGoals,
                                    lifeAreas: appState.lifeAreas,
                                    onTap:     { goal in
                                        if let area = appState.area(for: goal) {
                                            navItem = GoalNavItem(goal: goal, area: area)
                                        }
                                    },
                                    onUnpin:   { appState.pinGoal($0) },
                                    onArchive: { appState.archiveGoal($0) }
                                )
                                .softAppear(delay: 0.14)
                            }

                            // ── Active goal sections (by area) ─────
                            ForEach(Array(activeGroups.enumerated()), id: \.element.id) { sIdx, group in
                                GoalsSectionView(
                                    group:      group,
                                    realGoals:  appState.goals,
                                    baseDelay:  0.20 + Double(sIdx) * 0.10,
                                    onTap: { goal in
                                        if goal.isMock {
                                            // Mock tap → create a real goal in this area
                                            showAddGoal = true
                                        } else {
                                            navItem = GoalNavItem(goal: goal, area: group.area)
                                        }
                                    },
                                    onPin:     { appState.pinGoal($0) },
                                    onArchive: { appState.archiveGoal($0) },
                                    onAddGoal: {
                                        if access.canAddGoal(in: group.area.id, goals: appState.goals) {
                                            showAddGoal = true
                                        } else {
                                            showPremium = true
                                        }
                                    },
                                    onEdit: { goal in goalToEdit = goal; showEditGoal = true },
                                    onDelete: { goal in goalToDelete = goal; showDeleteAlert = true }
                                )
                                .id("area-\(group.area.id)")
                            }

                            // ── Completed section ──────────────────
                            if !completedGoals.isEmpty {
                                CompletedGoalsSection(
                                    goals:     completedGoals,
                                    lifeAreas: appState.lifeAreas,
                                    onTap:     { goal in
                                        if let area = appState.area(for: goal) {
                                            navItem = GoalNavItem(goal: goal, area: area)
                                        }
                                    }
                                )
                                .softAppear(delay: 0.50)
                            }
                        }
                    }
                    .padding(.horizontal, LCSpacing.md)
                    .padding(.top, LCSpacing.xl)
                    .padding(.bottom, LCSpacing.xxl)
                }
                .refreshable { appState.load() }
                .onChange(of: appState.dashboardFocusAreaId) { _, focusId in
                    guard let id = focusId else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.lcSoftAppear) {
                            proxy.scrollTo("area-\(id)", anchor: .top)
                        }
                        appState.dashboardFocusAreaId = nil
                    }
                }
            } // ScrollViewReader
            } // ZStack
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddGoal) {
                AddGoalView()
                    .environmentObject(appState)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showPremium) {
                PremiumView()
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showEditGoal) {
                if let goal = goalToEdit,
                   let area = appState.area(for: goal) {
                    EditGoalSheet(goal: goal, area: area) { updated in
                        appState.updateGoal(updated)
                    }
                    .environmentObject(appState)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.medium, .large])
                }
            }
            .confirmationDialog("Delete Goal?", isPresented: $showDeleteAlert, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let goal = goalToDelete {
                        appState.deleteGoal(goal)
                        goalToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { goalToDelete = nil }
            } message: {
                Text("This will permanently remove the goal and all its steps. This cannot be undone.")
            }
            .navigationDestination(item: $navItem) { item in
                GoalDetailView(
                    goal: item.goal,
                    area: item.area,
                    onGoalUpdated:        { appState.updateGoal($0) },
                    onMilestoneCompleted: { xp, areaId in appState.recordMilestoneCompletion(xp: xp, lifeAreaId: areaId) },
                    onStepCompleted:      { goalId, stepId in appState.recordStepActivity(goalId: goalId, stepId: stepId) }
                )
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.lcSoftAppear) { appeared = true }
        }
    }

    // ── Private helper ────────────────────────────────────────

    private func buildGroups(from source: [Goal]) -> [GoalGroup] {
        let byArea = Dictionary(grouping: source, by: \.lifeAreaId)
        return appState.lifeAreas.compactMap { area in
            guard let areaGoals = byArea[area.id], !areaGoals.isEmpty else { return nil }
            return GoalGroup(area: area, goals: areaGoals)
        }
    }
}

// ============================================================
// MARK: - Header
// ============================================================

private struct GoalsScreenHeader: View {
    let totalCompleted: Int
    let totalActive:    Int
    let appeared:       Bool
    let onAdd:          () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("Goals")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .softAppear(delay: 0.04)

                Group {
                    if appeared {
                        Text("\(totalCompleted) completed · \(totalActive) in progress")
                    } else {
                        Text("Your aspirations, made visible.")
                    }
                }
                .font(LCFont.insight)
                .foregroundStyle(Color.lcTextTertiary)
                .softAppear(delay: 0.10)
            }

            Spacer()

            Button(action: onAdd) {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("New Goal")
                        .font(LCFont.insight)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color.lcTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.lcPrimary.opacity(0.18))
                        .overlay(Capsule().strokeBorder(Color.lcPrimary.opacity(0.35), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
            .softAppear(delay: 0.12)
        }
    }
}

// ============================================================
// MARK: - Pinned Goals Section
// ============================================================

private struct PinnedGoalsSection: View {
    let goals:     [Goal]
    let lifeAreas: [LifeArea]
    let onTap:     (Goal) -> Void
    let onUnpin:   (Goal) -> Void
    let onArchive: (Goal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            SectionHeader(
                title:    "Pinned",
                subtitle: "\(goals.count) goal\(goals.count == 1 ? "" : "s")",
                overline: "PRIORITY"
            )

            ForEach(Array(goals.enumerated()), id: \.element.id) { idx, goal in
                if let area = lifeAreas.first(where: { $0.id == goal.lifeAreaId }) {
                    SwipeGoalCard(
                        goal:      goal,
                        area:      area,
                        isPinned:  true,
                        onTap:     { onTap(goal) },
                        onPin:     { onUnpin(goal) },   // toggle: unpins
                        onArchive: { onArchive(goal) }
                    )
                    .softAppear(delay: 0.06 + Double(idx) * 0.06)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Active Goals Section (by Area)
// ============================================================

private struct GoalsSectionView: View {
    let group:     GoalGroup
    let realGoals: [Goal]      // real (non-mock) goals — for usage badge
    let baseDelay: Double
    let onTap:     (Goal) -> Void
    let onPin:     (Goal) -> Void
    let onArchive: (Goal) -> Void
    let onAddGoal: () -> Void
    var onEdit:    (Goal) -> Void = { _ in }
    var onDelete:  (Goal) -> Void = { _ in }

    @ObservedObject private var access = FeatureAccessManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            let done    = group.goals.filter { $0.isComplete && !$0.isMock }.count
            let total   = group.goals.filter { !$0.isMock }.count
            let usage   = access.goalUsage(in: group.area.id, goals: realGoals)
            let canAdd  = access.canAddGoal(in: group.area.id, goals: realGoals)

            HStack(alignment: .bottom) {
                SectionHeader(
                    title:    group.area.title,
                    subtitle: total > 0 ? "\(done) of \(total) complete" : "No goals yet",
                    overline: "LIFE AREA"
                )

                Spacer()

                // Usage badge (free tier) or add button (premium)
                if !access.isPremium, let limit = usage.limit {
                    GoalUsageBadge(used: usage.used, limit: limit, canAdd: canAdd) {
                        onAddGoal()
                    }
                } else if access.isPremium && canAdd {
                    Button(action: onAddGoal) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(group.area.accent.opacity(0.70))
                    }
                    .buttonStyle(.plain)
                }
            }
            .softAppear(delay: baseDelay)

            ForEach(Array(group.goals.enumerated()), id: \.element.id) { cIdx, goal in
                SwipeGoalCard(
                    goal:      goal,
                    area:      group.area,
                    isPinned:  false,
                    onTap:     { onTap(goal) },
                    onPin:     { if !goal.isMock { onPin(goal) } },
                    onArchive: { if !goal.isMock { onArchive(goal) } },
                    onEdit:    { if !goal.isMock { onEdit(goal) } },
                    onDelete:  { if !goal.isMock { onDelete(goal) } }
                )
                .softAppear(delay: baseDelay + 0.06 + Double(cIdx) * 0.07)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 10)),
                    removal:   .opacity
                ))
            }
        }
    }
}

// ── Goal Usage Badge ───────────────────────────────────────────
private struct GoalUsageBadge: View {
    let used:   Int
    let limit:  Int
    let canAdd: Bool
    let onTap:  () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if !canAdd {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.lcGold)
                }
                Text(canAdd ? "\(used)/\(limit)" : "Upgrade")
                    .font(LCFont.overline)
                    .foregroundStyle(canAdd ? Color.lcTextTertiary : Color.lcGold)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(canAdd
                          ? Color.white.opacity(0.06)
                          : Color.lcGold.opacity(0.10))
                    .overlay(Capsule().strokeBorder(
                        canAdd ? Color.white.opacity(0.10) : Color.lcGold.opacity(0.28),
                        lineWidth: 0.5
                    ))
            )
        }
        .buttonStyle(.plain)
        .alignmentGuide(.bottom) { d in d[.bottom] }
    }
}

// ============================================================
// MARK: - Swipe Goal Card
// ============================================================

private struct SwipeGoalCard: View {
    let goal:      Goal
    let area:      LifeArea
    let isPinned:  Bool
    let onTap:     () -> Void
    let onPin:     () -> Void
    let onArchive: () -> Void
    var onEdit:    (() -> Void)? = nil
    var onDelete:  (() -> Void)? = nil

    @State private var offset:  CGFloat = 0
    private let threshold: CGFloat = 72
    private let maxReveal: CGFloat = 88

    // Mock goals are not swipeable — they are read-only examples.
    private var swipeEnabled: Bool { !goal.isMock }

    var body: some View {
        ZStack(alignment: .leading) {
            if swipeEnabled {
                // Leading action — Pin / Unpin
                HStack {
                    SwipeActionChip(
                        icon:  isPinned ? "pin.slash.fill" : "pin.fill",
                        label: isPinned ? "Unpin" : "Pin",
                        color: Color.lcGold
                    )
                    .opacity(offset > 0 ? Double(offset / maxReveal) : 0)
                    Spacer()
                }

                // Trailing action — Archive
                HStack {
                    Spacer()
                    SwipeActionChip(icon: "archivebox.fill", label: "Archive", color: Color.lcPrimary)
                        .opacity(offset < 0 ? Double(-offset / maxReveal) : 0)
                }
            }

            // Card
            GoalCard(
                goal:      goal,
                area:      area,
                onTap:     onTap,
                onEdit:    onEdit,
                onDelete:  onDelete,
                onPin:     { onPin() },
                onArchive: { onArchive() }
            )
            .offset(x: offset)
                .gesture(
                    swipeEnabled
                    ? DragGesture(minimumDistance: 18)
                        .onChanged { v in
                            let dx = v.translation.width
                            offset = dx > 0
                                ? min(dx, maxReveal)
                                : max(dx, -maxReveal)
                        }
                        .onEnded { v in
                            let dx = v.translation.width
                            withAnimation(.lcCardLift) { offset = 0 }
                            if dx > threshold       { onPin()     }
                            else if dx < -threshold { onArchive() }
                        }
                    : nil
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct SwipeActionChip: View {
    let icon:  String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 16, weight: .medium))
            Text(label).font(LCFont.overline)
        }
        .foregroundStyle(color)
        .frame(width: 80)
    }
}

// ============================================================
// MARK: - GoalCard (public — reused in Dashboard)
// ============================================================

struct GoalCard: View {
    let goal:  Goal
    let area:  LifeArea
    var onTap:     () -> Void = {}
    var onEdit:    (() -> Void)? = nil
    var onDelete:  (() -> Void)? = nil
    var onPin:     (() -> Void)? = nil
    var onArchive: (() -> Void)? = nil

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            GlassCard(
                glowColor:   area.accent,
                glowOpacity: pressed ? 0.28 : (goal.isMock ? 0.06 : 0.13)
            ) {
                VStack(alignment: .leading, spacing: 0) {

                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: area.icon)
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(area.accent.opacity(0.75))
                        Text(area.title.uppercased())
                            .font(LCFont.overline)
                            .foregroundStyle(Color.lcTextTertiary)
                        if goal.isMock {
                            // "Example" badge replaces pin/focus indicators
                            Text("Example")
                                .font(LCFont.overline)
                                .foregroundStyle(Color.lcTextTertiary.opacity(0.60))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Color.white.opacity(0.07))
                                )
                        } else if goal.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.lcGold.opacity(0.85))
                        } else if goal.isFocusGoal {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.lcGold)
                        }
                        Spacer(minLength: 0)
                        if !goal.isMock {
                            GoalXPBadge(xp: goal.xpReward, completed: goal.isComplete)
                        }
                    }

                    Spacer(minLength: LCSpacing.sm)

                    Text(goal.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            goal.isComplete ? Color.lcTextSecondary : Color.lcTextPrimary
                        )
                        .lineLimit(2)
                        .strikethrough(goal.isComplete, color: Color.lcTextTertiary)
                        .multilineTextAlignment(.leading)

                    if let why = goal.why {
                        Spacer(minLength: 8)
                        Text(why)
                            .font(LCFont.insight)
                            .italic()
                            .foregroundStyle(Color.lcTextSecondary.opacity(0.75))
                            .lineLimit(2)
                            .lineSpacing(3)
                    }

                    Spacer(minLength: LCSpacing.sm)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(goal.milestoneLabel)
                                .font(LCFont.insight)
                                .foregroundStyle(Color.lcTextSecondary)
                            Spacer()
                            Text("\(Int(goal.progress * 100))%")
                                .font(LCFont.overline)
                                .foregroundStyle(area.accent.opacity(0.80))
                        }
                        ProgressBar(
                            value:    Double(goal.completedMilestones),
                            maximum:  Double(max(goal.totalMilestones, 1)),
                            height:   5,
                            gradient: goal.isComplete
                                ? [Color.lcGold.opacity(0.6), Color.lcGold]
                                : area.gradient,
                            showGlow: !goal.isComplete
                        )
                    }

                    // Show today step count if any
                    let todayCount = goal.steps.forToday().count
                    if todayCount > 0 {
                        Spacer(minLength: 8)
                        HStack(spacing: 5) {
                            Image(systemName: "sun.max")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(area.accent.opacity(0.75))
                            Text("\(todayCount) step\(todayCount == 1 ? "" : "s") today")
                                .font(LCFont.insight)
                                .foregroundStyle(area.accent.opacity(0.85))
                        }
                    } else if !goal.isComplete {
                        Spacer(minLength: 10)
                        NextStepRow(milestone: goal.nextMilestone, accent: area.accent)
                    }
                }
                .padding(LCSpacing.md)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .opacity(goal.isMock ? 0.80 : 1.0)
        .animation(.lcCardLift, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { pressed = false }
                }
        )
        .contextMenu {
            if !goal.isMock {
                if let onEdit = onEdit {
                    Button { onEdit() } label: { Label("Edit Goal", systemImage: "pencil") }
                }
                if let onPin = onPin {
                    Button { onPin() } label: { Label(goal.isPinned ? "Unpin" : "Pin", systemImage: goal.isPinned ? "pin.slash.fill" : "pin.fill") }
                }
                if let onArchive = onArchive {
                    Button { onArchive() } label: { Label("Archive", systemImage: "archivebox") }
                }
                if let onDelete = onDelete {
                    Button(role: .destructive) { onDelete() } label: { Label("Delete Goal", systemImage: "trash") }
                }
            }
        }
    }
}

// ── Next Step Row ──────────────────────────────────────────────
struct NextStepRow: View {
    let milestone: Milestone?
    let accent:    Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(accent.opacity(0.80))

            if let ms = milestone {
                Text("Next: \(ms.title)")
                    .font(LCFont.insight)
                    .foregroundStyle(accent.opacity(0.85))
                    .lineLimit(1)
            } else {
                Text("Add your first step")
                    .font(LCFont.insight)
                    .foregroundStyle(Color.lcTextTertiary)
            }
        }
    }
}

// ── XP Badge ──────────────────────────────────────────────────
struct GoalXPBadge: View {
    let xp:        Double
    let completed: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: completed ? "checkmark.seal.fill" : "star.fill")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.lcGold)
            Text(completed ? "Earned" : "+\(Int(xp)) XP")
                .font(LCFont.overline)
                .foregroundStyle(Color.lcGold)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.lcGold.opacity(0.12))
                .overlay(Capsule().strokeBorder(Color.lcGold.opacity(0.22), lineWidth: 0.5))
        )
    }
}

// ============================================================
// MARK: - Completed Goals Section
// ============================================================

private struct CompletedGoalsSection: View {
    let goals:     [Goal]
    let lifeAreas: [LifeArea]
    let onTap:     (Goal) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            Button {
                withAnimation(.lcCardLift) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("COMPLETED")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcGold.opacity(0.75))
                    Text("(\(goals.count))")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.lcTextTertiary)
                }
                .padding(.vertical, LCSpacing.xs)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ForEach(goals) { goal in
                    if let area = lifeAreas.first(where: { $0.id == goal.lifeAreaId }) {
                        // AFTER
                        GoalCard(goal: goal, area: area, onTap: { onTap(goal) })
                            .transition(.opacity.combined(with: .offset(y: 8)))
                    }
                }
            }
        }
    }
}

// ============================================================
// MARK: - Skeleton (Loading)
// ============================================================

private struct GoalsSkeletonSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.xl) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: LCSpacing.sm) {
                    VStack(alignment: .leading, spacing: 6) {
                        ShimmerBar(width: 60,  height: 10)
                        ShimmerBar(width: 130, height: 18)
                        ShimmerBar(width: 90,  height: 10)
                    }
                    .padding(.vertical, LCSpacing.xs)
                    ForEach(0..<2, id: \.self) { _ in GoalSkeletonCard() }
                }
            }
        }
    }
}

private struct GoalSkeletonCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ShimmerBar(width: 14, height: 11, radius: 3)
                    ShimmerBar(width: 55, height: 10)
                    Spacer()
                    ShimmerBar(width: 68, height: 22, radius: 11)
                }
                Spacer(minLength: LCSpacing.sm)
                ShimmerBar(width: .infinity, height: 18)
                Spacer(minLength: 5)
                ShimmerBar(width: 200, height: 18)
                Spacer(minLength: 8)
                ShimmerBar(width: 150, height: 12, radius: 4)
                Spacer(minLength: 6)
                ShimmerBar(width: .infinity, height: 5, radius: 3)
                Spacer(minLength: 10)
                ShimmerBar(width: 180, height: 12)
            }
            .padding(LCSpacing.md)
        }
    }
}

// ============================================================
// MARK: - Empty State
// ============================================================

private struct GoalsEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        GlassCard(glowColor: .lcPrimary, glowOpacity: 0.16) {
            VStack(spacing: LCSpacing.md) {
                Image(systemName: "scope")
                    .font(.system(size: 42, weight: .ultraLight))
                    .foregroundStyle(Color.lcTextTertiary)

                VStack(spacing: LCSpacing.xs) {
                    Text("Start your first meaningful goal")
                        .font(LCFont.header)
                        .foregroundStyle(Color.lcTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Goals give your progress direction. Begin with something that genuinely matters to you.")
                        .font(LCFont.insight)
                        .foregroundStyle(Color.lcTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PrimaryButton(
                    label:    "Create Your First Goal",
                    icon:     "plus",
                    gradient: [Color.lcPrimary, Color.lcLavender]
                ) { onAdd() }
            }
            .padding(LCSpacing.lg)
            .frame(maxWidth: .infinity)
        }
    }
}

// ============================================================
// MARK: - Edit Goal Sheet
// ============================================================

private struct EditGoalSheet: View {
    @State private var editTitle: String
    @State private var editWhy:   String
    let goal:   Goal
    let area:   LifeArea
    let onSave: (Goal) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Int?

    init(goal: Goal, area: LifeArea, onSave: @escaping (Goal) -> Void) {
        self.goal   = goal
        self.area   = area
        self.onSave = onSave
        _editTitle = State(initialValue: goal.title)
        _editWhy   = State(initialValue: goal.why ?? "")
    }

    private var canSave: Bool { editTitle.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 }

    var body: some View {
        ZStack {
            LCBackground(showNoise: true)
            VStack(alignment: .leading, spacing: 0) {
                Capsule().fill(Color.white.opacity(0.14)).frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity).padding(.top, 16).padding(.bottom, 20)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EDIT GOAL").font(LCFont.overline).foregroundStyle(Color.lcTextTertiary)
                        Text("Update your goal").font(LCFont.header).foregroundStyle(Color.lcTextPrimary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 26, weight: .light))
                            .foregroundStyle(Color.white.opacity(0.22))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.bottom, 24)

                // Area indicator
                HStack(spacing: 8) {
                    Image(systemName: area.icon).font(.system(size: 14, weight: .light)).foregroundStyle(area.accent)
                    Text(area.title.uppercased()).font(LCFont.overline).foregroundStyle(Color.lcTextTertiary)
                }
                .padding(.horizontal, 20).padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        GlassCard(glowColor: area.accent, glowOpacity: focusedField == 0 ? 0.18 : 0.08) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("GOAL TITLE").font(LCFont.overline).foregroundStyle(Color.lcTextTertiary)
                                TextField("Goal title", text: $editTitle)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.lcTextPrimary)
                                    .focused($focusedField, equals: 0).submitLabel(.next)
                                    .onSubmit { focusedField = 1 }
                            }
                            .padding(16)
                        }
                        .animation(.lcCardLift, value: focusedField == 0)

                        GlassCard(glowColor: area.accent, glowOpacity: focusedField == 1 ? 0.14 : 0.06) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("WHY THIS MATTERS  (optional)").font(LCFont.overline).foregroundStyle(Color.lcTextTertiary)
                                ZStack(alignment: .topLeading) {
                                    if editWhy.isEmpty {
                                        Text("Because it will change how I feel about…")
                                            .font(LCFont.body).foregroundStyle(Color.lcTextTertiary)
                                            .allowsHitTesting(false).padding(.top, 8).padding(.leading, 4)
                                    }
                                    TextEditor(text: $editWhy)
                                        .font(LCFont.body).foregroundStyle(Color.lcTextPrimary)
                                        .frame(minHeight: 72).fixedSize(horizontal: false, vertical: true)
                                        .scrollContentBackground(.hidden).background(.clear)
                                        .focused($focusedField, equals: 1)
                                }
                            }
                            .padding(16)
                        }
                        .animation(.lcCardLift, value: focusedField == 1)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)

                Divider().background(Color.white.opacity(0.07))
                PrimaryButton(label: "Save Changes", icon: "checkmark.circle.fill", gradient: [area.accent.opacity(0.8), area.accent]) {
                    var updated = goal
                    updated.title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.why   = editWhy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editWhy
                    onSave(updated)
                    dismiss()
                }
                .disabled(!canSave).opacity(canSave ? 1.0 : 0.40)
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
        }

        .onAppear { focusedField = 0 }
    }
}

// ============================================================
// MARK: - Previews
// ============================================================

#Preview("Goals — Loaded") {
    GoalsView()
        .environmentObject(AppState())
}

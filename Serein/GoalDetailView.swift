// GoalDetailView.swift
// Life Compass — Goal Detail / Execution Hub
//
// This screen is the daily execution centre for a single goal.
//
// Sections (top → bottom)
//   Header         — area tag, goal title, progress ring
//   Why card       — "why this matters" (if set)
//   TODAY steps    — forToday() — max 5 highlighted, tap to complete
//   UPCOMING       — tomorrow + scheduled future steps
//   BACKLOG        — anytime steps
//   MILESTONES     — macro checkpoints (original functionality)
//   COMPLETED      — done steps
//   Celebration    — shown when goal milestones are all done
//
// Lifecycle
//   onGoalUpdated        — propagates Goal mutations to AppState
//   onMilestoneCompleted — records XP + lifeAreaId in AppState

import SwiftUI
import Combine

// ============================================================
// MARK: - Motivational Micro-feedback Texts
// ============================================================

private let motivationalMessages: [String] = [
    "You moved forward today",
    "Momentum is building",
    "One step closer",
    "That's real progress",
    "Keep going",
    "You're building the life you want",
]

// ============================================================
// MARK: - GoalDetailViewModel
// ============================================================

@MainActor
final class GoalDetailViewModel: ObservableObject {

    @Published private(set) var goal:            Goal
    @Published var showMicroFeedback: Bool    = false
    @Published var microFeedbackText: String  = "Step completed"
    @Published var momentumMessage:   String? = nil
    @Published var showCelebration:   Bool    = false
    @Published var showAddMilestone:  Bool    = false
    @Published var newMilestoneText:  String  = ""
    @Published var showAddStep:       Bool    = false

    var onGoalUpdated:        (Goal)          -> Void
    var onMilestoneCompleted: (Double, UUID)  -> Void   // xp, lifeAreaId

    private let lifeAreaId:        UUID
    private var sessionCompletions = 0
    private var microFeedbackTask: Task<Void, Never>?

    init(
        goal:                Goal,
        lifeAreaId:          UUID,
        onGoalUpdated:        @escaping (Goal)         -> Void,
        onMilestoneCompleted: @escaping (Double, UUID) -> Void = { _, _ in }
    ) {
        self.goal                = goal
        self.lifeAreaId          = lifeAreaId
        self.onGoalUpdated        = onGoalUpdated
        self.onMilestoneCompleted = onMilestoneCompleted
        self.showCelebration      = goal.isComplete
    }

    // ── Computed ──────────────────────────────────────────────

    var todaySteps:    [GoalStep] { goal.steps.forToday() }
    var upcomingSteps: [GoalStep] { goal.steps.upcoming() }
    var backlogSteps:  [GoalStep] { goal.steps.backlog() }
    var completedSteps:[GoalStep] { goal.steps.done() }

    var progressInsight: String {
        switch goal.progress {
        case 0:           return "Every journey begins with a single step."
        case ..<0.25:     return "You've taken the first step. Keep going."
        case ..<0.5:      return "Gaining momentum — you're making it real."
        case 0.5..<0.51:  return "You're exactly halfway there. Don't stop now."
        case ..<0.75:     return "More than halfway. The finish line is visible."
        case ..<1.0:      return "Almost there. One step at a time."
        default:          return "You did it. This is what commitment looks like."
        }
    }

    var completionPercentText: String { "\(Int(goal.progress * 100))% complete" }

    // ── Complete step ─────────────────────────────────────────

    func completeStep(id: UUID) {
        guard let idx = goal.steps.firstIndex(where: { $0.id == id }) else { return }
        let wasCompleted = goal.steps[idx].isCompleted

        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            goal.steps[idx].isCompleted.toggle()
            goal.steps[idx].completedAt = wasCompleted ? nil : Date()
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if !wasCompleted {
            sessionCompletions += 1
            // Award 25 XP per step completion
            onMilestoneCompleted(25, lifeAreaId)
            flashFeedback(motivationalMessages.randomElement() ?? "Step completed")
            if sessionCompletions >= 3 && momentumMessage == nil {
                withAnimation(.lcSoftAppear.delay(0.4)) {
                    momentumMessage = "Momentum is building"
                }
            }
        } else {
            flashFeedback("Step unchecked")
            if sessionCompletions > 0 { sessionCompletions -= 1 }
            if sessionCompletions < 3 {
                withAnimation(.easeOut(duration: 0.3)) { momentumMessage = nil }
            }
        }

        onGoalUpdated(goal)
    }

    // ── Add step ──────────────────────────────────────────────

    func addStep(_ step: GoalStep) {
        withAnimation(.lcSoftAppear) {
            goal.steps.append(step)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onGoalUpdated(goal)
    }

    // ── Toggle milestone ──────────────────────────────────────

    func toggleMilestone(id: UUID) {
        guard let idx = goal.milestones.firstIndex(where: { $0.id == id }) else { return }

        let wasCompleted = goal.milestones[idx].isCompleted

        withAnimation(.spring(response: 0.40, dampingFraction: 0.70)) {
            goal.milestones[idx].isCompleted.toggle()
            goal.milestones[idx].completedAt = wasCompleted ? nil : Date()
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        if !wasCompleted {
            sessionCompletions += 1
            let xp = goal.xpReward / Double(max(goal.totalMilestones, 1))
            onMilestoneCompleted(xp, lifeAreaId)
            flashFeedback(motivationalMessages.randomElement() ?? "Step completed")
            if sessionCompletions >= 3 && momentumMessage == nil {
                withAnimation(.lcSoftAppear.delay(0.4)) {
                    momentumMessage = "Momentum is building"
                }
            }
        } else {
            flashFeedback("Step unchecked")
            if sessionCompletions > 0 { sessionCompletions -= 1 }
            if sessionCompletions < 3 {
                withAnimation(.easeOut(duration: 0.3)) { momentumMessage = nil }
            }
        }

        let isNowComplete = goal.isComplete
        if isNowComplete && !showCelebration {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.lcSoftAppear.delay(0.60)) { showCelebration = true }
        } else if !isNowComplete && showCelebration {
            withAnimation(.easeOut(duration: 0.4)) { showCelebration = false }
        }

        onGoalUpdated(goal)
    }

    // ── Add Milestone ─────────────────────────────────────────

    func commitNewMilestone() {
        let title = newMilestoneText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        withAnimation(.lcSoftAppear) {
            goal.milestones.append(Milestone(title: title))
            newMilestoneText = ""
            showAddMilestone = false
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onGoalUpdated(goal)
    }

    // ── Private helpers ───────────────────────────────────────

    private func flashFeedback(_ text: String) {
        microFeedbackTask?.cancel()
        microFeedbackText = text
        withAnimation(.lcSoftAppear)      { showMicroFeedback = true  }
        microFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(.easeOut(duration: 0.4)) { showMicroFeedback = false }
        }
    }
}

// ============================================================
// MARK: - GoalDetailView
// ============================================================

struct GoalDetailView: View {
    let area: LifeArea
    var onGoalUpdated:        (Goal)         -> Void
    var onMilestoneCompleted: (Double, UUID) -> Void

    @StateObject private var vm: GoalDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        goal:                Goal,
        area:                LifeArea,
        onGoalUpdated:        @escaping (Goal)         -> Void,
        onMilestoneCompleted: @escaping (Double, UUID) -> Void = { _, _ in }
    ) {
        self.area                = area
        self.onGoalUpdated        = onGoalUpdated
        self.onMilestoneCompleted = onMilestoneCompleted
        _vm = StateObject(wrappedValue: GoalDetailViewModel(
            goal:                goal,
            lifeAreaId:          area.id,
            onGoalUpdated:        onGoalUpdated,
            onMilestoneCompleted: onMilestoneCompleted
        ))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LCBackground(showNoise: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: LCSpacing.xl) {

                    DetailHeader(vm: vm, area: area, onDismiss: { dismiss() })

                    if let why = vm.goal.why {
                        WhyCard(text: why, accent: area.accent)
                            .softAppear(delay: 0.15)
                    }

                    ProgressInsightCard(vm: vm, area: area)
                        .softAppear(delay: 0.20)

                    if let msg = vm.momentumMessage {
                        MomentumBanner(message: msg, accent: area.accent)
                            .softAppear(delay: 0.0)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: -8)),
                                removal:   .opacity
                            ))
                    }

                    // ── TODAY ─────────────────────────────────
                    if !vm.todaySteps.isEmpty || vm.goal.steps.isEmpty {
                        TodayStepsSection(vm: vm, area: area)
                            .softAppear(delay: 0.24)
                    }

                    // ── UPCOMING ──────────────────────────────
                    if !vm.upcomingSteps.isEmpty {
                        StepListSection(
                            title:    "Upcoming",
                            overline: "SCHEDULED",
                            steps:    vm.upcomingSteps,
                            accent:   area.accent,
                            onToggle: { vm.completeStep(id: $0) }
                        )
                        .softAppear(delay: 0.28)
                    }

                    // ── BACKLOG ───────────────────────────────
                    if !vm.backlogSteps.isEmpty {
                        StepListSection(
                            title:    "Backlog",
                            overline: "ANYTIME",
                            steps:    vm.backlogSteps,
                            accent:   area.accent,
                            onToggle: { vm.completeStep(id: $0) }
                        )
                        .softAppear(delay: 0.32)
                    }

                    // ── MILESTONES ────────────────────────────
                    MilestonesSection(vm: vm, area: area)
                        .softAppear(delay: 0.36)

                    // ── COMPLETED ─────────────────────────────
                    if !vm.completedSteps.isEmpty {
                        CompletedStepsSection(steps: vm.completedSteps, accent: area.accent)
                            .softAppear(delay: 0.40)
                    }

                    // ── CELEBRATION ───────────────────────────
                    if vm.showCelebration {
                        CelebrationCard(goal: vm.goal, area: area, onDismiss: { dismiss() })
                            .softAppear(delay: 0.10)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal:   .opacity
                            ))
                    }
                }
                .padding(.horizontal, LCSpacing.md)
                .padding(.top, LCSpacing.lg)
                .padding(.bottom, LCSpacing.xxl)
            }

            // Micro-feedback toast
            if vm.showMicroFeedback {
                MicroFeedbackToast(text: vm.microFeedbackText, accent: area.accent)
                    .padding(.bottom, LCSpacing.lg)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 12)),
                        removal:   .opacity.combined(with: .offset(y: 8))
                    ))
                    .zIndex(10)
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $vm.showAddStep) {
            AddStepView(goalId: vm.goal.id) { step in
                vm.addStep(step)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .animation(.lcSoftAppear, value: vm.showCelebration)
        .animation(.lcSoftAppear, value: vm.momentumMessage != nil)
    }
}

// ============================================================
// MARK: - 1. Detail Header
// ============================================================

private struct DetailHeader: View {
    @ObservedObject var vm:    GoalDetailViewModel
    let area:                  LifeArea
    let onDismiss:             () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.md) {

            HStack {
                Button(action: onDismiss) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .medium))
                        Text("Back")
                            .font(LCFont.body)
                    }
                    .foregroundStyle(Color.lcTextSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                // Add Step button
                Button {
                    vm.showAddStep = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Add Step")
                            .font(LCFont.insight)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.lcTextPrimary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(
                        Capsule(style: .continuous)
                            .fill(area.accent.opacity(0.15))
                            .overlay(Capsule().strokeBorder(area.accent.opacity(0.32), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                Image(systemName: area.icon)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(area.accent.opacity(0.80))
                Text(area.title.uppercased())
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                if vm.goal.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.lcGold.opacity(0.80))
                }
            }

            Text(vm.goal.title)
                .font(LCFont.largeTitle)
                .foregroundStyle(Color.lcTextPrimary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                ProgressRing(
                    value:      vm.goal.progress,
                    maximum:    1.0,
                    size:       140,
                    lineWidth:  10,
                    gradient:   area.gradient,
                    trackColor: Color.white.opacity(0.07)
                )
                .pulseGlow(
                    color:      area.accent,
                    minOpacity: 0.08,
                    maxOpacity: 0.35,
                    minRadius:  6,
                    maxRadius:  22
                )
                Spacer()
            }
        }
        .softAppear(delay: 0.05)
    }
}

// ============================================================
// MARK: - 2. Why Card
// ============================================================

private struct WhyCard: View {
    let text:   String
    let accent: Color

    var body: some View {
        GlassCard(glowColor: accent, glowOpacity: 0.12) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("WHY THIS MATTERS")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)

                Text(text)
                    .font(LCFont.body)
                    .italic()
                    .foregroundStyle(Color.lcTextSecondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(LCSpacing.md)
        }
    }
}

// ============================================================
// MARK: - 3. Progress Insight
// ============================================================

private struct ProgressInsightCard: View {
    @ObservedObject var vm: GoalDetailViewModel
    let area:               LifeArea

    var body: some View {
        GlassCard(glowColor: area.accent, glowOpacity: 0.10) {
            HStack(spacing: LCSpacing.md) {
                ProgressRing(
                    value:      vm.goal.progress,
                    maximum:    1.0,
                    size:       60,
                    lineWidth:  6,
                    gradient:   area.gradient,
                    trackColor: Color.white.opacity(0.07)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.completionPercentText)
                        .font(LCFont.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lcTextPrimary)
                    Text(vm.progressInsight)
                        .font(LCFont.insight)
                        .foregroundStyle(Color.lcTextSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(LCSpacing.md)
        }
    }
}

// ============================================================
// MARK: - 4. Momentum Banner
// ============================================================

private struct MomentumBanner: View {
    let message: String
    let accent:  Color

    var body: some View {
        GlassCard(glowColor: accent, glowOpacity: 0.20) {
            HStack(spacing: LCSpacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(accent)
                Text(message)
                    .font(LCFont.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.lcTextPrimary)
                Spacer()
            }
            .padding(LCSpacing.md)
        }
        .pulseGlow(color: accent, minOpacity: 0.10, maxOpacity: 0.30, minRadius: 4, maxRadius: 16)
    }
}

// ============================================================
// MARK: - 5. Today Steps Section
// ============================================================

private struct TodayStepsSection: View {
    @ObservedObject var vm: GoalDetailViewModel
    let area: LifeArea

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            SectionHeader(
                title:    "Today",
                subtitle: vm.todaySteps.isEmpty ? "No steps planned for today" : "\(vm.todaySteps.count) action\(vm.todaySteps.count == 1 ? "" : "s")",
                overline: "DO THIS NOW"
            )

            GlassCard(glowColor: area.accent, glowOpacity: 0.12) {
                VStack(spacing: 0) {
                    if vm.todaySteps.isEmpty {
                        // Empty today state
                        Button {
                            vm.showAddStep = true
                        } label: {
                            HStack(spacing: LCSpacing.sm) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundStyle(area.accent.opacity(0.70))
                                Text("Add a step for today")
                                    .font(LCFont.body)
                                    .foregroundStyle(area.accent.opacity(0.85))
                                Spacer()
                            }
                            .padding(LCSpacing.md)
                        }
                        .buttonStyle(.plain)
                    } else {
                        ForEach(Array(vm.todaySteps.enumerated()), id: \.element.id) { idx, step in
                            DetailStepRow(
                                step:      step,
                                accent:    area.accent,
                                isHighlighted: true,
                                onToggle:  { vm.completeStep(id: step.id) }
                            )
                            .softAppear(delay: 0.04 + Double(idx) * 0.05)

                            if idx < vm.todaySteps.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.horizontal, LCSpacing.md)
                            }
                        }

                        if vm.todaySteps.count < 5 {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.horizontal, LCSpacing.md)

                            Button {
                                vm.showAddStep = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Add step")
                                        .font(LCFont.insight)
                                        .fontWeight(.medium)
                                }
                                .foregroundStyle(area.accent.opacity(0.80))
                                .padding(LCSpacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

// ============================================================
// MARK: - 6. Generic Step List Section (Upcoming / Backlog)
// ============================================================

private struct StepListSection: View {
    let title:    String
    let overline: String
    let steps:    [GoalStep]
    let accent:   Color
    let onToggle: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            SectionHeader(
                title:    title,
                subtitle: "\(steps.count) step\(steps.count == 1 ? "" : "s")",
                overline: overline
            )

            GlassCard(glowColor: accent, glowOpacity: 0.08) {
                VStack(spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { idx, step in
                        DetailStepRow(
                            step:          step,
                            accent:        accent,
                            isHighlighted: false,
                            onToggle:      { onToggle(step.id) }
                        )

                        if idx < steps.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.horizontal, LCSpacing.md)
                        }
                    }
                }
            }
        }
    }
}

// ── Detail Step Row ────────────────────────────────────────────

private struct DetailStepRow: View {
    let step:          GoalStep
    let accent:        Color
    let isHighlighted: Bool
    let onToggle:      () -> Void

    @State private var checkScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: LCSpacing.sm) {

            Button(action: handleToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            step.isCompleted ? accent : Color.white.opacity(isHighlighted ? 0.30 : 0.18),
                            lineWidth: 1.5
                        )
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(step.isCompleted ? accent.opacity(0.15) : .clear)
                        )

                    if step.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                            .scaleEffect(checkScale)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.60), value: step.isCompleted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(LCFont.body)
                    .foregroundStyle(
                        step.isCompleted ? Color.lcTextTertiary : Color.lcTextPrimary
                    )
                    .strikethrough(step.isCompleted, color: Color.lcTextTertiary)
                    .animation(.easeOut(duration: 0.3), value: step.isCompleted)

                HStack(spacing: 4) {
                    if let date = step.scheduledDate {
                        Image(systemName: "calendar")
                            .font(.system(size: 9, weight: .light))
                            .foregroundStyle(Color.lcTextTertiary)
                        Text(date, style: .date)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.lcTextTertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            StepTypePill(type: step.type, accent: accent)
        }
        .padding(.horizontal, LCSpacing.md)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: handleToggle)
        .background(
            isHighlighted && !step.isCompleted
                ? accent.opacity(0.04)
                : .clear
        )
    }

    private func handleToggle() {
        onToggle()
        if !step.isCompleted {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.45)) { checkScale = 1.35 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { checkScale = 1.0 }
            }
        }
    }
}

// ============================================================
// MARK: - 7. Milestones Section
// ============================================================

private struct MilestonesSection: View {
    @ObservedObject var vm: GoalDetailViewModel
    let area:               LifeArea

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            SectionHeader(
                title:    "Milestones",
                subtitle: vm.goal.milestones.isEmpty ? "Add your first checkpoint" : vm.goal.milestoneLabel,
                overline: "MACRO PROGRESS"
            )

            GlassCard(glowColor: area.accent, glowOpacity: 0.10) {
                VStack(spacing: 0) {
                    if vm.goal.milestones.isEmpty && !vm.showAddMilestone {
                        HStack(spacing: LCSpacing.sm) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(Color.lcTextTertiary)
                            Text("Tap + to add your first milestone")
                                .font(LCFont.body)
                                .foregroundStyle(Color.lcTextTertiary)
                            Spacer()
                        }
                        .padding(LCSpacing.md)
                    } else {
                        ForEach(Array(vm.goal.milestones.enumerated()), id: \.element.id) { idx, ms in
                            MilestoneRow(
                                milestone: ms,
                                isNext:    ms.id == vm.goal.nextMilestone?.id,
                                accent:    area.accent,
                                onToggle:  { vm.toggleMilestone(id: ms.id) }
                            )
                            .softAppear(delay: 0.05 + Double(idx) * 0.06)

                            Divider()
                                .background(Color.white.opacity(0.06))
                                .padding(.horizontal, LCSpacing.md)
                        }
                    }

                    if vm.showAddMilestone {
                        AddMilestoneRow(vm: vm, accent: area.accent)
                            .transition(.opacity.combined(with: .offset(y: -4)))
                    }

                    if !vm.showAddMilestone {
                        Button {
                            withAnimation(.lcSoftAppear) { vm.showAddMilestone = true }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Add Milestone")
                                    .font(LCFont.insight)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(area.accent.opacity(0.85))
                            .padding(LCSpacing.md)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// ── AddMilestoneRow ───────────────────────────────────────────

private struct AddMilestoneRow: View {
    @ObservedObject var vm: GoalDetailViewModel
    let accent: Color
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: LCSpacing.sm) {
            TextField("Describe the next milestone…", text: $vm.newMilestoneText)
                .font(LCFont.body)
                .foregroundStyle(Color.lcTextPrimary)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { vm.commitNewMilestone() }

            if !vm.newMilestoneText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button(action: vm.commitNewMilestone) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Button {
                withAnimation(.lcSoftAppear) {
                    vm.newMilestoneText = ""
                    vm.showAddMilestone  = false
                }
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(Color.lcTextTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(LCSpacing.md)
        .onAppear { focused = true }
        .animation(.lcSoftAppear, value: vm.newMilestoneText.isEmpty)
    }
}

// ── MilestoneRow ───────────────────────────────────────────────

private struct MilestoneRow: View {
    let milestone: Milestone
    let isNext:    Bool
    let accent:    Color
    let onToggle:  () -> Void

    @State private var checkScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: LCSpacing.sm) {

            Button(action: handleToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            milestone.isCompleted ? accent : Color.white.opacity(0.20),
                            lineWidth: 1.5
                        )
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(milestone.isCompleted ? accent.opacity(0.15) : .clear)
                        )

                    if milestone.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accent)
                            .scaleEffect(checkScale)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.60), value: milestone.isCompleted)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(milestone.title)
                    .font(LCFont.body)
                    .foregroundStyle(
                        milestone.isCompleted ? Color.lcTextTertiary : Color.lcTextPrimary
                    )
                    .strikethrough(milestone.isCompleted, color: Color.lcTextTertiary)
                    .animation(.easeOut(duration: 0.3), value: milestone.isCompleted)

                if isNext && !milestone.isCompleted {
                    Text("Next milestone")
                        .font(LCFont.overline)
                        .foregroundStyle(accent.opacity(0.85))
                        .transition(.opacity)
                }
            }

            Spacer(minLength: 0)

            if milestone.isCompleted, let date = milestone.completedAt {
                Text(date, style: .date)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.lcTextTertiary)
            }
        }
        .padding(.horizontal, LCSpacing.md)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture(perform: handleToggle)
    }

    private func handleToggle() {
        onToggle()
        if !milestone.isCompleted {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.45)) { checkScale = 1.35 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { checkScale = 1.0 }
            }
        }
    }
}

// ============================================================
// MARK: - 8. Completed Steps Section
// ============================================================

private struct CompletedStepsSection: View {
    let steps:  [GoalStep]
    let accent: Color

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            Button {
                withAnimation(.lcCardLift) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text("COMPLETED STEPS")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcGold.opacity(0.75))
                    Text("(\(steps.count))")
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
                GlassCard(glowColor: accent, glowOpacity: 0.06) {
                    VStack(spacing: 0) {
                        ForEach(Array(steps.prefix(10).enumerated()), id: \.element.id) { idx, step in
                            HStack(spacing: LCSpacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundStyle(accent.opacity(0.50))
                                    .frame(width: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title)
                                        .font(LCFont.body)
                                        .foregroundStyle(Color.lcTextTertiary)
                                        .strikethrough(true, color: Color.lcTextTertiary)
                                        .lineLimit(1)

                                    if let date = step.completedAt {
                                        Text(date, style: .date)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.lcTextTertiary.opacity(0.60))
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, LCSpacing.md)
                            .padding(.vertical, 12)

                            if idx < min(steps.count, 10) - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.horizontal, LCSpacing.md)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .offset(y: 8)))
            }
        }
    }
}

// ============================================================
// MARK: - 9. Celebration Card
// ============================================================

private struct CelebrationCard: View {
    let goal:      Goal
    let area:      LifeArea
    let onDismiss: () -> Void

    var body: some View {
        GlassCard(glowColor: .lcGold, glowOpacity: 0.30) {
            VStack(spacing: LCSpacing.md) {
                Image(systemName: "seal.fill")
                    .font(.system(size: 44, weight: .ultraLight))
                    .foregroundStyle(Color.lcGold.opacity(0.85))
                    .pulseGlow(
                        color:      .lcGold,
                        minOpacity: 0.20,
                        maxOpacity: 0.60,
                        minRadius:  6,
                        maxRadius:  22
                    )

                VStack(spacing: LCSpacing.xs) {
                    Text("Goal Complete")
                        .font(LCFont.header)
                        .foregroundStyle(Color.lcTextPrimary)

                    Text("You earned \(Int(goal.xpReward)) XP in \(area.title).\nThis is what commitment looks like.")
                        .font(LCFont.insight)
                        .foregroundStyle(Color.lcTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                PrimaryButton(
                    label:    "Back to Goals",
                    icon:     "arrow.left",
                    gradient: [Color.lcGold.opacity(0.8), Color.lcGold]
                ) { onDismiss() }
            }
            .padding(LCSpacing.lg)
            .frame(maxWidth: .infinity)
        }
    }
}

// ============================================================
// MARK: - Micro-feedback Toast
// ============================================================

private struct MicroFeedbackToast: View {
    let text:   String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent)
            Text(text)
                .font(LCFont.insight)
                .fontWeight(.medium)
                .foregroundStyle(Color.lcTextPrimary)
        }
        .padding(.horizontal, LCSpacing.md)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                .shadow(color: accent.opacity(0.30), radius: 16, y: 4)
                .shadow(color: .black.opacity(0.30), radius: 8,  y: 2)
        )
    }
}

// ============================================================
// MARK: - Previews
// ============================================================

#Preview("Goal Detail — In Progress") {
    let appState = AppState()
    return NavigationStack {
        GoalDetailView(
            goal: Goal.samples[0],
            area: LifeArea.samples[0],
            onGoalUpdated:        { appState.updateGoal($0) },
            onMilestoneCompleted: { xp, areaId in appState.recordMilestoneCompletion(xp: xp, lifeAreaId: areaId) }
        )
    }
    .environmentObject(appState)
}

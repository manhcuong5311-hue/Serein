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
    @Published var showEditStep:   Bool       = false
    @Published var editingStep:    GoalStep?  = nil
    @Published var showEditGoal:   Bool       = false

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

    // ── Delete step ──────────────────────────────────────────────
    func deleteStep(id: UUID) {
        withAnimation(.lcSoftAppear) {
            goal.steps.removeAll { $0.id == id }
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onGoalUpdated(goal)
    }

    // ── Update step (from inline edit) ────────────────────────────
    func updateStep(_ step: GoalStep) {
        guard let idx = goal.steps.firstIndex(where: { $0.id == step.id }) else { return }
        withAnimation(.lcSoftAppear) { goal.steps[idx] = step }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onGoalUpdated(goal)
    }

    // ── Update goal title ─────────────────────────────────────────
    func updateGoalTitle(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        goal.title = trimmed
        onGoalUpdated(goal)
    }

    // ── Update goal why ───────────────────────────────────────────
    func updateGoalWhy(_ why: String) {
        goal.why = why.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : why
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
                            onToggle: { vm.completeStep(id: $0) },
                            onDelete: { vm.deleteStep(id: $0) },
                            onEdit:   { vm.editingStep = $0; vm.showEditStep = true }
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
                            onToggle: { vm.completeStep(id: $0) },
                            onDelete: { vm.deleteStep(id: $0) },
                            onEdit:   { vm.editingStep = $0; vm.showEditStep = true }
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

        .sheet(isPresented: $vm.showAddStep) {
            AddStepView(goalId: vm.goal.id) { step in
                vm.addStep(step)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.showEditStep) {
            if let step = vm.editingStep {
                EditStepSheet(step: step) { updated in
                    vm.updateStep(updated)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $vm.showEditGoal) {
            EditGoalInfoSheet(
                title: vm.goal.title,
                why:   vm.goal.why ?? "",
                accent: area.accent
            ) { newTitle, newWhy in
                vm.updateGoalTitle(newTitle)
                vm.updateGoalWhy(newWhy)
            }
            .presentationDetents([.medium])
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
                .contextMenu {
                    Button { vm.showEditGoal = true } label: { Label("Edit Goal", systemImage: "pencil") }
                }

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
                                step:          step,
                                accent:        area.accent,
                                isHighlighted: true,
                                onToggle:      { vm.completeStep(id: step.id) },
                                onDelete:      { vm.deleteStep(id: step.id) },
                                onEdit:        { vm.editingStep = step; vm.showEditStep = true }
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
    var onDelete: (UUID) -> Void     = { _ in }
    var onEdit:   (GoalStep) -> Void = { _ in }

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
                            onToggle:      { onToggle(step.id) },
                            onDelete:      { onDelete(step.id) },
                            onEdit:        { onEdit(step) }
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
    var onDelete:      (() -> Void)? = nil
    var onEdit:        (() -> Void)? = nil

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
        .contextMenu {
            if let onEdit = onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("Edit Step", systemImage: "pencil")
                }
            }
            if let onDelete = onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete Step", systemImage: "trash")
                }
            }
        }
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
// MARK: - Edit Step Sheet
// ============================================================

private struct EditStepSheet: View {
    let step:    GoalStep
    let onSave:  (GoalStep) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title:         String   = ""
    @State private var selectedType:  StepType = .today
    @State private var scheduledDate: Date     = Date()
    @FocusState private var focused: Bool

    init(step: GoalStep, onSave: @escaping (GoalStep) -> Void) {
        self.step   = step
        self.onSave = onSave
        _title         = State(initialValue: step.title)
        _selectedType  = State(initialValue: step.type)
        _scheduledDate = State(initialValue: step.scheduledDate ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }

    private var canSave: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1 }

    var body: some View {
        ZStack {
            LCBackground(showNoise: true)
            VStack(alignment: .leading, spacing: 0) {
                // Handle
                Capsule().fill(Color.white.opacity(0.14)).frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity).padding(.top, 16).padding(.bottom, 20)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EDIT STEP").font(LCFont.overline).foregroundStyle(Color.lcTextTertiary)
                        Text("Refine your action").font(LCFont.header).foregroundStyle(Color.lcTextPrimary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 26, weight: .light)).foregroundStyle(Color.white.opacity(0.22))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        GlassCard(glowColor: .lcPrimary, glowOpacity: focused ? 0.20 : 0.08) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("STEP TITLE").font(LCFont.overline).foregroundStyle(Color.lcTextTertiary)
                                TextField("Describe the action…", text: $title)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.lcTextPrimary)
                                    .focused($focused)
                                    .submitLabel(.done)
                            }
                            .padding(16)
                        }
                        .animation(.lcCardLift, value: focused)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("WHEN").font(LCFont.overline).foregroundStyle(Color.lcTextTertiary)
                            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.08) {
                                VStack(spacing: 0) {
                                    ForEach(Array(StepType.allCases.enumerated()), id: \.element) { idx, type in
                                        let locked = FeatureAccessManager.shared.isStepTypeLocked(type)
                                        HStack(spacing: 14) {
                                            Image(systemName: type.icon).font(.system(size: 14, weight: .light))
                                                .foregroundStyle(selectedType == type ? Color.lcPrimary : Color.lcTextTertiary).frame(width: 24)
                                            Text(type.displayName).font(LCFont.body).fontWeight(.medium)
                                                .foregroundStyle(locked ? Color.lcTextTertiary : (selectedType == type ? Color.lcTextPrimary : Color.lcTextSecondary))
                                            if locked {
                                                Text("Premium").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.lcGold)
                                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                                    .background(Capsule().fill(Color.lcGold.opacity(0.12)))
                                            }
                                            Spacer()
                                            if selectedType == type && !locked {
                                                Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundStyle(Color.lcPrimary)
                                            }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 14).contentShape(Rectangle())
                                        .opacity(locked ? 0.60 : 1.0)
                                        .onTapGesture { if !locked { withAnimation(.lcCardLift) { selectedType = type } } }
                                        if idx < StepType.allCases.count - 1 {
                                            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }
                        }

                        if selectedType == .scheduled {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("DATE").font(LCFont.overline).foregroundStyle(Color.lcTextTertiary)
                                GlassCard(glowColor: .lcPrimary, glowOpacity: 0.10) {
                                    DatePicker("", selection: $scheduledDate, in: Date()..., displayedComponents: .date)
                                        .datePickerStyle(.graphical).tint(Color.lcPrimary).labelsHidden().padding(10)
                                }
                            }
                            .transition(.opacity.combined(with: .offset(y: -8)))
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40).animation(.lcSoftAppear, value: selectedType)
                }

                Divider().background(Color.white.opacity(0.07))
                PrimaryButton(label: "Save Changes", icon: "checkmark.circle.fill", gradient: [Color.lcPrimary, Color.lcLavender]) {
                    var updated = step
                    updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    updated.type  = selectedType
                    updated.scheduledDate = selectedType == .scheduled ? scheduledDate : nil
                    onSave(updated)
                    dismiss()
                }
                .disabled(!canSave).opacity(canSave ? 1.0 : 0.40)
                .padding(.horizontal, 20).padding(.vertical, 16)
            }
        }

        .onAppear { focused = true }
    }
}

// ============================================================
// MARK: - Edit Goal Info Sheet
// ============================================================

private struct EditGoalInfoSheet: View {
    @State private var editTitle: String
    @State private var editWhy:   String
    let accent:  Color
    let onSave:  (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Int?

    init(title: String, why: String, accent: Color, onSave: @escaping (String, String) -> Void) {
        _editTitle = State(initialValue: title)
        _editWhy   = State(initialValue: why)
        self.accent = accent
        self.onSave = onSave
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
                        Text("Update your goal details").font(LCFont.header).foregroundStyle(Color.lcTextPrimary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 26, weight: .light)).foregroundStyle(Color.white.opacity(0.22))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 20).padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        GlassCard(glowColor: accent, glowOpacity: focusedField == 0 ? 0.18 : 0.08) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("GOAL TITLE").font(LCFont.overline).foregroundStyle(Color.lcTextTertiary)
                                TextField("Goal title", text: $editTitle)
                                    .font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.lcTextPrimary)
                                    .focused($focusedField, equals: 0).submitLabel(.next)
                                    .onSubmit { focusedField = 1 }
                            }
                            .padding(16)
                        }
                        .animation(.lcCardLift, value: focusedField == 0)

                        GlassCard(glowColor: accent, glowOpacity: focusedField == 1 ? 0.14 : 0.06) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("WHY THIS MATTERS  (optional)").font(LCFont.overline).foregroundStyle(Color.lcTextTertiary)
                                ZStack(alignment: .topLeading) {
                                    if editWhy.isEmpty {
                                        Text("Because it will change how I feel about…").font(LCFont.body)
                                            .foregroundStyle(Color.lcTextTertiary).allowsHitTesting(false)
                                            .padding(.top, 8).padding(.leading, 4)
                                    }
                                    TextEditor(text: $editWhy).font(LCFont.body).foregroundStyle(Color.lcTextPrimary)
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

                Divider().background(Color.white.opacity(0.07))
                PrimaryButton(label: "Save Changes", icon: "checkmark.circle.fill", gradient: [accent.opacity(0.8), accent]) {
                    onSave(editTitle, editWhy)
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

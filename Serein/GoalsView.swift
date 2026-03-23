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
    @State private var navItem:    GoalNavItem?
    @State private var appeared:   Bool = false
    @State private var showAddGoal: Bool = false

    // ── Computed from AppState ─────────────────────────────────

    private var pinnedGoals: [Goal] {
        appState.goals
            .filter { $0.isPinned && !$0.isArchived && !$0.isComplete }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private var activeGroups: [GoalGroup] {
        buildGroups(from: appState.goals.filter { !$0.isArchived && !$0.isComplete && !$0.isPinned })
    }

    private var completedGoals: [Goal] {
        appState.goals.filter { $0.isComplete && !$0.isArchived }
    }

    private var totalActive:    Int { appState.goals.filter { !$0.isArchived && !$0.isComplete }.count }
    private var totalCompleted: Int { completedGoals.count }

    var body: some View {
        NavigationStack {
            ZStack {
                LCBackground(showNoise: true)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: LCSpacing.xl) {

                        GoalsScreenHeader(
                            totalCompleted: totalCompleted,
                            totalActive:    totalActive,
                            appeared:       appeared,
                            onAdd:          { showAddGoal = true }
                        )

                        if !appeared {
                            GoalsSkeletonSection()
                                .softAppear(delay: 0.05)
                        } else if appState.goals.filter({ !$0.isArchived }).isEmpty {
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
                                    group:     group,
                                    baseDelay: 0.20 + Double(sIdx) * 0.10,
                                    onTap:     { goal in
                                        navItem = GoalNavItem(goal: goal, area: group.area)
                                    },
                                    onPin:     { appState.pinGoal($0) },
                                    onArchive: { appState.archiveGoal($0) }
                                )
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
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddGoal) {
                AddGoalView()
                    .environmentObject(appState)
                    .presentationDragIndicator(.visible)
                    .presentationDetents([.large])
            }
            .navigationDestination(item: $navItem) { item in
                GoalDetailView(
                    goal: item.goal,
                    area: item.area,
                    onGoalUpdated:        { appState.updateGoal($0) },
                    onMilestoneCompleted: { xp, areaId in appState.recordMilestoneCompletion(xp: xp, lifeAreaId: areaId) }
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
    let baseDelay: Double
    let onTap:     (Goal) -> Void
    let onPin:     (Goal) -> Void
    let onArchive: (Goal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            let done  = group.goals.filter(\.isComplete).count
            let total = group.goals.count

            SectionHeader(
                title:    group.area.title,
                subtitle: "\(done) of \(total) complete",
                overline: "LIFE AREA"
            )
            .softAppear(delay: baseDelay)

            ForEach(Array(group.goals.enumerated()), id: \.element.id) { cIdx, goal in
                SwipeGoalCard(
                    goal:      goal,
                    area:      group.area,
                    isPinned:  false,
                    onTap:     { onTap(goal) },
                    onPin:     { onPin(goal) },
                    onArchive: { onArchive(goal) }
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

    @State private var offset:  CGFloat = 0
    private let threshold: CGFloat = 72
    private let maxReveal: CGFloat = 88

    var body: some View {
        ZStack(alignment: .leading) {
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

            // Card
            GoalCard(goal: goal, area: area, onTap: onTap)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 18)
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
    var onTap: () -> Void = {}

    @State private var pressed = false

    var body: some View {
        Button(action: onTap) {
            GlassCard(
                glowColor:   area.accent,
                glowOpacity: pressed ? 0.28 : 0.13
            ) {
                VStack(alignment: .leading, spacing: 0) {

                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: area.icon)
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(area.accent.opacity(0.75))
                        Text(area.title.uppercased())
                            .font(LCFont.overline)
                            .foregroundStyle(Color.lcTextTertiary)
                        if goal.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.lcGold.opacity(0.85))
                        } else if goal.isFocusGoal {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.lcGold)
                        }
                        Spacer(minLength: 0)
                        GoalXPBadge(xp: goal.xpReward, completed: goal.isComplete)
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
        .animation(.lcCardLift, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded   { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { pressed = false }
                }
        )
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
                        GoalCard(goal: goal, area: area) { onTap(goal) }
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
// MARK: - Previews
// ============================================================

#Preview("Goals — Loaded") {
    GoalsView()
        .environmentObject(AppState())
}

// LifeDashboardView.swift
// Life Compass — Dashboard Screen
//
// The daily loop entry point. Opens every morning.
//
// Layout (top → bottom)
//   1. Header             — personalised greeting + date + streak badge
//   2. Today Steps        — all goals' today steps, sorted, max 5
//   3. Daily Focus Card   — today's goal + next milestone (tap → GoalDetail)
//   4. Life Areas Grid    — 2-col LazyVGrid
//   5. Reflection Prompt  — conditional
//   6. Life Balance       — concentric rings
//   7. Insight Card       — motivational quote + XP today
//   8. Future Self Card   — narrative teaser

import SwiftUI

// ============================================================
// MARK: - LifeDashboardView
// ============================================================

struct LifeDashboardView: View {
    @EnvironmentObject var appState: AppState
    var onGoToGoals:      (() -> Void)? = nil
    var onGoToReflection: (() -> Void)? = nil
    var onGoToVision:     (() -> Void)? = nil

    @State private var navItem: GoalNavItem?

    var body: some View {
        ZStack {
            LCBackground(showNoise: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: LCSpacing.xl) {

                    DashboardHeader()

                    // Today's steps — core execution section
                    TodayStepsSection(navItem: $navItem)
                        .softAppear(delay: 0.10)

                    // Daily focus goal card
                    if let focus = appState.dailyFocusGoal,
                       let area  = appState.area(for: focus) {
                        DailyFocusCard(goal: focus, area: area) {
                            navItem = GoalNavItem(goal: focus, area: area)
                        }
                        .softAppear(delay: 0.20)
                    }

                    // Life areas grid
                    LifeAreaSection()

                    // Reflection prompt (conditional)
                    if appState.shouldShowReflectionPrompt {
                        ReflectionPromptCard {
                            onGoToReflection?()
                        }
                        .softAppear(delay: 0.42)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: -8)),
                            removal:   .opacity
                        ))
                    }

                    // Life balance rings + XP today
                    if !appState.lifeAreas.isEmpty {
                        LifeBalanceSection(areas: appState.lifeAreas)
                            .softAppear(delay: 0.50)

                        InsightCardView(
                            insight:     DailyInsight.placeholder,
                            xpToday:     appState.totalXPToday,
                            hasActivity: appState.hasActivityToday
                        )
                        .softAppear(delay: 0.60)

                        FutureSelfTeaser(
                            vision: appState.futureVision,
                            onTap:  { onGoToVision?() }
                        )
                        .softAppear(delay: 0.70)
                    }
                }
                .padding(.horizontal, LCSpacing.md)
                .padding(.top, LCSpacing.xl)
                .padding(.bottom, LCSpacing.xxl)
            }
            .refreshable { appState.load() }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .navigationDestination(item: $navItem) { item in
            GoalDetailView(
                goal: item.goal,
                area: item.area,
                onGoalUpdated:        { appState.updateGoal($0) },
                onMilestoneCompleted: { xp, areaId in appState.recordMilestoneCompletion(xp: xp, lifeAreaId: areaId) }
            )
        }
        .animation(.lcSoftAppear, value: appState.shouldShowReflectionPrompt)
    }
}

// ============================================================
// MARK: - 1. Header
// ============================================================

private struct DashboardHeader: View {
    @EnvironmentObject var appState: AppState

    private var greetingText: String {
        if let name = appState.userProfile?.name {
            return greeting(for: name)
        }
        // Fallback if no profile yet
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12:  return "Good morning"
        case 12..<18: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text(greetingText)
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .softAppear(delay: 0.05)

                Text(dateString)
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.10)
            }

            Spacer()

            if appState.streak > 0 {
                DashboardStreakBadge(streak: appState.streak)
                    .softAppear(delay: 0.14)
            }
        }
    }
}

// ── Streak Badge ──────────────────────────────────────────────

private struct DashboardStreakBadge: View {
    let streak: Int

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "flame.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.lcGold)
                .pulseGlow(
                    color:      .lcGold,
                    minOpacity: 0.10,
                    maxOpacity: 0.40,
                    minRadius:  4,
                    maxRadius:  14
                )
            Text("\(streak)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.lcGold)
                .contentTransition(.numericText())
            Text("day\(streak == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.lcGold.opacity(0.65))
        }
        .padding(.horizontal, LCSpacing.sm)
        .padding(.vertical, LCSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.lcGold.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.lcGold.opacity(0.22), lineWidth: 1)
                )
        )
    }
}

// ============================================================
// MARK: - 2. Today Steps Section
// ============================================================

private struct TodayStepsSection: View {
    @EnvironmentObject var appState: AppState
    @Binding var navItem: GoalNavItem?

    private var allStepsCompletedToday: Bool {
        appState.todaySteps.isEmpty && appState.hasActivityToday
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            SectionHeader(
                title:    "Today",
                subtitle: todaySubtitle,
                overline: "WHAT TO DO NOW"
            )
            .softAppear(delay: 0.08)

            if allStepsCompletedToday {
                TodayAllCompleteCard()
                    .softAppear(delay: 0.12)

            } else if appState.todaySteps.isEmpty {
                TodayEmptyState()
                    .softAppear(delay: 0.12)

            } else {
                GlassCard(glowColor: .lcPrimary, glowOpacity: 0.14) {
                    VStack(spacing: 0) {
                        ForEach(Array(appState.todaySteps.enumerated()), id: \.element.id) { idx, item in
                            DashboardStepRow(
                                item:      item,
                                onComplete: {
                                    appState.completeStep(goalId: item.goal.id, stepId: item.step.id)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                },
                                onTapGoal: {
                                    navItem = GoalNavItem(goal: item.goal, area: item.area)
                                }
                            )
                            if idx < appState.todaySteps.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.06))
                                    .padding(.horizontal, LCSpacing.md)
                            }
                        }
                    }
                }
                .softAppear(delay: 0.12)
                .animation(.lcSoftAppear, value: appState.todaySteps.map(\.id))
            }
        }
    }

    private var todaySubtitle: String? {
        let count = appState.todaySteps.count
        if count == 0 { return nil }
        return "\(count) of 5 max"
    }
}

// ── Dashboard Step Row ─────────────────────────────────────────

private struct DashboardStepRow: View {
    let item:       TodayStepItem
    let onComplete: () -> Void
    let onTapGoal:  () -> Void

    @State private var checkScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: LCSpacing.sm) {

            // Completion circle
            Button(action: handleComplete) {
                ZStack {
                    Circle()
                        .strokeBorder(item.area.accent.opacity(0.45), lineWidth: 1.5)
                        .frame(width: 28, height: 28)
                    Circle()
                        .fill(item.area.accent.opacity(0.08))
                        .frame(width: 28, height: 28)
                }
                .scaleEffect(checkScale)
            }
            .buttonStyle(.plain)

            // Step info
            VStack(alignment: .leading, spacing: 3) {
                Text(item.step.title)
                    .font(LCFont.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.lcTextPrimary)
                    .lineLimit(2)

                HStack(spacing: 5) {
                    Image(systemName: item.area.icon)
                        .font(.system(size: 9, weight: .light))
                        .foregroundStyle(item.area.accent.opacity(0.75))
                    Text(item.goal.title)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.lcTextTertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            // Step type badge
            StepTypePill(type: item.step.type, accent: item.area.accent)

            // Chevron → goal detail
            Button(action: onTapGoal) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.lcTextTertiary.opacity(0.40))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, LCSpacing.md)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func handleComplete() {
        withAnimation(.spring(response: 0.20, dampingFraction: 0.45)) { checkScale = 1.35 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) { checkScale = 1.0 }
            onComplete()
        }
    }
}

// ── Step Type Pill ─────────────────────────────────────────────

struct StepTypePill: View {
    let type:   StepType
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: type.icon)
                .font(.system(size: 9, weight: .medium))
            Text(type.shortLabel)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(accent.opacity(0.85))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.10))
                .overlay(Capsule().strokeBorder(accent.opacity(0.22), lineWidth: 0.5))
        )
    }
}

// ── Today Empty State ──────────────────────────────────────────

private struct TodayEmptyState: View {
    var body: some View {
        GlassCard(glowColor: .lcPrimary, glowOpacity: 0.10) {
            HStack(spacing: LCSpacing.md) {
                Image(systemName: "sun.horizon")
                    .font(.system(size: 28, weight: .ultraLight))
                    .foregroundStyle(Color.lcTextTertiary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Nothing planned yet")
                        .font(LCFont.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lcTextSecondary)
                    Text("Open a goal and add a Today step to see it here.")
                        .font(LCFont.insight)
                        .foregroundStyle(Color.lcTextTertiary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(LCSpacing.md)
        }
    }
}

// ── Today All-Complete State ───────────────────────────────────

private struct TodayAllCompleteCard: View {
    var body: some View {
        GlassCard(glowColor: .lcGold, glowOpacity: 0.22) {
            HStack(spacing: LCSpacing.md) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(Color.lcGold.opacity(0.90))
                    .pulseGlow(
                        color:      .lcGold,
                        minOpacity: 0.10,
                        maxOpacity: 0.40,
                        minRadius:  4,
                        maxRadius:  16
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("You've completed today's actions")
                        .font(LCFont.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.lcTextPrimary)
                    Text("You made progress today. That's what matters.")
                        .font(LCFont.insight)
                        .foregroundStyle(Color.lcTextSecondary)
                        .lineSpacing(3)
                }

                Spacer(minLength: 0)
            }
            .padding(LCSpacing.md)
        }
    }
}

// ============================================================
// MARK: - 3. Daily Focus Card
// ============================================================

private struct DailyFocusCard: View {
    let goal:  Goal
    let area:  LifeArea
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            Text("FOCUS GOAL")
                .font(LCFont.overline)
                .foregroundStyle(Color.lcTextTertiary)

            Button(action: onTap) {
                GlassCard(glowColor: .lcGold, glowOpacity: pressed ? 0.38 : 0.24) {
                    VStack(alignment: .leading, spacing: LCSpacing.sm) {

                        HStack(spacing: 6) {
                            if goal.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.lcGold.opacity(0.85))
                            }
                            Image(systemName: area.icon)
                                .font(.system(size: 11, weight: .light))
                                .foregroundStyle(area.accent.opacity(0.80))
                            Text(area.title.uppercased())
                                .font(LCFont.overline)
                                .foregroundStyle(Color.lcTextTertiary)
                            Spacer()
                            Text("\(Int(goal.progress * 100))%")
                                .font(LCFont.overline)
                                .foregroundStyle(Color.lcGold.opacity(0.85))
                        }

                        Text(goal.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.lcTextPrimary)
                            .lineLimit(2)
                            .lineSpacing(3)

                        ProgressBar(
                            value:    goal.progress,
                            maximum:  1.0,
                            height:   5,
                            gradient: [Color.lcGold.opacity(0.65), Color.lcGold],
                            showGlow: true
                        )

                        if let next = goal.nextMilestone {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(Color.lcGold.opacity(0.80))
                                Text("Next: \(next.title)")
                                    .font(LCFont.insight)
                                    .foregroundStyle(Color.lcGold.opacity(0.85))
                                    .lineLimit(1)
                                Spacer()
                                Text("Open →")
                                    .font(LCFont.overline)
                                    .foregroundStyle(Color.lcTextTertiary)
                            }
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
            .pulseGlow(color: .lcGold, minOpacity: 0.06, maxOpacity: 0.18, minRadius: 4, maxRadius: 16)
        }
    }
}

// ============================================================
// MARK: - 4. Life Areas Section
// ============================================================

private struct LifeAreaSection: View {
    @EnvironmentObject var appState: AppState

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            SectionHeader(
                title:    "Life Areas",
                subtitle: appState.lifeAreas.isEmpty
                    ? nil
                    : "Lv. \(appState.overallLevel) · \(Int(appState.overallBalance * 100))% balanced",
                overline: "YOUR JOURNEY"
            )
            .softAppear(delay: 0.30)

            if appState.lifeAreas.isEmpty {
                DashboardEmptyState()
                    .softAppear(delay: 0.36)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(appState.lifeAreas.enumerated()), id: \.element.id) { idx, area in
                        LifeAreaCard(area: area)
                            .softAppear(delay: 0.32 + Double(idx) * 0.06)
                    }
                }
            }
        }
    }
}

// ============================================================
// MARK: - 5. Reflection Prompt Card
// ============================================================

private struct ReflectionPromptCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard(glowColor: .lcLavender, glowOpacity: 0.18) {
                HStack(spacing: LCSpacing.sm) {
                    Image(systemName: "moon.stars")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundStyle(Color.lcLavender.opacity(0.85))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Take a moment to reflect")
                            .font(LCFont.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.lcTextPrimary)
                        Text("You've had a strong week. A few minutes of reflection deepens the growth.")
                            .font(LCFont.insight)
                            .foregroundStyle(Color.lcTextSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.lcTextTertiary.opacity(0.50))
                }
                .padding(LCSpacing.md)
            }
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - 6. Life Balance Section
// ============================================================

private struct LifeBalanceSection: View {
    let areas: [LifeArea]

    var body: some View {
        GlassCard(glowColor: .lcPrimary, glowOpacity: 0.12) {
            VStack(alignment: .leading, spacing: LCSpacing.md) {

                SectionHeader(
                    title:    "Life Balance",
                    subtitle: "How your areas stack up",
                    overline: "OVERVIEW"
                )

                HStack(alignment: .center, spacing: LCSpacing.md) {
                    LifeBalanceRings(areas: areas)
                    Spacer(minLength: 0)
                    BalanceLegend(areas: areas)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(LCSpacing.md)
        }
    }
}

private struct LifeBalanceRings: View {
    let areas: [LifeArea]

    private let maxRings:  Int     = 6
    private let outerSize: CGFloat = 180
    private let ringGap:   CGFloat = 26
    private let lineWidth: CGFloat = 10

    @State private var animated = false

    var body: some View {
        let display = Array(areas.prefix(maxRings))

        ZStack {
            ForEach(Array(display.enumerated()), id: \.element.id) { idx, area in
                let size = outerSize - CGFloat(idx) * ringGap

                Circle()
                    .stroke(area.accent.opacity(0.10),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: size, height: size)

                Circle()
                    .trim(from: 0, to: animated ? area.progress : 0)
                    .stroke(
                        area.accent.opacity(0.80),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: area.accent.opacity(0.35), radius: 7)
                    .animation(.lcRingFill.delay(Double(idx) * 0.10), value: animated)
            }
        }
        .frame(width: outerSize, height: outerSize)
        .onAppear { animated = true }
    }
}

private struct BalanceLegend: View {
    let areas: [LifeArea]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(areas.prefix(6)) { area in
                HStack(spacing: 8) {
                    Circle().fill(area.accent).frame(width: 7, height: 7)
                    Text(area.title)
                        .font(LCFont.insight)
                        .foregroundStyle(Color.lcTextSecondary)
                    Spacer(minLength: 0)
                    Text("\(Int(area.progress * 100))%")
                        .font(LCFont.overline)
                        .foregroundStyle(area.accent.opacity(0.85))
                }
            }
        }
    }
}

// ============================================================
// MARK: - 7. Insight Card
// ============================================================

private struct InsightCardView: View {
    let insight:     DailyInsight
    let xpToday:     Double
    let hasActivity: Bool

    var body: some View {
        GlassCard(glowColor: .lcGold, glowOpacity: 0.22) {
            VStack(alignment: .leading, spacing: LCSpacing.sm) {

                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.lcGold.opacity(0.85))
                    Text("DAILY INSIGHT")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)
                    Spacer()
                    if xpToday > 0 {
                        Text("+\(Int(xpToday)) XP today")
                            .font(LCFont.overline)
                            .foregroundStyle(Color.lcGold.opacity(0.80))
                            .transition(.opacity)
                    }
                }

                Text(insight.text)
                    .font(LCFont.body)
                    .italic()
                    .foregroundStyle(Color.lcTextPrimary.opacity(0.90))
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                if hasActivity {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.lcPrimary.opacity(0.75))
                        Text("You moved forward today")
                            .font(LCFont.insight)
                            .foregroundStyle(Color.lcPrimary.opacity(0.85))
                    }
                    .transition(.opacity)
                }
            }
            .padding(LCSpacing.md)
        }
        .pulseGlow(color: .lcGold, minOpacity: 0.06, maxOpacity: 0.28, minRadius: 4, maxRadius: 18)
        .animation(.lcSoftAppear, value: hasActivity)
    }
}

// ============================================================
// MARK: - 8. Future Self Teaser
// ============================================================

private struct FutureSelfTeaser: View {
    let vision: FutureVision
    let onTap:  () -> Void

    var body: some View {
        GlassCard(glowColor: .lcLavender, glowOpacity: 0.16) {
            VStack(alignment: .leading, spacing: LCSpacing.md) {

                SectionHeader(
                    title:    "Your Future Self",
                    subtitle: "At age \(vision.targetAge)",
                    overline: "VISION"
                )

                Text(vision.narrative)
                    .font(LCFont.body)
                    .foregroundStyle(Color.lcTextSecondary)
                    .lineSpacing(5)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                PrimaryButton(
                    label:    "View Full Vision",
                    icon:     "arrow.forward",
                    gradient: [Color.lcPrimary, Color.lcLavender]
                ) { onTap() }
            }
            .padding(LCSpacing.md)
        }
    }
}

// ============================================================
// MARK: - Dashboard Empty State
// ============================================================

private struct DashboardEmptyState: View {
    var body: some View {
        GlassCard(glowColor: .lcPrimary, glowOpacity: 0.16) {
            VStack(spacing: LCSpacing.md) {
                Image(systemName: "map.fill")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundStyle(Color.lcTextTertiary)

                VStack(spacing: LCSpacing.xs) {
                    Text("Your journey begins here")
                        .font(LCFont.header)
                        .foregroundStyle(Color.lcTextPrimary)

                    Text("Complete onboarding to set your first goal and see your life map take shape.")
                        .font(LCFont.insight)
                        .foregroundStyle(Color.lcTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(LCSpacing.lg)
            .frame(maxWidth: .infinity)
        }
    }
}

// ============================================================
// MARK: - LifeAreaCard (public — reused in GoalsView)
// ============================================================

struct LifeAreaCard: View {
    let area:  LifeArea
    var onTap: () -> Void = {}

    @State private var isPressed:     Bool = false
    @State private var isHighlighted: Bool = false

    var body: some View {
        GlassCard(
            glowColor:   area.accent,
            glowOpacity: isHighlighted ? 0.38 : 0.14
        ) {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: area.icon)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(area.accent.opacity(0.85))

                    Spacer(minLength: LCSpacing.sm)

                    Text(area.title)
                        .font(LCFont.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.lcTextPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Text(area.levelTitle)
                        .font(LCFont.overline)
                        .foregroundStyle(area.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule(style: .continuous).fill(area.accent.opacity(0.15)))

                    Spacer(minLength: LCSpacing.sm)

                    ProgressBar(
                        value:    area.currentXP,
                        maximum:  area.maxXP,
                        height:   5,
                        gradient: area.gradient,
                        showGlow: false
                    )

                    Spacer(minLength: 5)

                    Text(area.xpLabel)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.lcTextTertiary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)

                ProgressRing(
                    value:      area.progress,
                    maximum:    1.0,
                    size:       50,
                    lineWidth:  5,
                    gradient:   area.gradient,
                    trackColor: Color.white.opacity(0.07)
                )
                .padding(12)
            }
        }
        .frame(height: 188)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.lcCardLift, value: isPressed)
        .onLongPressGesture(minimumDuration: 0.45) {
            withAnimation(.lcCardLift) { isHighlighted.toggle() }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isPressed = false }
                    onTap()
                }
        )
    }
}

// ============================================================
// MARK: - ShimmerBar (shared utility — internal)
// ============================================================

struct ShimmerBar: View {
    var width:  CGFloat
    var height: CGFloat
    var radius: CGFloat = 4

    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .frame(maxWidth: width == .infinity ? .infinity : width, maxHeight: height)
            .frame(height: height)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        stops: [
                            .init(color: .clear,               location: 0.0),
                            .init(color: .white.opacity(0.13), location: 0.4),
                            .init(color: .white.opacity(0.20), location: 0.5),
                            .init(color: .white.opacity(0.13), location: 0.6),
                            .init(color: .clear,               location: 1.0),
                        ],
                        startPoint: .leading,
                        endPoint:   .trailing
                    )
                    .frame(width: geo.size.width)
                    .offset(x: phase * geo.size.width)
                    .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

// ============================================================
// MARK: - Previews
// ============================================================

#Preview("Dashboard — Loaded") {
    NavigationStack {
        LifeDashboardView()
    }
    .environmentObject(AppState())
}

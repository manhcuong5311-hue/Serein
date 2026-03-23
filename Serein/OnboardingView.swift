// OnboardingView.swift
// Life Compass — Onboarding Flow
//
// 8 steps. Short, intentional.
// Step 0 — What should we call you?       (name)
// Step 1 — How old are you?               (age — optional)
// Step 2 — Who do you want to become?     (vision)
// Step 3 — Pick your first life area
// Step 4 — Name your first goal
// Step 5 — Add one milestone
// Step 6 — App Overview                   (feature tiles)
// Step 7 — Paywall                        (premium unlock)

import SwiftUI

// ============================================================
// MARK: - OnboardingView
// ============================================================

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: Int = 0

    // Step 0 — name
    @State private var userName: String = ""

    // Step 1 — age
    @State private var ageEnabled: Bool = false
    @State private var userAge:    Int  = 25

    // Step 2 — vision
    @State private var visionText: String = ""

    // Step 3 — life area
    @State private var selectedAreaId: UUID? = nil

    // Step 4 — goal
    @State private var goalTitle: String = ""
    @State private var goalWhy:   String = ""

    // Step 5 — milestone
    @State private var milestoneTitle: String = ""

    private let totalSteps = 8

    var body: some View {
        ZStack {
            LCBackground(showNoise: true)

            VStack(spacing: 0) {
                // Progress bar
                OnboardingProgress(current: step, total: totalSteps)
                    .padding(.horizontal, LCSpacing.md)
                    .padding(.top, LCSpacing.xl)

                Spacer(minLength: LCSpacing.lg)

                // Step content
                Group {
                    switch step {
                    case 0: StepName(userName: $userName)
                    case 1: StepAge(enabled: $ageEnabled, age: $userAge)
                    case 2: StepVision(text: $visionText)
                    case 3: StepLifeArea(areas: appState.lifeAreas, selected: $selectedAreaId)
                    case 4: StepGoal(title: $goalTitle, why: $goalWhy, areaName: selectedAreaName)
                    case 5: StepMilestone(title: $milestoneTitle, goalTitle: goalTitle)
                    case 6: StepAppOverview()
                    case 7: StepPaywall(onFinish: finishOnboarding)
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, LCSpacing.md)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(x: 24)),
                    removal:   .opacity.combined(with: .offset(x: -24))
                ))
                .animation(.lcSoftAppear, value: step)

                Spacer()

                // Navigation buttons
                OnboardingActions(
                    step:       step,
                    totalSteps: totalSteps,
                    canAdvance: canAdvance,
                    onBack:     { withAnimation(.lcSoftAppear) { step -= 1 } },
                    onNext:     advanceStep
                )
                .padding(.horizontal, LCSpacing.md)
                .padding(.bottom, LCSpacing.xl)
            }
        }

    }

    // ── Helpers ───────────────────────────────────────────────

    private var selectedAreaName: String {
        appState.lifeAreas.first { $0.id == selectedAreaId }?.title ?? "your area"
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return userName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1
        case 1: return true                        // age is optional
        case 2: return visionText.count >= 5
        case 3: return selectedAreaId != nil
        case 4: return goalTitle.count >= 3
        case 5: return milestoneTitle.count >= 3
        case 6: return true                        // pure display
        case 7: return true                        // paywall — user can always skip
        default: return false
        }
    }

    private func advanceStep() {
        if step < totalSteps - 1 {
            withAnimation(.lcSoftAppear) { step += 1 }
        } else {
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        // Save user profile
        let name    = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = UserProfile(name: name.isEmpty ? "Friend" : name,
                                  age: ageEnabled ? userAge : nil)
        appState.saveUserProfile(profile)

        // Sync legacy age storage
        if let age = profile.age { appState.currentAge = age }

        // Save vision
        if !visionText.isEmpty {
            var vision = FutureVision.load()
            vision.narrative = visionText
            appState.saveFutureVision(vision)
        }

        // Create goal + milestone
        if let areaId = selectedAreaId, !goalTitle.isEmpty {
            var newGoal = Goal(
                id:         UUID(),
                title:      goalTitle,
                lifeAreaId: areaId,
                why:        goalWhy.isEmpty ? nil : goalWhy,
                milestones: milestoneTitle.isEmpty
                    ? []
                    : [Milestone(title: milestoneTitle)],
                xpReward: 300
            )
            newGoal.isFocusGoal = true
            appState.addGoal(newGoal)
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        appState.onboardingComplete = true
    }
}

// ============================================================
// MARK: - Progress Bar
// ============================================================

private struct OnboardingProgress: View {
    let current: Int
    let total:   Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.lcPrimary : Color.white.opacity(0.12))
                    .frame(height: 3)
                    .animation(.lcSoftAppear, value: current)
            }
        }
    }
}

// ============================================================
// MARK: - Step 0: Name
// ============================================================

private struct StepName: View {
    @Binding var userName: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.lg) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("STEP 1 OF 8")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.04)

                Text("What should\nwe call you?")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .lineSpacing(4)
                    .softAppear(delay: 0.10)

                Text("This app is built around you.")
                    .font(LCFont.insight)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.16)
            }

            GlassCard(glowColor: .lcPrimary, glowOpacity: focused ? 0.22 : 0.10) {
                VStack(alignment: .leading, spacing: LCSpacing.xs) {
                    Text("YOUR NAME")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)

                    TextField("e.g. Alex", text: $userName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.lcTextPrimary)
                        .focused($focused)
                        .submitLabel(.next)
                        .autocorrectionDisabled()
                }
                .padding(LCSpacing.md)
            }
            .softAppear(delay: 0.22)
            .animation(.lcCardLift, value: focused)
            .onAppear { focused = true }
        }
    }
}

// ============================================================
// MARK: - Step 1: Age (optional)
// ============================================================

private struct StepAge: View {
    @Binding var enabled: Bool
    @Binding var age:     Int

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.lg) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("STEP 2 OF 8")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.04)

                Text("How old\nare you?")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .lineSpacing(4)
                    .softAppear(delay: 0.10)

                Text("Optional — helps anchor your Life Map timeline.")
                    .font(LCFont.insight)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.16)
            }

            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.10) {
                VStack(spacing: 0) {
                    Toggle(isOn: $enabled.animation(.lcCardLift)) {
                        HStack(spacing: LCSpacing.sm) {
                            Image(systemName: "person.circle")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(Color.lcTextSecondary.opacity(0.75))
                                .frame(width: 24)
                            Text("Include my age")
                                .font(LCFont.body)
                                .foregroundStyle(Color.lcTextSecondary)
                        }
                    }
                    .tint(Color.lcPrimary)
                    .padding(LCSpacing.md)

                    if enabled {
                        Divider()
                            .background(Color.white.opacity(0.07))
                            .padding(.horizontal, LCSpacing.md)

                        Stepper(
                            value: $age,
                            in:    10...100,
                            step:  1
                        ) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundStyle(Color.lcTextSecondary.opacity(0.75))
                                    .frame(width: 24)
                                Text("Age")
                                    .font(LCFont.body)
                                    .foregroundStyle(Color.lcTextSecondary)
                                Spacer()
                                Text("\(age)")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.lcGold)
                                    .contentTransition(.numericText())
                                    .padding(.trailing, LCSpacing.xs)
                            }
                        }
                        .padding(LCSpacing.md)
                        .transition(.opacity.combined(with: .offset(y: -6)))
                    }
                }
            }
            .softAppear(delay: 0.22)

            if !enabled {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.lcTextTertiary.opacity(0.55))
                    Text("You can always add this later in Settings.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.lcTextTertiary.opacity(0.55))
                }
                .softAppear(delay: 0.30)
            }
        }
    }
}

// ============================================================
// MARK: - Step 2: Vision
// ============================================================

private struct StepVision: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.lg) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("STEP 3 OF 8")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.04)

                Text("Who do you want\nto become?")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .lineSpacing(4)
                    .softAppear(delay: 0.10)

                Text("Write freely. This is only for you.")
                    .font(LCFont.insight)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.16)
            }

            GlassCard(glowColor: .lcPrimary, glowOpacity: focused ? 0.20 : 0.10) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("In 5 years, I am someone who...")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Color.lcTextTertiary)
                            .allowsHitTesting(false)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $text)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.lcTextPrimary)
                        .lineSpacing(6)
                        .frame(minHeight: 140)
                        .fixedSize(horizontal: false, vertical: true)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .focused($focused)
                }
                .padding(LCSpacing.md)
            }
            .softAppear(delay: 0.22)
            .animation(.lcCardLift, value: focused)
        }
    }
}

// ============================================================
// MARK: - Step 3: Life Area
// ============================================================

private struct StepLifeArea: View {
    let areas:    [LifeArea]
    @Binding var selected: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.lg) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("STEP 4 OF 8")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.04)

                Text("Pick your first\nlife area")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .lineSpacing(4)
                    .softAppear(delay: 0.10)

                Text("Where do you want to grow most right now?")
                    .font(LCFont.insight)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.16)
            }

            VStack(spacing: LCSpacing.sm) {
                ForEach(Array(areas.enumerated()), id: \.element.id) { idx, area in
                    AreaPickerRow(
                        area:       area,
                        isSelected: selected == area.id,
                        onTap:      { selected = area.id }
                    )
                    .softAppear(delay: 0.18 + Double(idx) * 0.07)
                }
            }
        }
    }
}

private struct AreaPickerRow: View {
    let area:       LifeArea
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: LCSpacing.sm) {
                Image(systemName: area.icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(area.accent)
                    .frame(width: 24)

                Text(area.title)
                    .font(LCFont.body)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.lcTextPrimary : Color.lcTextSecondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(area.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, LCSpacing.md)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? area.accent.opacity(0.10) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected ? area.accent.opacity(0.35) : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.lcCardLift, value: isSelected)
    }
}

// ============================================================
// MARK: - Step 4: Goal
// ============================================================

private struct StepGoal: View {
    @Binding var title:   String
    @Binding var why:     String
    let areaName: String

    @FocusState private var focusedField: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.lg) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("STEP 5 OF 8")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.04)

                Text("Name your\nfirst goal")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .lineSpacing(4)
                    .softAppear(delay: 0.10)

                Text("In \(areaName). Make it real.")
                    .font(LCFont.insight)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.16)
            }

            VStack(spacing: LCSpacing.sm) {
                GlassCard(glowColor: .lcPrimary, glowOpacity: focusedField == 0 ? 0.18 : 0.08) {
                    VStack(alignment: .leading, spacing: LCSpacing.xs) {
                        Text("GOAL")
                            .font(LCFont.overline)
                            .foregroundStyle(Color.lcTextTertiary)

                        TextField("Run a 5K, build a side project...", text: $title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.lcTextPrimary)
                            .focused($focusedField, equals: 0)
                    }
                    .padding(LCSpacing.md)
                }
                .softAppear(delay: 0.20)
                .animation(.lcCardLift, value: focusedField == 0)

                GlassCard(glowColor: .lcPrimary, glowOpacity: focusedField == 1 ? 0.14 : 0.06) {
                    VStack(alignment: .leading, spacing: LCSpacing.xs) {
                        Text("WHY THIS MATTERS  (optional)")
                            .font(LCFont.overline)
                            .foregroundStyle(Color.lcTextTertiary)

                        ZStack(alignment: .topLeading) {
                            if why.isEmpty {
                                Text("Because it will change how I feel about...")
                                    .font(LCFont.body)
                                    .foregroundStyle(Color.lcTextTertiary)
                                    .allowsHitTesting(false)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                            TextEditor(text: $why)
                                .font(LCFont.body)
                                .foregroundStyle(Color.lcTextPrimary)
                                .frame(minHeight: 72)
                                .fixedSize(horizontal: false, vertical: true)
                                .scrollContentBackground(.hidden)
                                .background(.clear)
                                .focused($focusedField, equals: 1)
                        }
                    }
                    .padding(LCSpacing.md)
                }
                .softAppear(delay: 0.28)
                .animation(.lcCardLift, value: focusedField == 1)
            }
        }
    }
}

// ============================================================
// MARK: - Step 5: Milestone
// ============================================================

private struct StepMilestone: View {
    @Binding var title:    String
    let goalTitle: String

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.lg) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("STEP 6 OF 8")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.04)

                Text("Your first\nnext step")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .lineSpacing(4)
                    .softAppear(delay: 0.10)

                Text(verbatim: "The one action that moves \(goalTitle) forward today.")
                    .font(LCFont.insight)
                    .foregroundStyle(Color.lcTextTertiary)
                    .lineLimit(2)
                    .lineSpacing(3)
                    .softAppear(delay: 0.16)
            }

            GlassCard(glowColor: .lcPrimary, glowOpacity: focused ? 0.20 : 0.10) {
                VStack(alignment: .leading, spacing: LCSpacing.xs) {
                    Text("MILESTONE")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)

                    TextField("e.g. Sign up for a local 5K", text: $title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.lcTextPrimary)
                        .focused($focused)
                }
                .padding(LCSpacing.md)
            }
            .softAppear(delay: 0.22)
            .animation(.lcCardLift, value: focused)

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color.lcTextTertiary.opacity(0.55))
                Text("You can add daily steps and more milestones from the Goals screen.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.lcTextTertiary.opacity(0.55))
                    .lineSpacing(3)
            }
            .softAppear(delay: 0.34)
        }
    }
}

// ============================================================
// MARK: - Step 6: App Overview
// ============================================================

private struct FeatureTileData: Identifiable {
    let id    = UUID()
    let icon:  String
    let color: Color
    let title: String
    let desc:  String
}

private struct StepAppOverview: View {

    private let tiles: [FeatureTileData] = [
        FeatureTileData(icon: "scope",                     color: .lcPrimary,              title: "Set Goals",     desc: "Define what truly matters across 6 life areas"),
        FeatureTileData(icon: "sun.max",                   color: .lcGold,                 title: "Plan Daily",    desc: "Break goals into small steps. Know exactly what to do today"),
        FeatureTileData(icon: "arrow.clockwise",           color: .lcLavender,             title: "Build Habits",  desc: "Recurring steps reset each morning to build momentum"),
        FeatureTileData(icon: "chart.line.uptrend.xyaxis", color: Color(lcHex: "#C4856A"), title: "Track Growth",  desc: "XP and level up as you complete milestones"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: LCSpacing.sm),
        GridItem(.flexible(), spacing: LCSpacing.sm),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.lg) {
            // Header
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("STEP 7 OF 8")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.04)

                Text("How Serein\nworks")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .lineSpacing(4)
                    .softAppear(delay: 0.10)
            }

            // Big icon
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.lcPrimary.opacity(0.25), Color.lcLavender.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)

                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.lcPrimary, Color.lcLavender],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .softAppear(delay: 0.14)

                Spacer()
            }

            // Subtitle
            Text("Your personal life execution system")
                .font(LCFont.insight)
                .foregroundStyle(Color.lcTextSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .softAppear(delay: 0.18)

            // 2×2 feature grid
            LazyVGrid(columns: columns, spacing: LCSpacing.sm) {
                ForEach(Array(tiles.enumerated()), id: \.element.id) { idx, tile in
                    FeatureTile(tile: tile)
                        .softAppear(delay: 0.22 + Double(idx) * 0.08)
                }
            }
        }
    }
}

private struct FeatureTile: View {
    let tile: FeatureTileData

    var body: some View {
        GlassCard(glowColor: tile.color, glowOpacity: 0.12) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Image(systemName: tile.icon)
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(tile.color)
                    .frame(width: 28, height: 28)

                Text(tile.title)
                    .font(LCFont.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.lcTextPrimary)

                Text(tile.desc)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lcTextTertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(LCSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// ============================================================
// MARK: - Step 7: Paywall
// ============================================================

private struct PaywallFeature: Identifiable {
    let id:       UUID   = UUID()
    let icon:     String
    let title:    String
    let subtitle: String
}

private struct StepPaywall: View {
    let onFinish: () -> Void   // called after purchase success OR free skip

    @ObservedObject private var access = FeatureAccessManager.shared
    @State private var glowing = false

    private var isPurchasing: Bool {
        access.purchaseState == .loading || access.purchaseState == .purchasing
    }

    private let features: [PaywallFeature] = [
        PaywallFeature(icon: "infinity",            title: "Unlimited Goals",  subtitle: "No cap across any life area"),
        PaywallFeature(icon: "calendar.badge.plus", title: "Scheduled Steps",  subtitle: "Plan actions on specific dates"),
        PaywallFeature(icon: "arrow.clockwise",     title: "Daily Habits",     subtitle: "Steps that auto-reset each morning"),
        PaywallFeature(icon: "tray.full",           title: "Smart Backlog",    subtitle: "Anytime steps with no deadline"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: LCSpacing.md) {

                // ── Hero ──────────────────────────────────────
                VStack(spacing: 14) {

                    // Animated glow orb
                    ZStack {
                        Circle()
                            .fill(Color.lcGold.opacity(glowing ? 0.22 : 0.08))
                            .frame(width: 100, height: 100)
                            .blur(radius: 16)

                        Circle()
                            .fill(Color.lcGold.opacity(0.10))
                            .frame(width: 66, height: 66)
                            .overlay(
                                Circle().strokeBorder(
                                    LinearGradient(
                                        colors: [Color.lcGold.opacity(0.50), Color.lcGold.opacity(0.15)],
                                        startPoint: .topLeading,
                                        endPoint:   .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                            )

                        Image(systemName: "sparkles")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.lcGold, Color.lcGold.opacity(0.65)],
                                    startPoint: .topLeading,
                                    endPoint:   .bottomTrailing
                                )
                            )
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                            glowing = true
                        }
                    }

                    // Title + subtitle
                    VStack(spacing: 6) {
                        Text("Go Premium")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Color.lcTextPrimary)

                        Text("One purchase. Every feature. Forever.")
                            .font(LCFont.insight)
                            .foregroundStyle(Color.lcTextSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Price badge
                    Text("$9.99  ·  Lifetime  ·  No subscription")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.lcGold)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.lcGold.opacity(0.10))
                                .overlay(
                                    Capsule().strokeBorder(Color.lcGold.opacity(0.35), lineWidth: 0.5)
                                )
                        )
                }
                .frame(maxWidth: .infinity)
                .softAppear(delay: 0.06)

                // ── Feature list ──────────────────────────────
                GlassCard(glowColor: .lcGold, glowOpacity: 0.16) {
                    VStack(spacing: 0) {
                        ForEach(Array(features.enumerated()), id: \.element.id) { idx, f in
                            if idx > 0 {
                                Divider()
                                    .padding(.horizontal, LCSpacing.md)
                            }
                            HStack(spacing: LCSpacing.sm) {
                                // Icon tile
                                ZStack {
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color.lcGold.opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: f.icon)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.lcGold)
                                }

                                // Labels
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(f.title)
                                        .font(LCFont.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.lcTextPrimary)
                                    Text(f.subtitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.lcTextTertiary)
                                }

                                Spacer()

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.lcGold.opacity(0.70))
                            }
                            .padding(.horizontal, LCSpacing.md)
                            .padding(.vertical, 14)
                        }
                    }
                }
                .softAppear(delay: 0.18)

                // ── Free plan reassurance ─────────────────────
                GlassCard(glowColor: .lcPrimary, glowOpacity: 0.06) {
                    HStack(spacing: LCSpacing.sm) {
                        Image(systemName: "gift")
                            .font(.system(size: 15, weight: .light))
                            .foregroundStyle(Color.lcPrimary.opacity(0.70))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Free plan always available")
                                .font(LCFont.body)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.lcTextSecondary)
                            Text("1 goal per area · Today & Tomorrow steps · No time limit")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.lcTextTertiary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(LCSpacing.md)
                }
                .softAppear(delay: 0.26)

                // ── CTAs ──────────────────────────────────────
                VStack(spacing: 12) {

                    // Unlock button — triggers real App Store purchase
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        Task {
                            await access.purchase()
                            // Auto-advance when purchase succeeds
                            if access.isPremium { onFinish() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isPurchasing {
                                ProgressView().tint(.white).scaleEffect(0.85)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(isPurchasing
                                 ? "Processing…"
                                 : "Unlock Premium — \(access.displayPrice)")
                                .fontWeight(.semibold)
                        }
                        .font(LCFont.body)
                        .foregroundStyle(.white)
                        .padding(.vertical, 16)
                        .padding(.horizontal, LCSpacing.lg)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.lcGold, Color(lcHex: "#A8722E")],
                                        startPoint: .topLeading,
                                        endPoint:   .bottomTrailing
                                    )
                                    .opacity(0.90)
                                )
                                .shadow(color: Color.lcGold.opacity(0.40), radius: 18, x: 0, y: 8)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)

                    Button(action: onFinish) {
                        Text("Continue with Free Plan")
                            .font(LCFont.insight)
                            .foregroundStyle(Color.lcTextTertiary)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)
                }
                .softAppear(delay: 0.32)

                Spacer(minLength: LCSpacing.md)
            }
        }
    }
}

// ============================================================
// MARK: - Navigation Actions
// ============================================================

private struct OnboardingActions: View {
    let step:       Int
    let totalSteps: Int
    let canAdvance: Bool
    let onBack:     () -> Void
    let onNext:     () -> Void

    // Step 7 (index) is the paywall — it owns its CTAs; hide all actions here.
    private var isPaywallStep: Bool { step == totalSteps - 1 }

    var body: some View {
        // Paywall step renders nothing here — StepPaywall has its own buttons.
        if !isPaywallStep {
            VStack(spacing: LCSpacing.sm) {
                PrimaryButton(
                    label:    "Continue",
                    icon:     "arrow.right",
                    gradient: [Color.lcPrimary, Color.lcLavender]
                ) { onNext() }
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1.0 : 0.40)

                if step > 0 {
                    Button(action: onBack) {
                        Text("Back")
                            .font(LCFont.insight)
                            .foregroundStyle(Color.lcTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(AppState())
}

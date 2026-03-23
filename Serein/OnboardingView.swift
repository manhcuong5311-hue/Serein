// OnboardingView.swift
// Life Compass — Onboarding Flow
//
// 6 steps. Short, intentional.
// Step 0 — What should we call you?       (name)
// Step 1 — How old are you?               (age — optional)
// Step 2 — Who do you want to become?     (vision)
// Step 3 — Pick your first life area
// Step 4 — Name your first goal
// Step 5 — Add one milestone

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

    private let totalSteps = 6

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
        .preferredColorScheme(.dark)
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
                Text("STEP 1 OF 6")
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
                Text("STEP 2 OF 6")
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
                Text("STEP 3 OF 6")
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
                Text("STEP 4 OF 6")
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
                Text("STEP 5 OF 6")
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
                Text("STEP 6 OF 6")
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
// MARK: - Navigation Actions
// ============================================================

private struct OnboardingActions: View {
    let step:       Int
    let totalSteps: Int
    let canAdvance: Bool
    let onBack:     () -> Void
    let onNext:     () -> Void

    private var isLastStep: Bool { step == totalSteps - 1 }

    var body: some View {
        VStack(spacing: LCSpacing.sm) {
            PrimaryButton(
                label:    isLastStep ? "Start My Journey" : "Continue",
                icon:     isLastStep ? "arrow.right.circle.fill" : "arrow.right",
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

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Onboarding") {
    OnboardingView()
        .environmentObject(AppState())
}

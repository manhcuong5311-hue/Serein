// WeeklyReflectionView.swift
// Life Compass — Weekly Reflection Screen
//
// Design philosophy: slow the user down. No rush.
// Every question gets full space. No clutter.
//
// Sections
//   Header      — week range + optional streak badge
//   Questions   — 3 GlassCard prompts with calm TextEditors
//   Mood tags   — optional quick-select row
//   Actions     — Submit (validated) + Skip (no guilt)
//
// States
//   writing  → scrollable form
//   saving   → brief loading
//   saved    → full-screen success (glow + XP + streak)
//   skipped  → gentle exit card

import SwiftUI

// ============================================================
// MARK: - WeeklyReflectionView
// ============================================================

struct WeeklyReflectionView: View {
    var onReflectionSaved: (WeeklyReflection) -> Void = { _ in }

    @StateObject private var vm = WeeklyReflectionViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LCBackground(showNoise: true)

            switch vm.phase {
            case .writing, .saving:
                ReflectionForm(vm: vm)
                    .transition(.opacity)

            case .saved(let streakMsg):
                ReflectionSuccessView(
                    xpEarned:      vm.reflection.xpEarned,
                    streakMessage: streakMsg,
                    onContinue:    { dismiss() }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.96)),
                    removal:   .opacity
                ))

            case .skipped:
                ReflectionSkippedView(onDismiss: { dismiss() })
                    .transition(.opacity)
            }
        }
        .animation(.lcSoftAppear, value: vm.phase == .writing)
        .preferredColorScheme(.dark)
        .onAppear { vm.onReflectionSaved = onReflectionSaved }
    }
}

// ============================================================
// MARK: - Reflection Form
// ============================================================

private struct ReflectionForm: View {
    @ObservedObject var vm: WeeklyReflectionViewModel
    @FocusState private var focusedField: Int?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: LCSpacing.xl) {

                ReflectionHeader(streak: vm.streak)

                // Questions
                ForEach(Array(ReflectionQuestion.all.enumerated()), id: \.element.id) { idx, question in
                    QuestionCard(
                        question: question,
                        answer:   Binding(
                            get: { vm.reflection.answers[idx] },
                            set: { vm.updateAnswer($0, at: idx) }
                        ),
                        isFocused: focusedField == idx,
                        onFocus:   { focusedField = idx }
                    )
                    .softAppear(delay: 0.10 + Double(idx) * 0.12)
                }

                // Mood tags
                MoodTagSection(
                    selected: vm.reflection.moodTags,
                    onToggle: { vm.toggleMoodTag($0) }
                )
                .softAppear(delay: 0.44)

                // Progress hint
                if vm.filledCount > 0 {
                    Text("\(vm.filledCount) of 3 questions answered")
                        .font(LCFont.insight)
                        .foregroundStyle(Color.lcTextTertiary)
                        .frame(maxWidth: .infinity)
                        .softAppear(delay: 0.0)
                        .transition(.opacity)
                }

                // Actions
                ReflectionActions(vm: vm)
                    .softAppear(delay: 0.50)
            }
            .padding(.horizontal, LCSpacing.md)
            .padding(.top, LCSpacing.xl)
            .padding(.bottom, LCSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// ============================================================
// MARK: - Header
// ============================================================

private struct ReflectionHeader: View {
    let streak: Int

    private var weekRange: String {
        let cal   = Calendar.current
        let start = cal.startOfWeek(for: Date())
        let end   = cal.date(byAdding: .day, value: 6, to: start) ?? start
        let fmt   = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.xs) {
            Text("WEEKLY REFLECTION")
                .font(LCFont.overline)
                .foregroundStyle(Color.lcTextTertiary)
                .softAppear(delay: 0.04)

            Text("Look inward.")
                .font(LCFont.largeTitle)
                .foregroundStyle(Color.lcTextPrimary)
                .softAppear(delay: 0.08)

            Text(weekRange)
                .font(LCFont.insight)
                .foregroundStyle(Color.lcTextTertiary)
                .softAppear(delay: 0.12)

            if streak >= 2 {
                StreakBadge(streak: streak)
                    .padding(.top, LCSpacing.xs)
                    .softAppear(delay: 0.18)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.lcGold)
            Text("You've reflected \(streak) weeks in a row")
                .font(LCFont.insight)
                .foregroundStyle(Color.lcGold.opacity(0.85))
        }
        .padding(.horizontal, LCSpacing.sm)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.lcGold.opacity(0.10))
                .overlay(Capsule().strokeBorder(Color.lcGold.opacity(0.20), lineWidth: 0.5))
        )
    }
}

// ============================================================
// MARK: - Question Card
// ============================================================

private struct QuestionCard: View {
    let question:  ReflectionQuestion
    @Binding var answer:    String
    let isFocused: Bool
    let onFocus:   () -> Void

    var body: some View {
        GlassCard(
            glowColor:   Color.lcPrimary,
            glowOpacity: isFocused ? 0.22 : 0.10
        ) {
            VStack(alignment: .leading, spacing: LCSpacing.md) {

                // Question number + icon
                HStack(alignment: .center) {
                    Text("0\(question.id)")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)
                    Spacer()
                    Image(systemName: question.icon)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Color.lcPrimary.opacity(0.65))
                }

                // Question text — large, readable, not cramped
                Text(question.text)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.lcTextPrimary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .background(Color.white.opacity(0.06))

                // Text editor with placeholder
                ZStack(alignment: .topLeading) {
                    if answer.isEmpty {
                        Text(question.placeholder)
                            .font(LCFont.body)
                            .foregroundStyle(Color.lcTextTertiary)
                            .allowsHitTesting(false)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $answer)
                        .font(LCFont.body)
                        .foregroundStyle(Color.lcTextPrimary)
                        .frame(minHeight: 110)
                        .fixedSize(horizontal: false, vertical: true)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .onTapGesture { onFocus() }
                }
            }
            .padding(LCSpacing.md)
        }
        .animation(.lcCardLift, value: isFocused)
    }
}

// ============================================================
// MARK: - Mood Tag Section
// ============================================================

private struct MoodTagSection: View {
    let selected: [MoodTag]
    let onToggle: (MoodTag) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {
            Text("HOW DID THIS WEEK FEEL?")
                .font(LCFont.overline)
                .foregroundStyle(Color.lcTextTertiary)

            Text("Optional — choose what resonates.")
                .font(LCFont.insight)
                .foregroundStyle(Color.lcTextTertiary)

            HStack(spacing: 10) {
                ForEach(MoodTag.allCases, id: \.self) { tag in
                    MoodChip(
                        tag:        tag,
                        isSelected: selected.contains(tag),
                        onTap:      { onToggle(tag) }
                    )
                }
            }
        }
    }
}

private struct MoodChip: View {
    let tag:        MoodTag
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: tag.icon)
                    .font(.system(size: 10, weight: .medium))
                Text(tag.label)
                    .font(LCFont.overline)
            }
            .foregroundStyle(isSelected ? tag.accent : Color.lcTextTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? tag.accent.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? tag.accent.opacity(0.40) : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.lcCardLift, value: isSelected)
    }
}

// ============================================================
// MARK: - Actions
// ============================================================

private struct ReflectionActions: View {
    @ObservedObject var vm: WeeklyReflectionViewModel

    var body: some View {
        VStack(spacing: LCSpacing.md) {

            PrimaryButton(
                label:    vm.phase == .saving ? "Saving…" : "Save Reflection",
                icon:     vm.phase == .saving ? "ellipsis" : "checkmark",
                gradient: [Color.lcPrimary, Color.lcLavender]
            ) {
                Task { await vm.submitReflection() }
            }
            .disabled(!vm.canSubmit || vm.phase == .saving)
            .opacity(vm.canSubmit ? 1.0 : 0.45)
            .frame(maxWidth: .infinity)

            // Skip — no guilt, no pressure
            Button(action: vm.skipReflection) {
                Text("Skip this week — no pressure")
                    .font(LCFont.insight)
                    .foregroundStyle(Color.lcTextTertiary)
            }
            .buttonStyle(.plain)
        }
    }
}

// ============================================================
// MARK: - Success Screen
// ============================================================

private struct ReflectionSuccessView: View {
    let xpEarned:      Double
    let streakMessage: String?
    let onContinue:    () -> Void

    var body: some View {
        VStack(spacing: LCSpacing.xl) {
            Spacer()

            // Glow icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72, weight: .ultraLight))
                .foregroundStyle(Color.lcGold.opacity(0.90))
                .pulseGlow(
                    color:      .lcGold,
                    minOpacity: 0.15,
                    maxOpacity: 0.55,
                    minRadius:  8,
                    maxRadius:  32
                )
                .softAppear(delay: 0.05)

            VStack(spacing: LCSpacing.sm) {
                Text("Reflection saved.")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .softAppear(delay: 0.12)

                Text("+\(Int(xpEarned)) XP earned")
                    .font(LCFont.header)
                    .foregroundStyle(Color.lcGold)
                    .softAppear(delay: 0.18)

                if let msg = streakMessage {
                    Text(msg)
                        .font(LCFont.body)
                        .foregroundStyle(Color.lcTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, LCSpacing.lg)
                        .softAppear(delay: 0.26)
                }
            }

            Spacer()

            PrimaryButton(
                label:    "Continue",
                icon:     "arrow.forward",
                gradient: [Color.lcGold.opacity(0.8), Color.lcGold]
            ) { onContinue() }
            .softAppear(delay: 0.34)
            .padding(.bottom, LCSpacing.xl)
        }
        .padding(.horizontal, LCSpacing.lg)
    }
}

// ============================================================
// MARK: - Skipped Screen
// ============================================================
// Calm, non-judgmental. Life happens.

private struct ReflectionSkippedView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: LCSpacing.xl) {
            Spacer()

            Image(systemName: "moon.stars")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(Color.lcTextTertiary)
                .softAppear(delay: 0.05)

            VStack(spacing: LCSpacing.sm) {
                Text("That's okay.")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .softAppear(delay: 0.10)

                Text("Awareness doesn't require a form.\nWe'll be here next week.")
                    .font(LCFont.body)
                    .foregroundStyle(Color.lcTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .softAppear(delay: 0.16)
            }

            Spacer()

            Button(action: onDismiss) {
                Text("Close")
                    .font(LCFont.body)
                    .foregroundStyle(Color.lcTextSecondary)
            }
            .buttonStyle(.plain)
            .softAppear(delay: 0.24)
            .padding(.bottom, LCSpacing.xl)
        }
        .padding(.horizontal, LCSpacing.lg)
    }
}

// ============================================================
// MARK: - Previews
// ============================================================

#Preview("Reflection — Writing") {
    WeeklyReflectionView()
}

#Preview("Reflection — Saved") {
    ZStack {
        LCBackground(showNoise: true)
        ReflectionSuccessView(
            xpEarned:      50,
            streakMessage: "You've reflected 3 weeks in a row. Momentum is building.",
            onContinue:    {}
        )
    }
    .preferredColorScheme(.dark)
}

#Preview("Reflection — Skipped") {
    ZStack {
        LCBackground(showNoise: true)
        ReflectionSkippedView(onDismiss: {})
    }
    .preferredColorScheme(.dark)
}

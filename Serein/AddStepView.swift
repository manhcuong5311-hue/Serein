// AddStepView.swift
// Life Compass — Add Goal Step Sheet
//
// Modal sheet presented from GoalDetailView.
// Lets the user define a step title, choose its type, and
// (when type == .scheduled) pick a date.

import SwiftUI

// ============================================================
// MARK: - AddStepView
// ============================================================

struct AddStepView: View {
    let goalId:  UUID
    let onSave:  (GoalStep) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title:         String   = ""
    @State private var selectedType:  StepType = .today
    @State private var scheduledDate: Date     = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    @FocusState private var titleFocused: Bool

    private var canSave: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).count >= 1
    }

    var body: some View {
        ZStack {
            LCBackground(showNoise: true)

            VStack(alignment: .leading, spacing: 0) {

                // ── Handle & Header ────────────────────────────
                VStack(alignment: .leading, spacing: LCSpacing.sm) {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 36, height: 4)
                        .frame(maxWidth: .infinity)
                        .padding(.top, LCSpacing.md)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ADD STEP")
                                .font(LCFont.overline)
                                .foregroundStyle(Color.lcTextTertiary)
                            Text("What will you do?")
                                .font(LCFont.header)
                                .foregroundStyle(Color.lcTextPrimary)
                        }
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26, weight: .light))
                                .foregroundStyle(Color.white.opacity(0.22))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, LCSpacing.md)
                .padding(.bottom, LCSpacing.lg)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: LCSpacing.lg) {

                        // ── Title input ────────────────────────
                        GlassCard(glowColor: .lcPrimary, glowOpacity: titleFocused ? 0.20 : 0.08) {
                            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                                Text("STEP")
                                    .font(LCFont.overline)
                                    .foregroundStyle(Color.lcTextTertiary)
                                TextField("Describe the action…", text: $title)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.lcTextPrimary)
                                    .focused($titleFocused)
                                    .submitLabel(.done)
                                    .onSubmit { if canSave { save() } }
                            }
                            .padding(LCSpacing.md)
                        }
                        .animation(.lcCardLift, value: titleFocused)

                        // ── Step type picker ───────────────────
                        VStack(alignment: .leading, spacing: LCSpacing.sm) {
                            Text("WHEN")
                                .font(LCFont.overline)
                                .foregroundStyle(Color.lcTextTertiary)

                            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.08) {
                                VStack(spacing: 0) {
                                    ForEach(Array(StepType.allCases.enumerated()), id: \.element) { idx, type in
                                        StepTypeRow(
                                            type:       type,
                                            isSelected: selectedType == type,
                                            onTap:      { withAnimation(.lcCardLift) { selectedType = type } }
                                        )
                                        if idx < StepType.allCases.count - 1 {
                                            Divider()
                                                .background(Color.white.opacity(0.06))
                                                .padding(.horizontal, LCSpacing.md)
                                        }
                                    }
                                }
                            }
                        }

                        // ── Date picker (scheduled only) ───────
                        if selectedType == .scheduled {
                            VStack(alignment: .leading, spacing: LCSpacing.sm) {
                                Text("DATE")
                                    .font(LCFont.overline)
                                    .foregroundStyle(Color.lcTextTertiary)

                                GlassCard(glowColor: .lcPrimary, glowOpacity: 0.10) {
                                    DatePicker(
                                        "",
                                        selection:   $scheduledDate,
                                        in:          Date()...,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.graphical)
                                    .tint(Color.lcPrimary)
                                    .labelsHidden()
                                    .padding(LCSpacing.sm)
                                }
                            }
                            .transition(.opacity.combined(with: .offset(y: -8)))
                        }

                        // ── Type description hint ──────────────
                        TypeHintCard(type: selectedType)
                            .animation(.lcSoftAppear, value: selectedType)
                    }
                    .padding(.horizontal, LCSpacing.md)
                    .padding(.bottom, LCSpacing.xxl)
                    .animation(.lcSoftAppear, value: selectedType)
                }

                // ── Save button ────────────────────────────────
                VStack(spacing: 0) {
                    Divider().background(Color.white.opacity(0.07))
                    PrimaryButton(
                        label:    "Add Step",
                        icon:     "plus.circle.fill",
                        gradient: [Color.lcPrimary, Color.lcLavender]
                    ) { save() }
                    .disabled(!canSave)
                    .opacity(canSave ? 1.0 : 0.40)
                    .padding(.horizontal, LCSpacing.md)
                    .padding(.vertical, LCSpacing.md)
                }
                .background(.ultraThinMaterial)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { titleFocused = true }
    }

    // ── Action ────────────────────────────────────────────────

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let step = GoalStep(
            goalId:        goalId,
            title:         trimmed,
            type:          selectedType,
            scheduledDate: selectedType == .scheduled ? scheduledDate : nil
        )
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSave(step)
        dismiss()
    }
}

// ============================================================
// MARK: - StepTypeRow
// ============================================================

private struct StepTypeRow: View {
    let type:       StepType
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: LCSpacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(isSelected ? Color.lcPrimary : Color.lcTextTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(LCFont.body)
                        .fontWeight(.medium)
                        .foregroundStyle(isSelected ? Color.lcTextPrimary : Color.lcTextSecondary)

                    Text(type.typeDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.lcTextTertiary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.lcPrimary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, LCSpacing.md)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.lcPrimary.opacity(0.06) : .clear)
        .animation(.lcCardLift, value: isSelected)
    }
}

// ============================================================
// MARK: - Type Hint Card
// ============================================================

private struct TypeHintCard: View {
    let type: StepType

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(Color.lcTextTertiary.opacity(0.55))
            Text(type.typeDescription)
                .font(.system(size: 13))
                .foregroundStyle(Color.lcTextTertiary.opacity(0.65))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, LCSpacing.xs)
    }
}

// ============================================================
// MARK: - StepType Descriptions
// ============================================================

private extension StepType {
    var typeDescription: String {
        switch self {
        case .today:
            return "Appears on your Dashboard today. High priority."
        case .tomorrow:
            return "Automatically becomes a Today step tomorrow morning."
        case .scheduled:
            return "Appears on the day you schedule it. Good for planned work."
        case .anytime:
            return "No deadline. Sits in your backlog until you're ready."
        case .recurringDaily:
            return "Resets every morning. Great for habits and routines."
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Add Step") {
    AddStepView(goalId: UUID()) { _ in }
        .environmentObject(AppState())
}

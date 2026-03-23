// AddGoalView.swift
// Life Compass — Add Goal Modal
//
// Presented as a sheet from GoalsView.
// Three sections: area picker → goal title + why → optional first milestone.
// Single-page, no steps — intentionally compact.

import SwiftUI

// ============================================================
// MARK: - AddGoalView
// ============================================================

struct AddGoalView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var access = FeatureAccessManager.shared

    @State private var selectedAreaId:  UUID?   = nil
    @State private var goalTitle:       String  = ""
    @State private var goalWhy:         String  = ""
    @State private var milestoneTitle:  String  = ""
    @State private var xpReward:        Double  = 300
    @State private var isSaving:        Bool    = false
    @State private var showPremium:     Bool    = false

    @FocusState private var focusedField: Field?
    enum Field { case title, why, milestone }

    private var selectedArea: LifeArea? {
        appState.lifeAreas.first { $0.id == selectedAreaId }
    }

    private var canSave: Bool {
        selectedAreaId != nil && goalTitle.trimmingCharacters(in: .whitespaces).count >= 2
    }

    var body: some View {
        ZStack {
            LCBackground(showNoise: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: LCSpacing.xl) {

                    // ── Header ────────────────────────────────
                    AddGoalHeader(onDismiss: { dismiss() })

                    // ── Life Area Picker ──────────────────────
                    AreaPickerSection(
                        areas:    appState.lifeAreas,
                        selected: $selectedAreaId
                    )

                    // ── Goal Details ──────────────────────────
                    GoalDetailsSection(
                        title:        $goalTitle,
                        why:          $goalWhy,
                        areaAccent:   selectedArea?.accent ?? .lcPrimary,
                        focusedField: $focusedField
                    )

                    // ── First Milestone ───────────────────────
                    FirstMilestoneSection(
                        milestone:    $milestoneTitle,
                        goalTitle:    goalTitle,
                        accent:       selectedArea?.accent ?? .lcPrimary,
                        focusedField: $focusedField
                    )

                    // ── XP Slider ─────────────────────────────
                    XPPickerSection(xpReward: $xpReward, accent: selectedArea?.accent ?? .lcPrimary)

                    // ── Save Button ───────────────────────────
                    PrimaryButton(
                        label:    isSaving ? "Saving…" : "Create Goal",
                        icon:     isSaving ? "ellipsis" : "checkmark",
                        gradient: selectedArea.map { [$0.accent.opacity(0.8), $0.accent] }
                            ?? [Color.lcPrimary, Color.lcLavender]
                    ) { save() }
                    .disabled(!canSave || isSaving)
                    .opacity(canSave ? 1.0 : 0.40)
                    .frame(maxWidth: .infinity)
                    .animation(.lcSoftAppear, value: canSave)
                }
                .padding(.horizontal, LCSpacing.md)
                .padding(.top, LCSpacing.xl)
                .padding(.bottom, LCSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showPremium) {
            PremiumView()
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
    }

    // ── Save ──────────────────────────────────────────────────

    private func save() {
        guard let areaId = selectedAreaId else { return }
        guard access.canAddGoal(in: areaId, goals: appState.goals) else {
            showPremium = true
            return
        }
        isSaving = true

        let trimmedTitle     = goalTitle.trimmingCharacters(in: .whitespaces)
        let trimmedWhy       = goalWhy.trimmingCharacters(in: .whitespaces)
        let trimmedMilestone = milestoneTitle.trimmingCharacters(in: .whitespaces)

        var newGoal = Goal(
            id:         UUID(),
            title:      trimmedTitle,
            lifeAreaId: areaId,
            why:        trimmedWhy.isEmpty ? nil : trimmedWhy,
            milestones: trimmedMilestone.isEmpty ? [] : [Milestone(title: trimmedMilestone)],
            xpReward:   xpReward
        )

        // Make it the focus goal if user has no other focus set
        let hasManualFocus = appState.goals.contains { $0.isFocusGoal && !$0.isComplete && !$0.isArchived }
        if !hasManualFocus { newGoal.isFocusGoal = true }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        appState.addGoal(newGoal)
        dismiss()
    }
}

// ============================================================
// MARK: - Header
// ============================================================

private struct AddGoalHeader: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("NEW GOAL")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.04)
                Text("What will you achieve?")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .softAppear(delay: 0.08)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lcTextTertiary)
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .softAppear(delay: 0.06)
        }
    }
}

// ============================================================
// MARK: - Area Picker Section
// ============================================================

private struct AreaPickerSection: View {
    let areas:    [LifeArea]
    @Binding var selected: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {
            Text("LIFE AREA")
                .font(LCFont.overline)
                .foregroundStyle(Color.lcTextTertiary)
                .softAppear(delay: 0.12)

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(areas.enumerated()), id: \.element.id) { idx, area in
                    AreaChip(
                        area:       area,
                        isSelected: selected == area.id,
                        onTap:      { selected = area.id }
                    )
                    .softAppear(delay: 0.14 + Double(idx) * 0.05)
                }
            }
        }
    }
}

private struct AreaChip: View {
    let area:       LifeArea
    let isSelected: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        }) {
            HStack(spacing: 8) {
                Image(systemName: area.icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(isSelected ? area.accent : Color.lcTextTertiary)
                    .frame(width: 20)
                Text(area.title)
                    .font(LCFont.insight)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.lcTextPrimary : Color.lcTextSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(area.accent)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? area.accent.opacity(0.12) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                isSelected ? area.accent.opacity(0.40) : Color.white.opacity(0.07),
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
// MARK: - Goal Details Section
// ============================================================

private struct GoalDetailsSection: View {
    @Binding var title:       String
    @Binding var why:         String
    let areaAccent: Color
    var focusedField: FocusState<AddGoalView.Field?>.Binding

    var body: some View {
        VStack(spacing: LCSpacing.sm) {

            // Title
            GlassCard(glowColor: areaAccent, glowOpacity: focusedField.wrappedValue == .title ? 0.18 : 0.08) {
                VStack(alignment: .leading, spacing: LCSpacing.xs) {
                    Text("GOAL")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)

                    TextField("Run a 5K, learn to cook, ship a project…", text: $title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.lcTextPrimary)
                        .focused(focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit { focusedField.wrappedValue = .why }
                }
                .padding(LCSpacing.md)
            }
            .softAppear(delay: 0.22)
            .animation(.lcCardLift, value: focusedField.wrappedValue == .title)

            // Why (optional)
            GlassCard(glowColor: areaAccent, glowOpacity: focusedField.wrappedValue == .why ? 0.14 : 0.06) {
                VStack(alignment: .leading, spacing: LCSpacing.xs) {
                    Text("WHY THIS MATTERS  (optional)")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)

                    ZStack(alignment: .topLeading) {
                        if why.isEmpty {
                            Text("Because it will make me feel…")
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
                            .focused(focusedField, equals: .why)
                    }
                }
                .padding(LCSpacing.md)
            }
            .softAppear(delay: 0.28)
            .animation(.lcCardLift, value: focusedField.wrappedValue == .why)
        }
    }
}

// ============================================================
// MARK: - First Milestone Section
// ============================================================

private struct FirstMilestoneSection: View {
    @Binding var milestone:  String
    let goalTitle:  String
    let accent:     Color
    var focusedField: FocusState<AddGoalView.Field?>.Binding

    var body: some View {
        GlassCard(glowColor: accent, glowOpacity: focusedField.wrappedValue == .milestone ? 0.16 : 0.07) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("FIRST MILESTONE  (optional)")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)

                let placeholder = goalTitle.isEmpty
                    ? "e.g. Research for 30 minutes"
                    : "First step toward \"\(goalTitle)\""

                TextField(placeholder, text: $milestone)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.lcTextPrimary)
                    .focused(focusedField, equals: .milestone)
                    .submitLabel(.done)

                Text("You can add more milestones after creating the goal.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lcTextTertiary.opacity(0.55))
                    .padding(.top, 2)
            }
            .padding(LCSpacing.md)
        }
        .softAppear(delay: 0.34)
        .animation(.lcCardLift, value: focusedField.wrappedValue == .milestone)
    }
}

// ============================================================
// MARK: - XP Picker Section
// ============================================================

private struct XPPickerSection: View {
    @Binding var xpReward: Double
    let accent: Color

    private let options: [(label: String, xp: Double)] = [
        ("Small",  150),
        ("Medium", 300),
        ("Big",    500),
        ("Epic",   800),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {
            HStack {
                Text("GOAL SIZE")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                Spacer()
                Text("+\(Int(xpReward)) XP")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcGold.opacity(0.85))
            }
            .softAppear(delay: 0.38)

            HStack(spacing: 10) {
                ForEach(options, id: \.xp) { opt in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.lcCardLift) { xpReward = opt.xp }
                    } label: {
                        Text(opt.label)
                            .font(LCFont.insight)
                            .fontWeight(.medium)
                            .foregroundStyle(xpReward == opt.xp ? Color.lcGold : Color.lcTextSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(xpReward == opt.xp ? Color.lcGold.opacity(0.12) : Color.white.opacity(0.04))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                xpReward == opt.xp ? Color.lcGold.opacity(0.40) : Color.white.opacity(0.07),
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .animation(.lcCardLift, value: xpReward)
                }
            }
            .softAppear(delay: 0.42)
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Add Goal") {
    AddGoalView()
        .environmentObject(AppState())
}

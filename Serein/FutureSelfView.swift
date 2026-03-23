// FutureSelfView.swift
// Life Compass — Future Self Screen
//
// The user should feel: "This is who I want to become."
//
// Read mode  — fade-in sections, slow scroll reveal
// Edit mode  — inline TextEditors, save / cancel
//
// Sections
//   Header        — "Your Future Self" + target age
//   Narrative     — large typography, wide line spacing
//   Life areas    — Career · Health · Lifestyle · Identity
//   Core values   — scrollable chips
//   Footer        — "Your daily actions shape this future"

import SwiftUI

// ============================================================
// MARK: - FutureSelfView
// ============================================================

struct FutureSelfView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = FutureSelfViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            LCBackground(showNoise: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: LCSpacing.xxl) {
                    FutureHeader(vm: vm)
                    NarrativeSection(vm: vm)
                    LifeAreasSection(vm: vm)
                    CoreValuesSection(vm: vm)
                    FooterMessage()
                }
                .padding(.horizontal, LCSpacing.md)
                .padding(.top, LCSpacing.xl)
                .padding(.bottom, LCSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)

            // Saved toast
            if vm.showSavedToast {
                SavedToast()
                    .padding(.bottom, LCSpacing.lg)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 10)),
                        removal:   .opacity
                    ))
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            vm.load()
            vm.onVisionSaved = { appState.saveFutureVision($0) }
        }
    }
}

// ============================================================
// MARK: - 1. Header
// ============================================================

private struct FutureHeader: View {
    @ObservedObject var vm: FutureSelfViewModel

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: LCSpacing.xs) {
                Text("YOUR FUTURE SELF")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
                    .softAppear(delay: 0.04)

                Text("Becoming")
                    .font(LCFont.largeTitle)
                    .foregroundStyle(Color.lcTextPrimary)
                    .softAppear(delay: 0.08)

                // Target age
                if vm.isEditMode {
                    HStack(spacing: LCSpacing.sm) {
                        Text("At age")
                            .font(LCFont.body)
                            .foregroundStyle(Color.lcTextSecondary)
                        Stepper(
                            value: $vm.editDraft.targetAge,
                            in: 20...90,
                            step: 1
                        ) {
                            Text("\(vm.editDraft.targetAge)")
                                .font(LCFont.header)
                                .foregroundStyle(Color.lcGold)
                        }
                    }
                    .transition(.opacity)
                } else {
                    HStack(spacing: 6) {
                        Text("At age")
                            .font(LCFont.body)
                            .foregroundStyle(Color.lcTextSecondary)
                        Text("\(vm.vision.targetAge)")
                            .font(LCFont.header)
                            .foregroundStyle(Color.lcGold)
                    }
                    .softAppear(delay: 0.12)
                    .transition(.opacity)
                }
            }

            Spacer()

            // Edit / Save / Cancel
            EditControls(vm: vm)
        }
        .animation(.lcSoftAppear, value: vm.isEditMode)
    }
}

private struct EditControls: View {
    @ObservedObject var vm: FutureSelfViewModel

    var body: some View {
        if vm.isEditMode {
            HStack(spacing: LCSpacing.sm) {
                Button("Cancel") { vm.cancelEdit() }
                    .font(LCFont.insight)
                    .foregroundStyle(Color.lcTextTertiary)
                    .buttonStyle(.plain)

                PrimaryButton(
                    label:    vm.isSaving ? "Saving…" : "Save",
                    gradient: [Color.lcPrimary, Color.lcLavender]
                ) {
                    Task { await vm.save() }
                }
                .disabled(vm.isSaving)
            }
        } else {
            Button {
                vm.enterEditMode()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .medium))
                    Text("Edit")
                        .font(LCFont.insight)
                }
                .foregroundStyle(Color.lcTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)
        }
    }
}

// ============================================================
// MARK: - 2. Narrative Section
// ============================================================

private struct NarrativeSection: View {
    @ObservedObject var vm: FutureSelfViewModel

    var body: some View {
        GlassCard(glowColor: .lcPrimary, glowOpacity: 0.14) {
            VStack(alignment: .leading, spacing: LCSpacing.sm) {
                Text("THE VISION")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)

                if vm.isEditMode {
                    ZStack(alignment: .topLeading) {
                        if vm.editDraft.narrative.isEmpty {
                            Text("Write your vision in the present tense, as if you're already living it...")
                                .font(.system(size: 19, weight: .regular))
                                .foregroundStyle(Color.lcTextTertiary)
                                .allowsHitTesting(false)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $vm.editDraft.narrative)
                            .font(.system(size: 19, weight: .regular))
                            .foregroundStyle(Color.lcTextPrimary)
                            .lineSpacing(8)
                            .frame(minHeight: 160)
                            .fixedSize(horizontal: false, vertical: true)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                    }
                } else {
                    Text(vm.vision.narrative)
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(Color.lcTextPrimary.opacity(0.92))
                        .lineSpacing(9)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(LCSpacing.md)
        }
        .softAppear(delay: 0.16)
        .animation(.lcSoftAppear, value: vm.isEditMode)
    }
}

// ============================================================
// MARK: - 3. Life Areas Section
// ============================================================

private struct LifeAreasSection: View {
    @ObservedObject var vm: FutureSelfViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {
            SectionHeader(
                title:    "Life Areas",
                subtitle: "Who you are in each dimension",
                overline: "YOUR WORLD"
            )
            .softAppear(delay: 0.22)

            ForEach(Array(FutureVisionCategory.allCases.enumerated()), id: \.element) { idx, cat in
                FutureAreaCard(category: cat, vm: vm)
                    .softAppear(delay: 0.26 + Double(idx) * 0.08)
            }
        }
    }
}

private struct FutureAreaCard: View {
    let category: FutureVisionCategory
    @ObservedObject var vm: FutureSelfViewModel

    private var readDescription: String {
        vm.area(for: category)?.description ?? ""
    }

    var body: some View {
        GlassCard(glowColor: category.accent, glowOpacity: 0.11) {
            VStack(alignment: .leading, spacing: LCSpacing.sm) {

                // Category label
                HStack(spacing: 7) {
                    Image(systemName: category.icon)
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(category.accent.opacity(0.85))
                    Text(category.label.uppercased())
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)
                }

                if vm.isEditMode {
                    ZStack(alignment: .topLeading) {
                        if vm.draftArea(for: category).wrappedValue.isEmpty {
                            Text(category.editPlaceholder)
                                .font(LCFont.body)
                                .foregroundStyle(Color.lcTextTertiary)
                                .allowsHitTesting(false)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: vm.draftArea(for: category))
                            .font(LCFont.body)
                            .foregroundStyle(Color.lcTextPrimary)
                            .lineSpacing(5)
                            .frame(minHeight: 80)
                            .fixedSize(horizontal: false, vertical: true)
                            .scrollContentBackground(.hidden)
                            .background(.clear)
                    }
                } else {
                    if readDescription.isEmpty {
                        Text("Tap edit to describe your \(category.label.lowercased()) vision.")
                            .font(LCFont.insight)
                            .italic()
                            .foregroundStyle(Color.lcTextTertiary)
                    } else {
                        Text(readDescription)
                            .font(LCFont.body)
                            .foregroundStyle(Color.lcTextSecondary)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(LCSpacing.md)
        }
        .animation(.lcSoftAppear, value: vm.isEditMode)
    }
}

// ============================================================
// MARK: - 4. Core Values Section
// ============================================================

private struct CoreValuesSection: View {
    @ObservedObject var vm: FutureSelfViewModel
    @State private var valuesEditText: String = ""

    var body: some View {
        GlassCard(glowColor: .lcBeige, glowOpacity: 0.10) {
            VStack(alignment: .leading, spacing: LCSpacing.md) {
                Text("CORE VALUES")
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)

                if vm.isEditMode {
                    VStack(alignment: .leading, spacing: LCSpacing.xs) {
                        Text("Separate with commas")
                            .font(LCFont.insight)
                            .foregroundStyle(Color.lcTextTertiary)

                        TextField(
                            "Integrity, Growth, Presence…",
                            text: $valuesEditText
                        )
                        .font(LCFont.body)
                        .foregroundStyle(Color.lcTextPrimary)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                        .onChange(of: valuesEditText) { _, text in
                            vm.editDraft.coreValues = vm.parseValues(from: text)
                        }
                    }
                    .onAppear {
                        valuesEditText = vm.editDraft.coreValues.joined(separator: ", ")
                    }
                } else {
                    if vm.vision.coreValues.isEmpty {
                        Text("Tap edit to add your core values.")
                            .font(LCFont.insight)
                            .italic()
                            .foregroundStyle(Color.lcTextTertiary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(vm.vision.coreValues, id: \.self) { value in
                                    ValueChip(text: value)
                                }
                            }
                        }
                    }
                }
            }
            .padding(LCSpacing.md)
        }
        .softAppear(delay: 0.60)
        .animation(.lcSoftAppear, value: vm.isEditMode)
    }
}

private struct ValueChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(LCFont.insight)
            .fontWeight(.medium)
            .foregroundStyle(Color.lcBeige.opacity(0.85))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.lcBeige.opacity(0.10))
                    .overlay(Capsule().strokeBorder(Color.lcBeige.opacity(0.20), lineWidth: 0.5))
            )
    }
}

// ============================================================
// MARK: - Footer Message
// ============================================================

private struct FooterMessage: View {
    var body: some View {
        GlassCard(glowColor: .lcPrimary, glowOpacity: 0.08) {
            HStack(spacing: LCSpacing.sm) {
                Image(systemName: "arrow.up.forward.circle")
                    .font(.system(size: 18, weight: .ultraLight))
                    .foregroundStyle(Color.lcPrimary.opacity(0.70))

                Text("Your daily actions shape this future.")
                    .font(LCFont.body)
                    .italic()
                    .foregroundStyle(Color.lcTextSecondary)
                    .lineSpacing(3)
            }
            .padding(LCSpacing.md)
        }
        .softAppear(delay: 0.72)
    }
}

// ============================================================
// MARK: - Saved Toast
// ============================================================

private struct SavedToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.lcGold)
            Text("Vision saved")
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
                .shadow(color: Color.lcGold.opacity(0.25), radius: 14, y: 4)
                .shadow(color: .black.opacity(0.30), radius: 8, y: 2)
        )
    }
}

// ============================================================
// MARK: - Previews
// ============================================================

#Preview("Future Self — Read Mode") {
    FutureSelfView()
        .environmentObject(AppState())
}

#Preview("Future Self — Edit Mode") {
    let vm = FutureSelfViewModel()
    vm.load()
    vm.enterEditMode()
    return ZStack {
        LCBackground(showNoise: true)
        FutureSelfView()
    }
    .environmentObject(AppState())
}

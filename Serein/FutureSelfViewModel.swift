// FutureSelfViewModel.swift
// Life Compass — Future Self ViewModel

import SwiftUI
import Combine

// ============================================================
// MARK: - FutureSelfViewModel
// ============================================================

@MainActor
final class FutureSelfViewModel: ObservableObject {

    // ── Published ─────────────────────────────────────────────
    @Published var vision:         FutureVision = .placeholder
    @Published var isEditMode:     Bool         = false
    @Published var isSaving:       Bool         = false
    @Published var showSavedToast: Bool         = false

    // Edit-mode working copy — only committed on save
    @Published var editDraft: FutureVision = .placeholder

    /// Called after a successful save — caller persists to AppState.
    var onVisionSaved: (FutureVision) -> Void = { _ in }

    // ── Computed ──────────────────────────────────────────────

    func parseValues(from text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // ── Load ──────────────────────────────────────────────────

    func load() {
        vision    = FutureVision.load()
        editDraft = vision
    }

    // ── Edit flow ─────────────────────────────────────────────

    func enterEditMode() {
        editDraft = vision
        withAnimation(.lcSoftAppear) { isEditMode = true }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func cancelEdit() {
        editDraft = vision
        withAnimation(.lcSoftAppear) { isEditMode = false }
    }

    // ── Save ──────────────────────────────────────────────────

    func save() async {
        guard !isSaving else { return }
        isSaving = true

        editDraft.normalizeAreas()

        try? await Task.sleep(for: .milliseconds(600))

        // Persist locally
        editDraft.save()

        // Propagate to AppState
        onVisionSaved(editDraft)

        withAnimation(.lcSoftAppear) {
            vision     = editDraft
            isEditMode = false
            isSaving   = false
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.lcSoftAppear) { showSavedToast = true }
        try? await Task.sleep(for: .seconds(2.0))
        withAnimation(.easeOut(duration: 0.4)) { showSavedToast = false }
    }

    // ── Area helpers ──────────────────────────────────────────

    func area(for category: FutureVisionCategory) -> FutureVisionArea? {
        vision.areas.first { $0.category == category }
    }

    func draftArea(for category: FutureVisionCategory) -> Binding<String> {
        Binding(
            get: {
                self.editDraft.areas.first { $0.category == category }?.description ?? ""
            },
            set: { newValue in
                if let idx = self.editDraft.areas.firstIndex(where: { $0.category == category }) {
                    self.editDraft.areas[idx].description = newValue
                }
            }
        )
    }
}

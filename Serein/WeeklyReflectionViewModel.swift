// WeeklyReflectionViewModel.swift
// Life Compass — Weekly Reflection ViewModel

import SwiftUI
import Combine
import UserNotifications

// ============================================================
// MARK: - WeeklyReflectionViewModel
// ============================================================

@MainActor
final class WeeklyReflectionViewModel: ObservableObject {

    // ── Published state ───────────────────────────────────────
    @Published var reflection:  WeeklyReflection = WeeklyReflection()
    @Published var phase:       Phase            = .writing
    @Published var streak:      Int              = 0

    /// Called after a successful save — caller persists to AppState.
    var onReflectionSaved: (WeeklyReflection) -> Void = { _ in }

    enum Phase: Equatable {
        case writing
        case saving
        case saved(streakMessage: String?)
        case skipped
    }

    // ── Computed ──────────────────────────────────────────────

    var canSubmit:  Bool { reflection.hasMeaningfulContent }
    var filledCount: Int { reflection.filledCount }

    var streakMessage: String? {
        switch streak {
        case 2:    return "You've reflected 2 weeks in a row."
        case 3:    return "You've reflected 3 weeks in a row. Momentum is building."
        case 5:    return "5 weeks of reflection — real self-awareness takes root."
        case 10:   return "10 weeks. You've made reflection a habit."
        default:
            if streak >= 4 { return "You've reflected \(streak) weeks in a row." }
            return nil
        }
    }

    // ── Init ──────────────────────────────────────────────────

    init() {
        let all = WeeklyReflection.loadAll()
        streak  = WeeklyReflection.currentStreak(from: all)
    }

    // ── Mutations ─────────────────────────────────────────────

    func updateAnswer(_ text: String, at index: Int) {
        guard reflection.answers.indices.contains(index) else { return }
        reflection.answers[index] = text
    }

    func toggleMoodTag(_ tag: MoodTag) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.lcCardLift) {
            if reflection.moodTags.contains(tag) {
                reflection.moodTags.removeAll { $0 == tag }
            } else {
                reflection.moodTags.append(tag)
            }
        }
    }

    // ── Submit ────────────────────────────────────────────────

    func submitReflection() async {
        guard canSubmit else { return }

        phase = .saving
        try? await Task.sleep(for: .milliseconds(800))

        // Propagate to AppState — AppState owns persistence
        onReflectionSaved(reflection)

        // Update streak from freshly persisted state
        let all = WeeklyReflection.loadAll()
        streak = WeeklyReflection.currentStreak(from: all)

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.lcSoftAppear) {
            phase = .saved(streakMessage: streakMessage)
        }
    }

    // ── Skip ──────────────────────────────────────────────────

    func skipReflection() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.lcSoftAppear) { phase = .skipped }
    }

    func resetToWriting() {
        reflection = WeeklyReflection()
        phase      = .writing
    }

}

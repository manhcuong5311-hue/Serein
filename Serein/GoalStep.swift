// GoalStep.swift
// Life Compass — Goal Step Model
//
// GoalStep is the daily execution layer that sits below Milestones.
// Milestones = macro checkpoints (what you're building toward).
// GoalSteps  = daily actions   (what you do right now).
//
// TodayStepItem bundles a step with its parent goal + life area
// so the Dashboard can render everything it needs from one value.

import Foundation

// ============================================================
// MARK: - StepType
// ============================================================

enum StepType: String, Codable, CaseIterable {
    case today
    case tomorrow
    case scheduled
    case anytime
    case recurringDaily

    var displayName: String {
        switch self {
        case .today:          return "Today"
        case .tomorrow:       return "Tomorrow"
        case .scheduled:      return "Scheduled"
        case .anytime:        return "Anytime"
        case .recurringDaily: return "Daily"
        }
    }

    /// Lower = higher priority in today list sort.
    var sortPriority: Int {
        switch self {
        case .today:          return 0
        case .scheduled:      return 1
        case .recurringDaily: return 2
        case .anytime:        return 3
        case .tomorrow:       return 4
        }
    }

    var icon: String {
        switch self {
        case .today:          return "sun.max"
        case .tomorrow:       return "moon"
        case .scheduled:      return "calendar"
        case .anytime:        return "infinity"
        case .recurringDaily: return "arrow.clockwise"
        }
    }

    var shortLabel: String {
        switch self {
        case .today:          return "Today"
        case .tomorrow:       return "Tomorrow"
        case .scheduled:      return "Scheduled"
        case .anytime:        return "Backlog"
        case .recurringDaily: return "Daily"
        }
    }
}

// ============================================================
// MARK: - GoalStep
// ============================================================

struct GoalStep: Identifiable, Codable, Hashable {
    let id:            UUID
    let goalId:        UUID
    var title:         String
    var type:          StepType
    var scheduledDate: Date?
    var isCompleted:   Bool
    var completedAt:   Date?
    let createdAt:     Date

    init(
        id:            UUID      = UUID(),
        goalId:        UUID,
        title:         String,
        type:          StepType  = .today,
        scheduledDate: Date?     = nil,
        isCompleted:   Bool      = false,
        completedAt:   Date?     = nil,
        createdAt:     Date      = Date()
    ) {
        self.id            = id
        self.goalId        = goalId
        self.title         = title
        self.type          = type
        self.scheduledDate = scheduledDate
        self.isCompleted   = isCompleted
        self.completedAt   = completedAt
        self.createdAt     = createdAt
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: GoalStep, rhs: GoalStep) -> Bool { lhs.id == rhs.id }
}

// ============================================================
// MARK: - Array<GoalStep> Helpers
// ============================================================

extension Array where Element == GoalStep {

    /// Steps that should appear in "Today": type=today, scheduled steps due today,
    /// and recurring daily steps — all incomplete, sorted by priority then creation time.
    func forToday() -> [GoalStep] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        return filter { step in
            guard !step.isCompleted else { return false }
            switch step.type {
            case .today:
                return true
            case .scheduled:
                guard let date = step.scheduledDate else { return false }
                return cal.isDate(cal.startOfDay(for: date), inSameDayAs: today)
            case .recurringDaily:
                return true
            case .tomorrow, .anytime:
                return false
            }
        }
        .sorted {
            if $0.type.sortPriority != $1.type.sortPriority {
                return $0.type.sortPriority < $1.type.sortPriority
            }
            return $0.createdAt < $1.createdAt
        }
    }

    /// Steps in the UPCOMING section: tomorrow steps + scheduled future steps.
    func upcoming() -> [GoalStep] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())

        return filter { step in
            guard !step.isCompleted else { return false }
            switch step.type {
            case .tomorrow:
                return true
            case .scheduled:
                guard let date = step.scheduledDate else { return false }
                return cal.startOfDay(for: date) > today
            default:
                return false
            }
        }
        .sorted { a, b in
            let da = a.scheduledDate ?? Date.distantFuture
            let db = b.scheduledDate ?? Date.distantFuture
            return da < db
        }
    }

    /// Steps in the BACKLOG section: anytime steps only.
    func backlog() -> [GoalStep] {
        filter { $0.type == .anytime && !$0.isCompleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    /// All completed steps, most-recently-completed first.
    func done() -> [GoalStep] {
        filter(\.isCompleted)
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }
}

// ============================================================
// MARK: - TodayStepItem
// ============================================================
// Bundles step + parent goal + life area for Dashboard rendering.
// The id matches step.id so ForEach is stable.

struct TodayStepItem: Identifiable {
    let id:   UUID     // == step.id
    let goal: Goal
    let area: LifeArea
    let step: GoalStep
}

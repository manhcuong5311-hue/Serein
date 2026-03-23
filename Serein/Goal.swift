// Goal.swift
// Life Compass — Goal + Milestone Models
//
// Design philosophy: goals are life-direction anchors, not tasks.
// Each goal has a "why", a set of milestones, and a next step
// so the user always knows where they stand and what comes next.

import Foundation

// ============================================================
// MARK: - Milestone
// ============================================================

struct Milestone: Identifiable, Hashable, Codable {
    let id:          UUID
    var title:       String
    var isCompleted: Bool
    var completedAt: Date?

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false, completedAt: Date? = nil) {
        self.id          = id
        self.title       = title
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}

// ============================================================
// MARK: - Goal
// ============================================================

struct Goal: Identifiable, Hashable, Codable {
    let id:         UUID
    var title:      String
    let lifeAreaId: UUID

    var why:         String?        // "Why this matters" — optional user reflection
    var milestones:  [Milestone]
    var xpReward:    Double

    var isFocusGoal: Bool = false
    var isArchived:  Bool = false

    // ── Pinning & daily steps (safe defaults for backward compat) ──
    var isPinned:    Bool       = false
    var orderIndex:  Int        = 0
    var steps:       [GoalStep] = []

    // MARK: Computed

    var completedMilestones: Int { milestones.filter(\.isCompleted).count }
    var totalMilestones:     Int { milestones.count }

    var progress: Double {
        totalMilestones > 0
            ? min(Double(completedMilestones) / Double(totalMilestones), 1.0)
            : 0
    }

    var isComplete: Bool {
        totalMilestones > 0 && completedMilestones >= totalMilestones
    }

    /// First incomplete milestone — what comes next.
    var nextMilestone: Milestone? {
        milestones.first { !$0.isCompleted }
    }

    var milestoneLabel: String {
        guard totalMilestones > 0 else { return "No milestones yet" }
        let s = totalMilestones == 1 ? "milestone" : "milestones"
        return "\(completedMilestones) of \(totalMilestones) \(s)"
    }

    // Hashable: identity only
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Goal, rhs: Goal) -> Bool { lhs.id == rhs.id }
}

// ============================================================
// MARK: - Persistence
// ============================================================

extension Goal {
    static let storageKey = "lc.goals"

    static func loadPersisted() -> [Goal]? {
        guard let data    = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Goal].self, from: data)
        else { return nil }
        return decoded
    }
}

// ============================================================
// MARK: - Navigation Item
// ============================================================
// Bundles a Goal + its LifeArea for type-safe NavigationStack routing.

struct GoalNavItem: Hashable {
    var goal: Goal
    let area: LifeArea
}

extension LifeArea: Hashable {
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: LifeArea, rhs: LifeArea) -> Bool { lhs.id == rhs.id }
}

// ============================================================
// MARK: - Sample Data
// ============================================================

extension Goal {
    static let samples: [Goal] = [

        // ── Health ─────────────────────────────────────────────
        Goal(
            id: UUID(),
            title: "Run a 5K without stopping",
            lifeAreaId: LifeAreaID.health,
            why: "Physical strength gives me clarity and confidence in everything I do.",
            milestones: [
                Milestone(title: "Run 1K without stopping",      isCompleted: true),
                Milestone(title: "Run 2K without stopping",      isCompleted: true),
                Milestone(title: "Build a training schedule",    isCompleted: false),
                Milestone(title: "Run 5K with a running buddy",  isCompleted: false),
                Milestone(title: "Complete my first 5K run",     isCompleted: false),
            ],
            xpReward: 450
        ),
        Goal(
            id: UUID(),
            title: "Build a morning movement routine",
            lifeAreaId: LifeAreaID.health,
            why: "How I start the morning shapes the entire day.",
            milestones: [
                Milestone(title: "Wake up at 7 am for 7 days",  isCompleted: true),
                Milestone(title: "Try 3 different routines",     isCompleted: false),
                Milestone(title: "Lock in a 20-min routine",     isCompleted: false),
            ],
            xpReward: 350,
            isFocusGoal: true
        ),

        // ── Career ─────────────────────────────────────────────
        Goal(
            id: UUID(),
            title: "Ship a side project from scratch",
            lifeAreaId: LifeAreaID.career,
            why: "Building something real is how I grow beyond my comfort zone.",
            milestones: [
                Milestone(title: "Define the core idea",         isCompleted: true),
                Milestone(title: "Build the MVP in a weekend",   isCompleted: true),
                Milestone(title: "Build landing page",           isCompleted: false),
                Milestone(title: "Share with 10 real users",     isCompleted: false),
                Milestone(title: "Get first piece of feedback",  isCompleted: false),
                Milestone(title: "Iterate and re-ship",          isCompleted: false),
            ],
            xpReward: 800
        ),
        Goal(
            id: UUID(),
            title: "Have a meaningful mentorship conversation",
            lifeAreaId: LifeAreaID.career,
            why: "One conversation with the right person can change everything.",
            milestones: [
                Milestone(title: "List 3 people I admire",       isCompleted: true),
                Milestone(title: "Reach out with a real ask",    isCompleted: false),
            ],
            xpReward: 300
        ),

        // ── Relationships ──────────────────────────────────────
        Goal(
            id: UUID(),
            title: "Plan a meaningful trip with family",
            lifeAreaId: LifeAreaID.relationships,
            why: "Shared experiences build bonds that last a lifetime.",
            milestones: [
                Milestone(title: "Choose a destination together", isCompleted: true),
                Milestone(title: "Book accommodation",            isCompleted: true),
                Milestone(title: "Plan 2 shared activities",      isCompleted: false),
                Milestone(title: "Take the trip",                 isCompleted: false),
            ],
            xpReward: 500
        ),

        // ── Mindfulness ────────────────────────────────────────
        Goal(
            id: UUID(),
            title: "Complete a 30-day meditation streak",
            lifeAreaId: LifeAreaID.mindfulness,
            why: "Stillness is the foundation everything else is built on.",
            milestones: [
                Milestone(title: "Meditate for 7 days straight",  isCompleted: true),
                Milestone(title: "Reach day 14",                  isCompleted: false),
                Milestone(title: "Complete day 30",               isCompleted: false),
            ],
            xpReward: 400
        ),

        // ── Finances ──────────────────────────────────────────
        Goal(
            id: UUID(),
            title: "Build a 3-month emergency fund",
            lifeAreaId: LifeAreaID.finances,
            why: "Financial security lets me take risks in the areas that matter most.",
            milestones: [
                Milestone(title: "Calculate exact target amount",  isCompleted: true),
                Milestone(title: "Save month 1 of 3",              isCompleted: true),
                Milestone(title: "Save month 2 of 3",              isCompleted: false),
                Milestone(title: "Save month 3 of 3",              isCompleted: false),
            ],
            xpReward: 700
        ),
    ]
}

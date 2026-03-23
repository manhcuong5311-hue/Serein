// MockGoalProvider.swift
// Life Compass — Mock Goal Factory
//
// Provides example (isMock = true) goals shown to new users when a
// life area has no real goals yet. Mock goals are:
//   • Never persisted to disk
//   • Auto-dismissed the moment the user creates a real goal in the area
//   • Shown at reduced opacity with an "Example" badge in the UI
//
// Add mock goal definitions here for any life area.
// Currently only Health ships with example data (per product spec).

import Foundation

enum MockGoalProvider {

    // Returns example goals for `areaId`, or [] if no mock exists.
    static func goals(for areaId: UUID) -> [Goal] {
        if areaId == LifeAreaID.health  { return [healthGoal] }
        return []
    }

    // ── Health ───────────────────────────────────────────────────
    // Stable fixed ID so SwiftUI ForEach never generates identity conflicts.
    private static let healthGoalId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private static var healthGoal: Goal {
        let goal = Goal(
            id:         healthGoalId,
            title:      "Get Fit",
            lifeAreaId: LifeAreaID.health,
            why:        "Consistent movement gives me energy and confidence all day.",
            milestones: [
                Milestone(title: "Work out 3× this week"),
                Milestone(title: "Replace one meal with something wholesome"),
                Milestone(title: "Sleep 7+ hours for 5 nights"),
            ],
            xpReward:   300,
            steps: [
                GoalStep(
                    goalId:  healthGoalId,
                    title:   "Workout 30 min",
                    type:    .today
                ),
                GoalStep(
                    goalId:  healthGoalId,
                    title:   "Run 2 km",
                    type:    .tomorrow
                ),
            ],
            isMock: true
        )
        return goal
    }
}

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

import Foundation

enum MockGoalProvider {

    // Returns example goals for `areaId`, or [] if no mock exists.
    static func goals(for areaId: UUID) -> [Goal] {
        switch areaId {
        case LifeAreaID.health:        return [healthGoal]
        case LifeAreaID.career:        return [careerGoal]
        case LifeAreaID.relationships: return [relationshipsGoal]
        case LifeAreaID.mindfulness:   return [mindfulnessGoal]
        case LifeAreaID.creativity:    return [creativityGoal]
        case LifeAreaID.finances:      return [financesGoal]
        default:                       return []
        }
    }

    // ── Health ───────────────────────────────────────────────────
    private static let healthGoalId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    private static var healthGoal: Goal {
        Goal(
            id:         healthGoalId,
            title:      "Get Fit",
            lifeAreaId: LifeAreaID.health,
            why:        "Consistent movement gives me energy and confidence all day.",
            milestones: [
                Milestone(title: "Work out 3× this week"),
                Milestone(title: "Replace one meal with something wholesome"),
                Milestone(title: "Sleep 7+ hours for 5 nights"),
            ],
            xpReward: 300,
            steps: [
                GoalStep(goalId: healthGoalId, title: "Workout 30 min",  type: .today),
                GoalStep(goalId: healthGoalId, title: "Run 2 km",        type: .tomorrow),
            ],
            isMock: true
        )
    }

    // ── Career ───────────────────────────────────────────────────
    private static let careerGoalId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    private static var careerGoal: Goal {
        Goal(
            id:         careerGoalId,
            title:      "Ship a side project from scratch",
            lifeAreaId: LifeAreaID.career,
            why:        "Building something real is how I grow beyond my comfort zone.",
            milestones: [
                Milestone(title: "Define the core idea"),
                Milestone(title: "Build the MVP in a weekend"),
                Milestone(title: "Share with 10 real users"),
            ],
            xpReward: 800,
            steps: [
                GoalStep(goalId: careerGoalId, title: "Write down the core idea", type: .today),
                GoalStep(goalId: careerGoalId, title: "Sketch the MVP scope",     type: .tomorrow),
            ],
            isMock: true
        )
    }

    // ── Relationships ────────────────────────────────────────────
    private static let relationshipsGoalId = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    private static var relationshipsGoal: Goal {
        Goal(
            id:         relationshipsGoalId,
            title:      "Plan a meaningful trip with family",
            lifeAreaId: LifeAreaID.relationships,
            why:        "Shared experiences build bonds that last a lifetime.",
            milestones: [
                Milestone(title: "Choose a destination together"),
                Milestone(title: "Book accommodation"),
                Milestone(title: "Plan 2 shared activities"),
            ],
            xpReward: 500,
            steps: [
                GoalStep(goalId: relationshipsGoalId, title: "Research destinations", type: .today),
                GoalStep(goalId: relationshipsGoalId, title: "Ask family for input",  type: .tomorrow),
            ],
            isMock: true
        )
    }

    // ── Mindfulness ──────────────────────────────────────────────
    private static let mindfulnessGoalId = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!

    private static var mindfulnessGoal: Goal {
        Goal(
            id:         mindfulnessGoalId,
            title:      "Complete a 30-day meditation streak",
            lifeAreaId: LifeAreaID.mindfulness,
            why:        "Stillness is the foundation everything else is built on.",
            milestones: [
                Milestone(title: "Meditate for 7 days straight"),
                Milestone(title: "Reach day 14"),
                Milestone(title: "Complete day 30"),
            ],
            xpReward: 400,
            steps: [
                GoalStep(goalId: mindfulnessGoalId, title: "Meditate 10 min",        type: .today),
                GoalStep(goalId: mindfulnessGoalId, title: "Set a morning reminder", type: .tomorrow),
            ],
            isMock: true
        )
    }

    // ── Creativity ───────────────────────────────────────────────
    private static let creativityGoalId = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!

    private static var creativityGoal: Goal {
        Goal(
            id:         creativityGoalId,
            title:      "Start a creative side project",
            lifeAreaId: LifeAreaID.creativity,
            why:        "Creativity keeps me alive, curious, and fully myself.",
            milestones: [
                Milestone(title: "Choose a medium or format"),
                Milestone(title: "Create a first rough piece"),
                Milestone(title: "Share it with one person"),
            ],
            xpReward: 350,
            steps: [
                GoalStep(goalId: creativityGoalId, title: "Sketch out ideas",         type: .today),
                GoalStep(goalId: creativityGoalId, title: "Pick one idea to pursue",  type: .tomorrow),
            ],
            isMock: true
        )
    }

    // ── Finances ─────────────────────────────────────────────────
    private static let financesGoalId = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!

    private static var financesGoal: Goal {
        Goal(
            id:         financesGoalId,
            title:      "Build a 3-month emergency fund",
            lifeAreaId: LifeAreaID.finances,
            why:        "Financial security lets me take risks in the areas that matter most.",
            milestones: [
                Milestone(title: "Calculate exact target amount"),
                Milestone(title: "Save month 1 of 3"),
                Milestone(title: "Save month 2 of 3"),
                Milestone(title: "Save month 3 of 3"),
            ],
            xpReward: 700,
            steps: [
                GoalStep(goalId: financesGoalId, title: "Review monthly expenses", type: .today),
                GoalStep(goalId: financesGoalId, title: "Set up a savings rule",   type: .tomorrow),
            ],
            isMock: true
        )
    }
}

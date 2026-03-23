// DailyActivity.swift
// Life Compass — Daily Activity Model
//
// Tracks what the user did each day.
// Powers the streak engine and the retention loop.

import Foundation

// ============================================================
// MARK: - DailyActivity
// ============================================================

struct DailyActivity: Identifiable, Codable {
    let id:   UUID
    let date: Date
    var completedMilestoneCount: Int
    var completedStepCount:      Int    // GoalStep completions (safe default = 0)
    var xpEarned: Double

    init(
        id:   UUID   = UUID(),
        date: Date,
        completedMilestoneCount: Int    = 0,
        completedStepCount:      Int    = 0,
        xpEarned:               Double = 0
    ) {
        self.id                      = id
        self.date                    = date
        self.completedMilestoneCount = completedMilestoneCount
        self.completedStepCount      = completedStepCount
        self.xpEarned                = xpEarned
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}

// ============================================================
// MARK: - Persistence
// ============================================================

extension DailyActivity {
    static let storageKey = "lc.dailyActivities"

    static func loadAll() -> [DailyActivity] {
        guard let data    = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([DailyActivity].self, from: data)
        else { return [] }
        return decoded
    }

    static func save(_ activities: [DailyActivity]) {
        guard let encoded = try? JSONEncoder().encode(activities) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }
}

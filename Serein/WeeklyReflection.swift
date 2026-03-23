// WeeklyReflection.swift
// Life Compass — Weekly Reflection Models
//
// Philosophy: Slowing down is a form of progress.

import SwiftUI

// ============================================================
// MARK: - Reflection Question
// ============================================================

struct ReflectionQuestion: Identifiable {
    let id:          Int
    let text:        String
    let placeholder: String   // gentle writing prompt
    let icon:        String   // SF Symbol

    static let all: [ReflectionQuestion] = [
        ReflectionQuestion(
            id: 1,
            text: "Did your actions move you closer to your future self?",
            placeholder: "Reflect honestly... what did you do this week that aligned with who you're becoming?",
            icon: "arrow.up.forward"
        ),
        ReflectionQuestion(
            id: 2,
            text: "Which part of your life improved the most?",
            placeholder: "Even small wins count. What area showed growth this week?",
            icon: "chart.line.uptrend.xyaxis"
        ),
        ReflectionQuestion(
            id: 3,
            text: "What felt meaningful this week?",
            placeholder: "A conversation, a moment, a decision... what truly stays with you?",
            icon: "heart.text.square"
        ),
    ]
}

// ============================================================
// MARK: - Mood Tag
// ============================================================

enum MoodTag: String, CaseIterable, Codable, Hashable {
    case productive, balanced, stressed, inspired

    var label: String {
        switch self {
        case .productive: return "Productive"
        case .balanced:   return "Balanced"
        case .stressed:   return "Stressed"
        case .inspired:   return "Inspired"
        }
    }

    var icon: String {
        switch self {
        case .productive: return "bolt.fill"
        case .balanced:   return "scale.3d"
        case .stressed:   return "wind"
        case .inspired:   return "sparkles"
        }
    }

    var accent: Color {
        switch self {
        case .productive: return .lcGold
        case .balanced:   return .lcPrimary
        case .stressed:   return Color(lcHex: "#C4856A")
        case .inspired:   return .lcLavender
        }
    }
}

// ============================================================
// MARK: - Weekly Reflection
// ============================================================

struct WeeklyReflection: Identifiable, Codable {
    let id:            UUID
    let weekStartDate: Date
    var answers:       [String]     // indexed: 0, 1, 2 → questions 1, 2, 3
    var moodTags:      [MoodTag]
    var xpEarned:      Double

    init(weekStartDate: Date = .currentWeekStart) {
        self.id            = UUID()
        self.weekStartDate = weekStartDate
        self.answers       = ["", "", ""]
        self.moodTags      = []
        self.xpEarned      = 50
    }

    var hasMeaningfulContent: Bool {
        answers.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).count > 5 }
    }

    var filledCount: Int {
        answers.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }
}

// ============================================================
// MARK: - Persistence (UserDefaults)
// ============================================================

extension WeeklyReflection {
    private static let storageKey = "lc.reflections"

    static func loadAll() -> [WeeklyReflection] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WeeklyReflection].self, from: data)
        else { return [] }
        return decoded
    }

    static func save(_ reflections: [WeeklyReflection]) {
        guard let encoded = try? JSONEncoder().encode(reflections) else { return }
        UserDefaults.standard.set(encoded, forKey: storageKey)
    }

    /// Streak = consecutive weeks with saved reflections ending today.
    static func currentStreak(from reflections: [WeeklyReflection]) -> Int {
        let cal   = Calendar.current
        var count = 0
        var check = Date.currentWeekStart
        let sorted = reflections.sorted { $0.weekStartDate > $1.weekStartDate }

        for _ in 0..<52 {
            if sorted.contains(where: { cal.isDate($0.weekStartDate, inSameDayAs: check) }) {
                count += 1
                check = cal.date(byAdding: .weekOfYear, value: -1, to: check) ?? check
            } else {
                break
            }
        }
        return count
    }
}

// ============================================================
// MARK: - Date helper
// ============================================================

private extension Date {
    static var currentWeekStart: Date {
        Calendar.current.startOfWeek(for: Date())
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? date
    }
}

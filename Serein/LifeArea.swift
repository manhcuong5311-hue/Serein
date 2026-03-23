// LifeArea.swift
// Life Compass — Domain Models
//
// LifeArea · DailyInsight · FutureSelf
// All value types, Identifiable, preview-ready sample data.

import SwiftUI

// ============================================================
// MARK: - LifeArea
// ============================================================

struct LifeArea: Identifiable {
    let id:       UUID
    let title:    String
    let icon:     String      // SF Symbol name
    let accent:   Color       // area colour token

    var level:     Int
    var currentXP: Double
    var maxXP:     Double

    // MARK: Computed
    var progress:   Double { maxXP > 0 ? min(currentXP / maxXP, 1.0) : 0 }
    var levelTitle: String { "Lv. \(level)" }
    var xpLabel:    String { "\(Int(currentXP)) / \(Int(maxXP)) XP" }

    /// Gradient pair for rings / bars (accent → slightly lighter)
    var gradient: [Color] { [accent.opacity(0.7), accent] }
}

// ============================================================
// MARK: - Stable Area IDs
// ============================================================
// Fixed UUIDs allow cross-model references (e.g. Goal → LifeArea)
// to survive multiple static initialiser calls.

enum LifeAreaID {
    static let health        = UUID(uuidString: "A0000001-0000-0000-0000-000000000001")!
    static let career        = UUID(uuidString: "A0000001-0000-0000-0000-000000000002")!
    static let relationships = UUID(uuidString: "A0000001-0000-0000-0000-000000000003")!
    static let mindfulness   = UUID(uuidString: "A0000001-0000-0000-0000-000000000004")!
    static let creativity    = UUID(uuidString: "A0000001-0000-0000-0000-000000000005")!
    static let finances      = UUID(uuidString: "A0000001-0000-0000-0000-000000000006")!
}

// ============================================================
// MARK: - Progress Persistence
// ============================================================
// LifeArea contains Color (not Codable), so we persist only
// the mutable progress fields keyed by stable UUID.

struct LifeAreaProgressData: Codable {
    let id:        UUID
    var level:     Int
    var currentXP: Double
    var maxXP:     Double
}

extension LifeArea {
    private static let progressKey = "lc.lifeAreaProgress"

    static func loadProgress() -> [UUID: LifeAreaProgressData] {
        guard let data    = UserDefaults.standard.data(forKey: progressKey),
              let decoded = try? JSONDecoder().decode([LifeAreaProgressData].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    static func saveProgress(_ areas: [LifeArea]) {
        let payload = areas.map {
            LifeAreaProgressData(id: $0.id, level: $0.level,
                                 currentXP: $0.currentXP, maxXP: $0.maxXP)
        }
        guard let encoded = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(encoded, forKey: progressKey)
    }

    static func clearProgress() {
        UserDefaults.standard.removeObject(forKey: progressKey)
    }
}

// ============================================================
// MARK: - Sample Data
// ============================================================

extension LifeArea {
    static let samples: [LifeArea] = [
        LifeArea(
            id: LifeAreaID.health, title: "Health",
            icon: "heart.fill",
            accent: .lcGold,
            level: 14, currentXP: 3_200, maxXP: 5_000
        ),
        LifeArea(
            id: LifeAreaID.career, title: "Career",
            icon: "briefcase.fill",
            accent: .lcPrimary,
            level: 9, currentXP: 1_800, maxXP: 4_000
        ),
        LifeArea(
            id: LifeAreaID.relationships, title: "Relationships",
            icon: "person.2.fill",
            accent: .lcLavender,
            level: 11, currentXP: 2_600, maxXP: 4_500
        ),
        LifeArea(
            id: LifeAreaID.mindfulness, title: "Mindfulness",
            icon: "leaf.fill",
            accent: Color(lcHex: "#7DB6A0"),
            level: 7, currentXP: 900, maxXP: 3_000
        ),
        LifeArea(
            id: LifeAreaID.creativity, title: "Creativity",
            icon: "paintbrush.fill",
            accent: .lcBeige,
            level: 5, currentXP: 400, maxXP: 2_500
        ),
        LifeArea(
            id: LifeAreaID.finances, title: "Finances",
            icon: "chart.line.uptrend.xyaxis",
            accent: Color(lcHex: "#C4856A"),
            level: 6, currentXP: 1_100, maxXP: 3_000
        ),
    ]
}

// ============================================================
// MARK: - DailyInsight
// ============================================================

struct DailyInsight {
    let text:     String
    let category: Category
    let source:   String?

    enum Category { case momentum, focus, clarity, growth, resilience, mindset }

    // Returns a different insight each calendar day, cycling through the full pool.
    static var today: DailyInsight {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return pool[dayOfYear % pool.count]
    }

    // ── Legacy placeholder alias ───────────────────────────────
    static var placeholder: DailyInsight { today }

    // ── 42-insight rotating pool ──────────────────────────────
    // Each insight is tied to a real life-execution context: morning
    // energy, goal inertia, habit building, reflection, focus, identity.
    static let pool: [DailyInsight] = [

        // MOMENTUM
        .init(text: "The goal isn't motivation — it's motion. Start before you feel ready.",
              category: .momentum, source: nil),
        .init(text: "Consistency is the only superpower available to everyone.",
              category: .momentum, source: nil),
        .init(text: "One small action today compounds silently into the life you want tomorrow.",
              category: .momentum, source: nil),
        .init(text: "You don't need a perfect plan. You need a next step — take it.",
              category: .momentum, source: nil),
        .init(text: "Momentum is built in the micro. Every tiny win counts.",
              category: .momentum, source: nil),
        .init(text: "The hardest part of any day is starting. Once you move, keep moving.",
              category: .momentum, source: nil),
        .init(text: "Action dissolves anxiety. The thing you've been avoiding — start there.",
              category: .momentum, source: nil),

        // FOCUS
        .init(text: "What you give your attention to grows. Choose what you water today.",
              category: .focus, source: nil),
        .init(text: "A life lived with intention beats a busy life every time.",
              category: .focus, source: nil),
        .init(text: "Clarity on what matters makes every decision easier.",
              category: .focus, source: nil),
        .init(text: "Deep work on the right thing beats scattered effort on everything.",
              category: .focus, source: nil),
        .init(text: "Before you check your notifications, check your priorities.",
              category: .focus, source: nil),
        .init(text: "Protect your mornings — the first hour shapes the other twenty-three.",
              category: .focus, source: nil),
        .init(text: "One meaningful goal pursued with focus beats ten goals pursued with noise.",
              category: .focus, source: nil),

        // CLARITY
        .init(text: "Knowing who you're becoming changes how you act today.",
              category: .clarity, source: nil),
        .init(text: "The clearer your why, the lighter your how feels.",
              category: .clarity, source: nil),
        .init(text: "Uncertainty isn't a problem — it's where every meaningful life begins.",
              category: .clarity, source: nil),
        .init(text: "Write it down. An unwritten goal is just a wish.",
              category: .clarity, source: nil),
        .init(text: "Reflect often. Progress you can't see is progress you can't build on.",
              category: .clarity, source: nil),
        .init(text: "The version of you five years from now is shaped by choices this week.",
              category: .clarity, source: nil),
        .init(text: "Slow down to ask the right question. Speed up once you have the answer.",
              category: .clarity, source: nil),

        // GROWTH
        .init(text: "Growth is uncomfortable — that's how you know it's real.",
              category: .growth, source: nil),
        .init(text: "Every area of your life that's thriving once started exactly where you are now.",
              category: .growth, source: nil),
        .init(text: "Level up doesn't mean perfect. It means one notch better than yesterday.",
              category: .growth, source: nil),
        .init(text: "You are not behind. You are exactly where your next growth opportunity is.",
              category: .growth, source: nil),
        .init(text: "The skill you develop today becomes the advantage you enjoy for years.",
              category: .growth, source: nil),
        .init(text: "Learning something hard makes the person doing it stronger — not just smarter.",
              category: .growth, source: nil),
        .init(text: "Chase progress in your health, work, and relationships simultaneously — they feed each other.",
              category: .growth, source: nil),

        // RESILIENCE
        .init(text: "A missed day isn't failure — it's data. Adjust and continue.",
              category: .resilience, source: nil),
        .init(text: "The comeback is always harder than the setback. And always more worth it.",
              category: .resilience, source: nil),
        .init(text: "Resistance is highest right before breakthrough. Keep going.",
              category: .resilience, source: nil),
        .init(text: "You've already overcome things that seemed impossible. Trust that pattern.",
              category: .resilience, source: nil),
        .init(text: "Rest when you need to. Quit never.",
              category: .resilience, source: nil),
        .init(text: "Difficult days are not detours — they're part of the path.",
              category: .resilience, source: nil),
        .init(text: "Discipline is just caring about your future self enough to act now.",
              category: .resilience, source: nil),

        // MINDSET
        .init(text: "Identity shapes action. Act like the person you're becoming — starting today.",
              category: .mindset, source: nil),
        .init(text: "Success isn't a destination. It's what happens when your daily actions align with your values.",
              category: .mindset, source: nil),
        .init(text: "Don't compare your chapter one to someone else's chapter twenty.",
              category: .mindset, source: nil),
        .init(text: "Gratitude for where you are and hunger for where you're going — hold both.",
              category: .mindset, source: nil),
        .init(text: "The story you tell yourself about your life is the most powerful one you'll ever hear.",
              category: .mindset, source: nil),
        .init(text: "Time is the one resource that doesn't replenish. Spend it like it matters — because it does.",
              category: .mindset, source: nil),
        .init(text: "Execution is the difference between the life you imagine and the life you live.",
              category: .mindset, source: nil),
    ]
}

// ============================================================
// MARK: - FutureSelf
// ============================================================

struct FutureSelf {
    let narrative: String
    let horizon:   String   // e.g. "12 months from now"

    static let placeholder = FutureSelf(
        narrative: "In 12 months, you've built a life that feels deeply aligned. Your health is thriving, your work carries meaning, and your relationships run deep. This version of you is closer than you think.",
        horizon: "12 months from now"
    )
}

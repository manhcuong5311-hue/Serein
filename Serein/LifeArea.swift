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
    let text:   String
    let source: String?

    static let placeholder = DailyInsight(
        text: "Each small step you take today compounds into the life you envision. Progress isn't always visible — but it's always real.",
        source: nil
    )
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

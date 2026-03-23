// FutureVision.swift
// Life Compass — Future Vision Models
//
// The user's written vision of who they are becoming.
// Stored locally in UserDefaults; designed for Core Data / CloudKit later.

import SwiftUI

// ============================================================
// MARK: - Future Vision Category
// ============================================================

enum FutureVisionCategory: String, CaseIterable, Codable, Hashable {
    case career, health, lifestyle, identity

    var label: String {
        switch self {
        case .career:    return "Career"
        case .health:    return "Health"
        case .lifestyle: return "Lifestyle"
        case .identity:  return "Identity"
        }
    }

    var icon: String {
        switch self {
        case .career:    return "briefcase.fill"
        case .health:    return "heart.fill"
        case .lifestyle: return "house.fill"
        case .identity:  return "person.crop.circle.fill"
        }
    }

    var accent: Color {
        switch self {
        case .career:    return .lcPrimary
        case .health:    return .lcGold
        case .lifestyle: return .lcLavender
        case .identity:  return .lcBeige
        }
    }

    var editPlaceholder: String {
        switch self {
        case .career:
            return "What work will you be doing? What impact will you have made?"
        case .health:
            return "How does your body feel? What habits define your physical life?"
        case .lifestyle:
            return "Where do you live? How do your days feel? What does your home hold?"
        case .identity:
            return "Who are you at your core? How do others experience you?"
        }
    }
}

// ============================================================
// MARK: - Future Vision Area
// ============================================================

struct FutureVisionArea: Identifiable, Codable, Hashable {
    let id:          UUID
    var category:    FutureVisionCategory
    var description: String

    init(category: FutureVisionCategory, description: String = "") {
        self.id          = UUID()
        self.category    = category
        self.description = description
    }
}

// ============================================================
// MARK: - Future Vision
// ============================================================

struct FutureVision: Codable, Equatable {
    var targetAge:  Int
    var narrative:  String
    var areas:      [FutureVisionArea]
    var coreValues: [String]

    // Ensure all four categories are always present
    mutating func normalizeAreas() {
        for cat in FutureVisionCategory.allCases {
            if !areas.contains(where: { $0.category == cat }) {
                areas.append(FutureVisionArea(category: cat))
            }
        }
        // Sort to consistent order
        areas.sort { $0.category.rawValue < $1.category.rawValue }
    }

    // ── Placeholder ───────────────────────────────────────────
    static let placeholder = FutureVision(
        targetAge: 35,
        narrative: "I wake up with clarity and purpose. My work creates real value in the world and my health gives me the energy to pursue what matters. The people around me are deeply trusted, and I show up for them with presence. I am calm, capable, and fully myself.",
        areas: [
            FutureVisionArea(
                category: .career,
                description: "I lead meaningful projects that align with my values. My work is recognized and financially rewarding."
            ),
            FutureVisionArea(
                category: .health,
                description: "I move my body every morning. I sleep deeply, eat mindfully, and have more energy than I did at 25."
            ),
            FutureVisionArea(
                category: .lifestyle,
                description: "I live in a space that reflects who I am — calm, beautiful, intentional. I travel twice a year."
            ),
            FutureVisionArea(
                category: .identity,
                description: "I am patient, curious, and deeply kind. I have learned to say no to what doesn't matter."
            ),
        ],
        coreValues: ["Integrity", "Growth", "Presence", "Courage", "Depth"]
    )
}

// ============================================================
// MARK: - Persistence
// ============================================================

extension FutureVision {
    private static let storageKey = "lc.futureVision"

    static func load() -> FutureVision {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              var decoded = try? JSONDecoder().decode(FutureVision.self, from: data)
        else { return .placeholder }
        decoded.normalizeAreas()
        return decoded
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(encoded, forKey: FutureVision.storageKey)
    }
}

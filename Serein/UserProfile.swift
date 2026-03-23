// UserProfile.swift
// Life Compass — User Profile Model
//
// Codable, persisted to UserDefaults.
// Provides a top-level greeting function used by Dashboard + Onboarding.

import Foundation

// ============================================================
// MARK: - UserProfile
// ============================================================

struct UserProfile: Identifiable, Codable {
    let id:        UUID
    var name:      String
    var age:       Int?
    let createdAt: Date

    init(
        id:        UUID  = UUID(),
        name:      String,
        age:       Int?  = nil,
        createdAt: Date  = Date()
    ) {
        self.id        = id
        self.name      = name
        self.age       = age
        self.createdAt = createdAt
    }

    // ── Persistence ───────────────────────────────────────────

    private static let storageKey = "lc.userProfile"

    static func load() -> UserProfile? {
        guard let data    = UserDefaults.standard.data(forKey: storageKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return nil }
        return profile
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func delete() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

// ============================================================
// MARK: - Greeting
// ============================================================

/// Returns a time-aware greeting personalised with the user's first name.
/// - 05:00–11:59 → Good morning
/// - 12:00–17:59 → Good afternoon
/// - 18:00–04:59 → Good evening
func greeting(for name: String) -> String {
    let hour = Calendar.current.component(.hour, from: Date())
    let salutation: String
    switch hour {
    case 5..<12:  salutation = "Good morning"
    case 12..<18: salutation = "Good afternoon"
    default:      salutation = "Good evening"
    }
    // Use only first word (first name) to keep greeting compact
    let firstName = name.components(separatedBy: " ").first ?? name
    return "\(salutation), \(firstName)"
}

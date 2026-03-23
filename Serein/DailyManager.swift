// DailyManager.swift
// Life Compass — Daily Engine
//
// Stateless struct. Detects when the calendar day has changed
// so AppState can promote tomorrow→today steps and reset recurrings.
// Called on app launch and every time the app returns to foreground.

import Foundation

struct DailyManager {

    static let lastActiveDateKey = "lc.lastActiveDate"

    /// Returns true if we haven't seen this calendar day yet.
    /// First launch always returns true (no stored date).
    static func isNewDay() -> Bool {
        guard let last = UserDefaults.standard.object(forKey: lastActiveDateKey) as? Date else {
            return true   // first launch
        }
        // Compare start-of-day in the current time zone to handle DST / timezone changes.
        let cal   = Calendar.current
        let lastDay  = cal.startOfDay(for: last)
        let today    = cal.startOfDay(for: Date())
        return lastDay < today
    }

    /// Stamps today as the last-active date. Call after processing the new-day logic.
    static func markToday() {
        UserDefaults.standard.set(Date(), forKey: lastActiveDateKey)
    }

    /// Convenience: run the new-day check and mark in one call.
    /// Returns true if a new day was detected.
    @discardableResult
    static func checkAndMark() -> Bool {
        let isNew = isNewDay()
        markToday()
        return isNew
    }
}

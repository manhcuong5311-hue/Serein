// GoalsViewModel.swift
// Life Compass — Goals ViewModel
//
// Lightweight grouping helper.
// All data and mutations now live in AppState.
// GoalGroup is kept here as a shared type used by GoalsView.

import SwiftUI
import Combine

// ============================================================
// MARK: - GoalGroup
// ============================================================

struct GoalGroup: Identifiable {
    var id:    UUID  { area.id }
    let area:  LifeArea
    var goals: [Goal]
}

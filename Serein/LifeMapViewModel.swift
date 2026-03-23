// LifeMapViewModel.swift
// Life Compass — Life Map Model + ViewModel
//
// Sources all data from AppState via init injection.
// Merges goals, milestones, and future vision into a
// single chronological timeline sorted by age.

import SwiftUI
import Combine

// ============================================================
// MARK: - LifeNodeType
// ============================================================

enum LifeNodeType {
    case goal       // active or completed goal
    case vision     // future vision area
    case present    // "You are here" marker
}

// ============================================================
// MARK: - LifeMapNode
// ============================================================

struct LifeMapNode: Identifiable {
    let id:          UUID
    let type:        LifeNodeType
    let age:         Int
    let title:       String
    let description: String?
    let accent:      Color
    let isCompleted: Bool

    var sortOrder: Int {
        switch type {
        case .present: return 0
        case .goal:    return 1
        case .vision:  return 2
        }
    }
}

// ============================================================
// MARK: - LifeMapViewModel
// ============================================================

@MainActor
final class LifeMapViewModel: ObservableObject {

    @Published private(set) var nodes:          [LifeMapNode] = []
    @Published private(set) var phase:          LoadPhase     = .idle
    @Published              var expandedNodeId: UUID?         = nil

    @AppStorage("lc.currentAge") var currentAge: Int = 25

    enum LoadPhase: Equatable { case idle, loading, loaded, empty }

    // ── Age relation (used for styling) ──────────────────────
    enum AgeRelation { case past, present, future }

    func relation(for node: LifeMapNode) -> AgeRelation {
        if node.type == .present   { return .present }
        if node.age  <  currentAge { return .past    }
        if node.age  == currentAge { return .present }
        return .future
    }

    // ── Load (from AppState data) ─────────────────────────────

    func load(goals: [Goal], areas: [LifeArea], vision: FutureVision) async {
        guard phase == .idle else { return }
        phase = .loading

        try? await Task.sleep(for: .milliseconds(500))

        let built = buildTimeline(goals: goals, areas: areas, vision: vision)

        withAnimation(.lcSoftAppear) {
            nodes = built
            phase = built.isEmpty ? .empty : .loaded
        }
    }

    func refresh(goals: [Goal], areas: [LifeArea], vision: FutureVision) async {
        phase = .idle
        nodes = []
        await load(goals: goals, areas: areas, vision: vision)
    }

    // ── Interaction ───────────────────────────────────────────

    func toggleExpanded(_ id: UUID) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.lcSoftAppear) {
            expandedNodeId = expandedNodeId == id ? nil : id
        }
    }

    // ── Timeline builder ──────────────────────────────────────

    private func buildTimeline(
        goals:  [Goal],
        areas:  [LifeArea],
        vision: FutureVision
    ) -> [LifeMapNode] {

        var result: [LifeMapNode] = []

        func area(for goal: Goal) -> LifeArea? {
            areas.first { $0.id == goal.lifeAreaId }
        }

        // 1. Completed goals — distributed across recent past
        let completed = goals.filter(\.isComplete)
        for (i, goal) in completed.enumerated() {
            guard let a = area(for: goal) else { continue }
            let pastAge = max(currentAge - completed.count + i, currentAge - 8)
            result.append(LifeMapNode(
                id: UUID(), type: .goal,
                age: pastAge, title: goal.title,
                description: goal.why,
                accent: a.accent, isCompleted: true
            ))
        }

        // 2. "You are here" marker
        let activeCount = goals.filter { !$0.isComplete && !$0.isArchived }.count
        result.append(LifeMapNode(
            id: UUID(), type: .present,
            age: currentAge, title: "You are here",
            description: "\(activeCount) goal\(activeCount == 1 ? "" : "s") in progress · age \(currentAge)",
            accent: .lcPrimary, isCompleted: false
        ))

        // 3. Active goals — same age as present
        let active = goals.filter { !$0.isComplete && !$0.isArchived }
        for goal in active {
            guard let a = area(for: goal) else { continue }
            result.append(LifeMapNode(
                id: UUID(), type: .goal,
                age: currentAge, title: goal.title,
                description: goal.why,
                accent: a.accent, isCompleted: false
            ))
        }

        // 4. Overall vision narrative
        if !vision.narrative.isEmpty {
            result.append(LifeMapNode(
                id: UUID(), type: .vision,
                age: vision.targetAge, title: "Your Future Self",
                description: vision.narrative,
                accent: .lcGold, isCompleted: false
            ))
        }

        // 5. Individual vision life areas
        for visionArea in vision.areas where !visionArea.description.isEmpty {
            result.append(LifeMapNode(
                id: UUID(), type: .vision,
                age: vision.targetAge,
                title: visionArea.category.label,
                description: visionArea.description,
                accent: visionArea.category.accent,
                isCompleted: false
            ))
        }

        // Sort: age ascending, then present < goal < vision
        result.sort {
            $0.age != $1.age
                ? $0.age < $1.age
                : $0.sortOrder < $1.sortOrder
        }

        return result
    }
}

// LifeMapView.swift
// Life Compass — Life Map Screen
//
// The user sees their life as a journey through time.
// Data sourced from AppState via @EnvironmentObject.

import SwiftUI
import Combine

// ============================================================
// MARK: - LifeMapView
// ============================================================

struct LifeMapView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = LifeMapViewModel()

    var body: some View {
        ZStack {
            LCBackground(showNoise: true)

            switch vm.phase {
            case .idle, .loading:
                LifeMapSkeletonView()
                    .transition(.opacity)

            case .empty:
                LifeMapEmptyState()
                    .transition(.opacity)

            case .loaded:
                TimelineScroll(vm: vm)
                    .transition(.opacity)
            }
        }
        .animation(.lcSoftAppear, value: vm.phase)

        .task {
            await vm.load(
                goals:  appState.goals,
                areas:  appState.lifeAreas,
                vision: appState.futureVision
            )
        }
        .onChange(of: appState.goals) { _, newGoals in
            Task {
                await vm.refresh(
                    goals:  newGoals,
                    areas:  appState.lifeAreas,
                    vision: appState.futureVision
                )
            }
        }
        .onChange(of: appState.futureVision) { _, newVision in
            Task {
                await vm.refresh(
                    goals:  appState.goals,
                    areas:  appState.lifeAreas,
                    vision: newVision
                )
            }
        }
    }
}

// ============================================================
// MARK: - Timeline Scroll
// ============================================================

private struct TimelineScroll: View {
    @ObservedObject var vm: LifeMapViewModel

    private let spineX: CGFloat = 70

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack(alignment: .topLeading) {

                // Connecting spine line
                GeometryReader { geo in
                    Color.white.opacity(0.10)
                        .frame(width: 1.5)
                        .frame(height: geo.size.height)
                        .offset(x: spineX)
                }

                // Node rows
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(vm.nodes.enumerated()), id: \.element.id) { idx, node in
                        TimelineRow(
                            node:       node,
                            isExpanded: vm.expandedNodeId == node.id,
                            relation:   vm.relation(for: node),
                            onTap:      { vm.toggleExpanded(node.id) }
                        )
                        .softAppear(delay: 0.06 + Double(min(idx, 8)) * 0.08)
                    }
                }
            }
            .padding(.top, LCSpacing.md)
            .padding(.bottom, LCSpacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// ============================================================
// MARK: - Timeline Row
// ============================================================

private struct TimelineRow: View {
    let node:       LifeMapNode
    let isExpanded: Bool
    let relation:   LifeMapViewModel.AgeRelation
    let onTap:      () -> Void

    private let ageLabelWidth:  CGFloat = 44
    private let gap:            CGFloat = 12
    private let dotColumnWidth: CGFloat = 28

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            AgeLabel(age: node.age, type: node.type, relation: relation)
                .frame(width: ageLabelWidth, alignment: .trailing)

            Spacer().frame(width: gap)

            NodeDot(type: node.type, accent: node.accent, relation: relation)
                .frame(width: dotColumnWidth, height: dotColumnWidth)
                .padding(.top, 2)

            Spacer().frame(width: LCSpacing.sm)

            NodeCard(
                node:       node,
                isExpanded: isExpanded,
                relation:   relation,
                onTap:      onTap
            )
            .padding(.trailing, LCSpacing.md)
        }
        .padding(.horizontal, LCSpacing.md)
        .padding(.bottom, node.type == .present ? LCSpacing.lg : LCSpacing.md)
    }
}

// ============================================================
// MARK: - Age Label
// ============================================================

private struct AgeLabel: View {
    let age:      Int
    let type:     LifeNodeType
    let relation: LifeMapViewModel.AgeRelation

    var body: some View {
        if type == .present {
            Color.clear.frame(width: 44, height: 28)
        } else {
            Text("\(age)")
                .font(.system(size: 13, weight: relation == .past ? .light : .medium, design: .monospaced))
                .foregroundStyle(labelColor)
                .frame(minHeight: 28, alignment: .center)
        }
    }

    private var labelColor: Color {
        switch relation {
        case .past:    return .lcTextTertiary.opacity(0.55)
        case .present: return .lcTextTertiary
        case .future:  return .lcGold.opacity(0.70)
        }
    }
}

// ============================================================
// MARK: - Node Dot
// ============================================================

private struct NodeDot: View {
    let type:     LifeNodeType
    let accent:   Color
    let relation: LifeMapViewModel.AgeRelation

    var body: some View {
        switch type {
        case .present: PresentDot()
        case .vision:  VisionDot(accent: accent)
        case .goal:    GoalDot(accent: accent, relation: relation)
        }
    }
}

private struct PresentDot: View {
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.lcPrimary.opacity(0.25), lineWidth: 1.5)
                .frame(width: 28, height: 28)
                .pulseGlow(
                    color:      .lcPrimary,
                    minOpacity: 0.08,
                    maxOpacity: 0.35,
                    minRadius:  4,
                    maxRadius:  14
                )

            Circle()
                .fill(Color.lcPrimary)
                .frame(width: 14, height: 14)
                .shadow(color: Color.lcPrimary.opacity(0.70), radius: 8)
        }
    }
}

private struct VisionDot: View {
    let accent: Color

    var body: some View {
        ZStack {
            Circle().fill(accent.opacity(0.15)).frame(width: 26, height: 26)
            Circle().strokeBorder(accent.opacity(0.50), lineWidth: 1.5).frame(width: 26, height: 26)
            Circle().fill(accent).frame(width: 10, height: 10)
        }
    }
}

private struct GoalDot: View {
    let accent:   Color
    let relation: LifeMapViewModel.AgeRelation

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(relation == .past ? 0.25 : 0.18))
                .frame(width: 20, height: 20)
            Circle()
                .fill(accent.opacity(relation == .past ? 0.60 : 0.85))
                .frame(width: 9, height: 9)
        }
    }
}

// ============================================================
// MARK: - Node Card (router)
// ============================================================

private struct NodeCard: View {
    let node:       LifeMapNode
    let isExpanded: Bool
    let relation:   LifeMapViewModel.AgeRelation
    let onTap:      () -> Void

    var body: some View {
        switch node.type {
        case .present: PresentNodeCard(node: node)
        case .goal:    GoalNodeCard(node: node, isExpanded: isExpanded, relation: relation, onTap: onTap)
        case .vision:  VisionNodeCard(node: node, isExpanded: isExpanded, onTap: onTap)
        }
    }
}

private struct PresentNodeCard: View {
    let node: LifeMapNode

    var body: some View {
        GlassCard(glowColor: .lcPrimary, glowOpacity: 0.22) {
            HStack(spacing: LCSpacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOU ARE HERE")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)
                    Text(node.title)
                        .font(LCFont.header)
                        .foregroundStyle(Color.lcTextPrimary)
                    if let desc = node.description {
                        Text(desc)
                            .font(LCFont.insight)
                            .foregroundStyle(Color.lcPrimary.opacity(0.80))
                    }
                }
                Spacer()
                Text("\(node.age)")
                    .font(.system(size: 28, weight: .thin, design: .monospaced))
                    .foregroundStyle(Color.lcPrimary.opacity(0.85))
            }
            .padding(LCSpacing.md)
        }
    }
}

private struct GoalNodeCard: View {
    let node:       LifeMapNode
    let isExpanded: Bool
    let relation:   LifeMapViewModel.AgeRelation
    let onTap:      () -> Void

    private var dimmed: Bool { relation == .past }

    var body: some View {
        Button(action: onTap) {
            GlassCard(
                glowColor:   node.accent,
                glowOpacity: dimmed ? 0.06 : (isExpanded ? 0.18 : 0.10)
            ) {
                VStack(alignment: .leading, spacing: LCSpacing.xs) {
                    HStack(alignment: .top) {
                        if node.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(node.accent.opacity(0.70))
                        }
                        Text(node.title)
                            .font(LCFont.body)
                            .fontWeight(.medium)
                            .foregroundStyle(dimmed ? Color.lcTextSecondary.opacity(0.65) : Color.lcTextPrimary)
                            .lineLimit(isExpanded ? nil : 1)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.lcTextTertiary.opacity(0.50))
                    }

                    if isExpanded, let desc = node.description, !desc.isEmpty {
                        Text(desc)
                            .font(LCFont.insight)
                            .italic()
                            .foregroundStyle(Color.lcTextSecondary.opacity(0.80))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .offset(y: -4)))
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(node.accent.opacity(dimmed ? 0.45 : 0.85))
                            .frame(width: 5, height: 5)
                        Text(node.isCompleted ? "Completed" : (relation == .present ? "In Progress" : "Active"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(node.accent.opacity(dimmed ? 0.50 : 0.75))
                    }
                }
                .padding(LCSpacing.sm)
            }
        }
        .buttonStyle(.plain)
        .animation(.lcSoftAppear, value: isExpanded)
    }
}

private struct VisionNodeCard: View {
    let node:       LifeMapNode
    let isExpanded: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
            GlassCard(
                glowColor:   node.accent,
                glowOpacity: isExpanded ? 0.22 : 0.13
            ) {
                VStack(alignment: .leading, spacing: LCSpacing.xs) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("FUTURE VISION")
                                .font(LCFont.overline)
                                .foregroundStyle(node.accent.opacity(0.70))
                            Text(node.title)
                                .font(LCFont.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.lcTextPrimary)
                                .lineLimit(isExpanded ? nil : 1)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.lcTextTertiary.opacity(0.50))
                    }

                    if isExpanded, let desc = node.description, !desc.isEmpty {
                        Divider().background(Color.white.opacity(0.06))
                        Text(desc)
                            .font(LCFont.body)
                            .foregroundStyle(Color.lcTextSecondary.opacity(0.88))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity.combined(with: .offset(y: -4)))
                    }
                }
                .padding(LCSpacing.sm)
            }
        }
        .buttonStyle(.plain)
        .animation(.lcSoftAppear, value: isExpanded)
    }
}

// ============================================================
// MARK: - Header (public — used by MainTabView)
// ============================================================

struct LifeMapHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.xs) {
            Text("LIFE MAP")
                .font(LCFont.overline)
                .foregroundStyle(Color.lcTextTertiary)
                .softAppear(delay: 0.04)
            Text("Your Journey")
                .font(LCFont.largeTitle)
                .foregroundStyle(Color.lcTextPrimary)
                .softAppear(delay: 0.08)
            Text("Past goals, present momentum, future vision.")
                .font(LCFont.insight)
                .foregroundStyle(Color.lcTextTertiary)
                .softAppear(delay: 0.12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LCSpacing.md)
        .padding(.top, LCSpacing.xl)
        .padding(.bottom, LCSpacing.sm)
    }
}

// ============================================================
// MARK: - Empty State
// ============================================================

private struct LifeMapEmptyState: View {
    var body: some View {
        VStack(spacing: LCSpacing.lg) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(Color.lcTextTertiary.opacity(0.55))
                .softAppear(delay: 0.05)

            VStack(spacing: LCSpacing.xs) {
                Text("Your life story will appear here")
                    .font(LCFont.header)
                    .foregroundStyle(Color.lcTextPrimary)
                    .softAppear(delay: 0.10)

                Text("Add goals and a future vision\nto see your journey take shape.")
                    .font(LCFont.body)
                    .foregroundStyle(Color.lcTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .softAppear(delay: 0.16)
            }
            Spacer()
        }
        .padding(.horizontal, LCSpacing.lg)
    }
}

// ============================================================
// MARK: - Skeleton
// ============================================================

private struct LifeMapSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.lg) {
            ForEach(0..<5, id: \.self) { i in
                HStack(alignment: .top, spacing: 0) {
                    ShimmerBar(width: 30, height: 14, radius: 4)
                        .frame(width: 44, alignment: .trailing)
                    Spacer().frame(width: 12)
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 18, height: 18)
                        .padding(.top, 2)
                    Spacer().frame(width: LCSpacing.sm)
                    ShimmerBar(
                        width: CGFloat.random(in: 160...240),
                        height: 48,
                        radius: 12
                    )
                    Spacer()
                }
                .padding(.horizontal, LCSpacing.md)
                .softAppear(delay: Double(i) * 0.07)
            }
            Spacer()
        }
        .padding(.top, LCSpacing.xl)
    }
}

// ============================================================
// MARK: - Previews
// ============================================================

#Preview("Life Map") {
    ZStack(alignment: .top) {
        LCBackground(showNoise: true)
        VStack(spacing: 0) {
            LifeMapHeaderView()
            LifeMapView()
        }
    }
    .environmentObject(AppState())
}

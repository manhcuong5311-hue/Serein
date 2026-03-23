// MainTabView.swift
// Life Compass — Root Tab Navigation
//
// 5 tabs, each in its own NavigationStack so navigation state
// is isolated per tab.
//
//   Dashboard   — home icon  — daily loop entry point
//   Goals       — target     — where action happens
//   Life Map    — map        — life journey visualization
//   Reflect     — moon       — weekly reflection entry
//   Settings    — gear       — preferences

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Int = 0
    @State private var showReflection: Bool = false

    var body: some View {
        TabView(selection: $selectedTab) {

            // ── Tab 0: Dashboard ──────────────────────────────
            NavigationStack {
                LifeDashboardView(
                    onGoToGoals:      { selectedTab = 1 },
                    onGoToReflection: { showReflection = true },
                    onGoToVision:     { selectedTab = 3 }
                )
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(0)

            // ── Tab 1: Goals ──────────────────────────────────
            GoalsView()
                .tabItem {
                    Label("Goals", systemImage: "scope")
                }
                .tag(1)

            // ── Tab 2: Life Map ───────────────────────────────
            NavigationStack {
                VStack(spacing: 0) {
                    LifeMapHeaderView()
                    LifeMapView()
                }
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }
            .tag(2)

            // ── Tab 3: Reflect ────────────────────────────────
            NavigationStack {
                FutureSelfView()
            }
            .tabItem {
                Label("Vision", systemImage: "person.crop.circle.fill.badge.plus")
            }
            .tag(3)

            // ── Tab 4: Settings ───────────────────────────────
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(4)
        }
        .tint(Color.lcPrimary)
        .preferredColorScheme(.dark)
        // Weekly reflection sheet — triggered from Dashboard or streak prompt
        .sheet(isPresented: $showReflection) {
            WeeklyReflectionView(
                onReflectionSaved: { reflection in
                    appState.saveReflection(reflection)
                }
            )
            .presentationDragIndicator(.visible)
            .presentationDetents([.large])
        }
        .onChange(of: appState.shouldShowReflectionPrompt) { _, show in
            // Could auto-open here if desired; currently user-initiated via Dashboard card
            _ = show
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppState())
}

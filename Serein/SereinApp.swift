//
//  SereinApp.swift
//  Serein
//
//  Entry point. Creates the single AppState instance and injects
//  it as an EnvironmentObject into every view in the hierarchy.
//
//  DailyManager is called on launch and every foreground transition
//  so tomorrow steps are promoted and recurring steps are reset
//  automatically the moment the user opens the app on a new day.
//

import SwiftUI

@main
struct SereinApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState.handleNewDayIfNeeded()
            }
        }
    }
}

// ============================================================
// MARK: - RootView
// ============================================================
// Decides whether to show onboarding or the main tab interface.
// Lives here so it can react to appState.onboardingComplete.

private struct RootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if appState.onboardingComplete {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .animation(.lcSoftAppear, value: appState.onboardingComplete)
    }
}

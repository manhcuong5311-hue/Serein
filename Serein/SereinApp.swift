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
import UserNotifications

@main
struct SereinApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("lc.appColorScheme") private var appColorScheme: Int = 0

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(appColorScheme == 1 ? .light : .dark)
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
//
// Notification permission is requested once — immediately after
// onboarding completes — without interrupting the main flow.

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
        // Request notification permission after onboarding completes.
        // Only fires when status is .notDetermined (i.e., first launch).
        .task(id: appState.onboardingComplete) {
            guard appState.onboardingComplete else { return }
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            // Small delay so the main UI settles first
            try? await Task.sleep(for: .milliseconds(1_200))
            do {
                try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                // Permission request failed — not actionable, safe to ignore
            }
        }
    }
}

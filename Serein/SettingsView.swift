// SettingsView.swift
// Life Compass — Settings Screen
//
// Minimal, thoughtful. No noise.
// Reset uses AppState to wipe all data cleanly.

import SwiftUI
import Combine
import UserNotifications

// ============================================================
// MARK: - SettingsViewModel
// ============================================================

@MainActor
final class SettingsViewModel: ObservableObject {

    @AppStorage("lc.reminderEnabled")  var reminderEnabled: Bool = false
    @AppStorage("lc.reminderHour")     var reminderHour: Int  = 20
    @AppStorage("lc.reminderWeekday")  var reminderWeekday: Int = 1

    @Published var showResetConfirmation: Bool = false
    @Published var showResetDone:         Bool = false
    @Published var notificationStatus:    UNAuthorizationStatus = .notDetermined

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    func checkNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
    }

    func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                reminderEnabled = true
                scheduleReflectionReminder()
            }
        } catch {}
        await checkNotificationStatus()
    }

    func toggleReminder(_ enabled: Bool) {
        if enabled {
            Task { await requestNotificationPermission() }
        } else {
            reminderEnabled = false
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["lc.weeklyReflection"]
            )
        }
    }

    func scheduleReflectionReminder() {
        let center  = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["lc.weeklyReflection"])

        let content        = UNMutableNotificationContent()
        content.title      = "Time to reflect."
        content.body       = "A few minutes of honest reflection can change your week."
        content.sound      = .default

        var components      = DateComponents()
        components.weekday  = reminderWeekday
        components.hour     = reminderHour
        components.minute   = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "lc.weeklyReflection",
            content:    content,
            trigger:    trigger
        )
        center.add(request)
    }
}

// ============================================================
// MARK: - SettingsView
// ============================================================

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = SettingsViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            LCBackground(showNoise: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: LCSpacing.xl) {

                    SettingsHeader()

                    ProfileSection(appState: appState)
                        .softAppear(delay: 0.10)

                    NotificationsSection(vm: vm)
                        .softAppear(delay: 0.18)

                    DataSection(vm: vm)
                        .softAppear(delay: 0.26)

                    AboutSection(vm: vm)
                        .softAppear(delay: 0.34)
                }
                .padding(.horizontal, LCSpacing.md)
                .padding(.top, LCSpacing.xl)
                .padding(.bottom, LCSpacing.xxl)
            }

            if vm.showResetDone {
                ResetDoneToast()
                    .padding(.bottom, LCSpacing.lg)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 10)),
                        removal:   .opacity
                    ))
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .confirmationDialog(
            "Reset all data?",
            isPresented: $vm.showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                appState.resetAllData()
                withAnimation(.lcSoftAppear) { vm.showResetDone = true }
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation(.easeOut(duration: 0.4)) { vm.showResetDone = false }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears your future vision, reflections, daily activity, and settings. Goals are reset to samples.")
        }
        .task { await vm.checkNotificationStatus() }
    }
}

// ============================================================
// MARK: - Header
// ============================================================

private struct SettingsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.xs) {
            Text("SETTINGS")
                .font(LCFont.overline)
                .foregroundStyle(Color.lcTextTertiary)
                .softAppear(delay: 0.04)
            Text("Your space.")
                .font(LCFont.largeTitle)
                .foregroundStyle(Color.lcTextPrimary)
                .softAppear(delay: 0.08)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ============================================================
// MARK: - Profile Section
// ============================================================

private struct ProfileSection: View {
    @ObservedObject var appState: AppState

    @State private var editingName: String = ""
    @State private var isEditingName: Bool = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        SettingsSection(title: "PROFILE") {
            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.10) {
                VStack(spacing: 0) {

                    // ── Name row ──────────────────────────────
                    HStack(spacing: LCSpacing.sm) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 16, weight: .light))
                            .foregroundStyle(Color.lcTextSecondary.opacity(0.75))
                            .frame(width: 24)

                        Text("Name")
                            .font(LCFont.body)
                            .foregroundStyle(Color.lcTextSecondary)

                        Spacer()

                        if isEditingName {
                            TextField("Your name", text: $editingName)
                                .font(LCFont.body)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.lcTextPrimary)
                                .multilineTextAlignment(.trailing)
                                .focused($nameFocused)
                                .submitLabel(.done)
                                .onSubmit { saveName() }
                                .frame(maxWidth: 160)

                            Button(action: saveName) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.lcPrimary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                editingName = appState.userProfile?.name ?? ""
                                isEditingName = true
                                nameFocused   = true
                            } label: {
                                Text(appState.userProfile?.name ?? "Add name")
                                    .font(LCFont.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(
                                        appState.userProfile?.name != nil
                                            ? Color.lcTextPrimary
                                            : Color.lcTextTertiary
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(LCSpacing.md)

                    SettingsDivider()

                    // ── Age row ───────────────────────────────
                    SettingsRow(icon: "calendar", label: "Age") {
                        Stepper(
                            value: appState.$currentAge,
                            in:    10...100,
                            step:  1
                        ) {
                            Text("\(appState.currentAge)")
                                .font(LCFont.body)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.lcGold)
                                .contentTransition(.numericText())
                        }
                        .onChange(of: appState.currentAge) { _, newAge in
                            if var profile = appState.userProfile {
                                profile.age = newAge
                                appState.saveUserProfile(profile)
                            }
                        }
                    }

                    SettingsDivider()

                    SettingsNote("Your age anchors the Life Map timeline.")
                }
            }
        }
    }

    private func saveName() {
        let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isEditingName = false
            return
        }
        if var profile = appState.userProfile {
            profile.name = trimmed
            appState.saveUserProfile(profile)
        } else {
            let profile = UserProfile(name: trimmed, age: appState.currentAge)
            appState.saveUserProfile(profile)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        isEditingName = false
    }
}

// ============================================================
// MARK: - Notifications Section
// ============================================================

private struct NotificationsSection: View {
    @ObservedObject var vm: SettingsViewModel

    private var statusNote: String {
        switch vm.notificationStatus {
        case .denied:     return "Notifications are blocked. Enable them in iOS Settings."
        case .authorized: return "You'll get a gentle nudge every Sunday evening."
        default:          return "Tap to enable a weekly reflection reminder."
        }
    }

    var body: some View {
        SettingsSection(title: "NOTIFICATIONS") {
            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.08) {
                VStack(spacing: 0) {
                    SettingsRow(icon: "bell", label: "Weekly Reminder") {
                        Toggle("", isOn: Binding(
                            get: { vm.reminderEnabled },
                            set: { vm.toggleReminder($0) }
                        ))
                        .labelsHidden()
                        .tint(Color.lcPrimary)
                        .disabled(vm.notificationStatus == .denied)
                    }

                    if vm.reminderEnabled && vm.notificationStatus == .authorized {
                        SettingsDivider()
                        SettingsRow(icon: "clock", label: "Day") {
                            Picker("", selection: $vm.reminderWeekday) {
                                Text("Sunday").tag(1)
                                Text("Monday").tag(2)
                                Text("Friday").tag(6)
                                Text("Saturday").tag(7)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(Color.lcTextSecondary)
                            .onChange(of: vm.reminderWeekday) { _, _ in
                                vm.scheduleReflectionReminder()
                            }
                        }
                    }

                    SettingsDivider()
                    SettingsNote(statusNote, warning: vm.notificationStatus == .denied)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Data Section
// ============================================================

private struct DataSection: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        SettingsSection(title: "DATA") {
            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.08) {
                VStack(spacing: 0) {
                    Button { vm.showResetConfirmation = true } label: {
                        HStack(spacing: LCSpacing.sm) {
                            Image(systemName: "arrow.counterclockwise.circle")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(Color.lcGold.opacity(0.75))
                                .frame(width: 24)
                            Text("Reset All Data")
                                .font(LCFont.body)
                                .foregroundStyle(Color.lcGold.opacity(0.85))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.lcTextTertiary.opacity(0.40))
                        }
                        .padding(LCSpacing.md)
                    }
                    .buttonStyle(.plain)

                    SettingsDivider()
                    SettingsNote("Clears vision, reflections, activity, and settings. Cannot be undone.")
                }
            }
        }
    }
}

// ============================================================
// MARK: - About Section
// ============================================================

private struct AboutSection: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        SettingsSection(title: "ABOUT") {
            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.07) {
                VStack(spacing: 0) {
                    SettingsRow(icon: "app.badge.checkmark", label: "Version") {
                        Text("\(vm.appVersion) (\(vm.buildNumber))")
                            .font(LCFont.insight)
                            .foregroundStyle(Color.lcTextTertiary)
                    }

                    SettingsDivider()

                    VStack(alignment: .leading, spacing: LCSpacing.xs) {
                        Text("Life Compass helps you live with intention. Not by tracking every minute — but by knowing where you're going and taking one step each day.")
                            .font(LCFont.insight)
                            .foregroundStyle(Color.lcTextSecondary.opacity(0.75))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, LCSpacing.md)
                    .padding(.vertical, LCSpacing.md)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Reusable Settings Components
// ============================================================

private struct SettingsSection<Content: View>: View {
    let title:   String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {
            Text(title)
                .font(LCFont.overline)
                .foregroundStyle(Color.lcTextTertiary)
            content
        }
    }
}

private struct SettingsRow<Trailing: View>: View {
    let icon:     String
    let label:    String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: LCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(Color.lcTextSecondary.opacity(0.75))
                .frame(width: 24)
            Text(label)
                .font(LCFont.body)
                .foregroundStyle(Color.lcTextSecondary)
            Spacer()
            trailing
        }
        .padding(LCSpacing.md)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .background(Color.white.opacity(0.06))
            .padding(.horizontal, LCSpacing.md)
    }
}

private struct SettingsNote: View {
    let text:    String
    let warning: Bool

    init(_ text: String, warning: Bool = false) {
        self.text    = text
        self.warning = warning
    }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: warning ? "exclamationmark.circle" : "info.circle")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(warning ? Color.lcGold.opacity(0.70) : Color.lcTextTertiary.opacity(0.55))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(warning ? Color.lcGold.opacity(0.70) : Color.lcTextTertiary.opacity(0.55))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, LCSpacing.md)
        .padding(.vertical, LCSpacing.sm)
    }
}

// ============================================================
// MARK: - Reset Done Toast
// ============================================================

private struct ResetDoneToast: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.lcTextSecondary)
            Text("Data cleared")
                .font(LCFont.insight)
                .fontWeight(.medium)
                .foregroundStyle(Color.lcTextPrimary)
        }
        .padding(.horizontal, LCSpacing.md)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                .shadow(color: .black.opacity(0.30), radius: 8, y: 2)
        )
    }
}

// ============================================================
// MARK: - Previews
// ============================================================

#Preview("Settings") {
    SettingsView()
        .environmentObject(AppState())
}

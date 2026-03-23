// SettingsView.swift
// Life Compass — Settings Screen
//
// Minimal, thoughtful. No noise.
// Reset uses AppState to wipe all data cleanly.

import SwiftUI
import Combine
import UserNotifications

// ============================================================
// MARK: - Constants
// ============================================================

private let privacyPolicyURL = URL(string: "https://manhcuong5311-hue.github.io/serein-legal/")!
private let termsOfUseURL    = URL(string: "https://manhcuong5311-hue.github.io/serein-legal/")!
// FAQ is now an in-app sheet — no external URL needed

// ============================================================
// MARK: - SettingsViewModel
// ============================================================

@MainActor
final class SettingsViewModel: ObservableObject {

    // ── Weekly reflection reminder ────────────────────────────
    @AppStorage("lc.reminderEnabled")  var reminderEnabled: Bool = false
    @AppStorage("lc.reminderHour")     var reminderHour:    Int  = 20
    @AppStorage("lc.reminderMinute")   var reminderMinute:  Int  = 0
    @AppStorage("lc.reminderWeekday")  var reminderWeekday: Int  = 1   // 1=Sun…7=Sat

    // ── Morning check-in (daily) ──────────────────────────────
    @AppStorage("lc.morningEnabled")   var morningEnabled:  Bool = false
    @AppStorage("lc.morningHour")      var morningHour:     Int  = 8

    // ── Evening review (daily) ────────────────────────────────
    @AppStorage("lc.eveningEnabled")   var eveningEnabled:  Bool = false
    @AppStorage("lc.eveningHour")      var eveningHour:     Int  = 21

    // ── Appearance ───────────────────────────────────────────
    @AppStorage("lc.appColorScheme")   var appColorScheme:  Int  = 0   // 0=dark 1=light

    @Published var showResetConfirmation:  Bool = false
    @Published var showResetDone:          Bool = false
    @Published var notificationStatus:     UNAuthorizationStatus = .notDetermined
    @Published var isRestoringPurchase:    Bool = false
    @Published var showRestoreAlert:       Bool = false
    @Published var restoreSucceeded:       Bool = false

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // ── Notification label helpers ────────────────────────────

    var weekdayName: String {
        let symbols = Calendar.current.weekdaySymbols
        let idx = max(0, min(reminderWeekday - 1, symbols.count - 1))
        return symbols[idx]
    }

    func timeLabel(hour: Int, minute: Int) -> String {
        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute
        guard let date = Calendar.current.date(from: comps) else { return "\(hour):00" }
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: date)
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
            if notificationStatus == .authorized {
                reminderEnabled = true
                scheduleReflectionReminder()
            } else if notificationStatus == .notDetermined {
                Task { await requestNotificationPermission() }
            }
            // .denied → user must go to iOS Settings; toggle stays off
        } else {
            reminderEnabled = false
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["lc.weeklyReflection"]
            )
        }
    }

    func toggleMorningReminder(_ enabled: Bool) {
        if enabled {
            if notificationStatus == .authorized {
                morningEnabled = true
                scheduleMorningReminder()
            } else if notificationStatus == .notDetermined {
                Task { await requestNotificationPermission() }
            }
        } else {
            morningEnabled = false
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["lc.morningCheckin"]
            )
        }
    }

    func toggleEveningReminder(_ enabled: Bool) {
        if enabled {
            if notificationStatus == .authorized {
                eveningEnabled = true
                scheduleEveningReminder()
            } else if notificationStatus == .notDetermined {
                Task { await requestNotificationPermission() }
            }
        } else {
            eveningEnabled = false
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["lc.eveningReview"]
            )
        }
    }

    func restorePurchase() {
        isRestoringPurchase = true
        Task {
            let found = await FeatureAccessManager.shared.restorePurchase()
            isRestoringPurchase = false
            restoreSucceeded    = found
            showRestoreAlert    = true
            if found { UINotificationFeedbackGenerator().notificationOccurred(.success) }
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
        components.minute   = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "lc.weeklyReflection",
            content:    content,
            trigger:    trigger
        )
        center.add(request)
    }

    func scheduleMorningReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["lc.morningCheckin"])
        guard morningEnabled else { return }
        let content      = UNMutableNotificationContent()
        content.title    = "Good morning."
        content.body     = "What's the one thing you'll do today to move forward?"
        content.sound    = .default
        var comps        = DateComponents()
        comps.hour       = morningHour
        comps.minute     = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: "lc.morningCheckin", content: content, trigger: trigger))
    }

    func scheduleEveningReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["lc.eveningReview"])
        guard eveningEnabled else { return }
        let content      = UNMutableNotificationContent()
        content.title    = "How did today go?"
        content.body     = "Take a moment to acknowledge what you accomplished."
        content.sound    = .default
        var comps        = DateComponents()
        comps.hour       = eveningHour
        comps.minute     = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: "lc.eveningReview", content: content, trigger: trigger))
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

                    PlanSection(vm: vm)
                        .softAppear(delay: 0.08)

                    ProfileSection(appState: appState)
                        .softAppear(delay: 0.14)

                    AppearanceSection(vm: vm)
                        .softAppear(delay: 0.18)

                    NotificationsSection(vm: vm)
                        .softAppear(delay: 0.24)

                    AccountSection(vm: vm)
                        .softAppear(delay: 0.26)

                    LegalSection()
                        .softAppear(delay: 0.30)

                    SupportSection()
                        .softAppear(delay: 0.34)

                    DataSection(vm: vm)
                        .softAppear(delay: 0.38)

                    AboutSection(vm: vm)
                        .softAppear(delay: 0.42)
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

        .confirmationDialog(
            "Reset all data?",
            isPresented: $vm.showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                appState.resetAllData()
                FeatureAccessManager.shared.reset()
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
        .alert(
            vm.restoreSucceeded ? "Purchase Restored" : "Nothing to Restore",
            isPresented: $vm.showRestoreAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(vm.restoreSucceeded
                 ? "Your Premium access has been restored."
                 : "No previous purchase was found for this Apple ID."
            )
        }
        .task { await vm.checkNotificationStatus() }
    }
}

// ============================================================
// MARK: - Plan Section
// ============================================================

private struct PlanSection: View {
    @ObservedObject var vm: SettingsViewModel
    @ObservedObject private var access = FeatureAccessManager.shared
    @State private var showPremium = false

    var body: some View {
        SettingsSection(title: "PLAN") {
            GlassCard(
                glowColor:   access.isPremium ? Color.lcGold : Color.lcPrimary,
                glowOpacity: access.isPremium ? 0.18 : 0.10
            ) {
                VStack(spacing: 0) {

                    // Status row
                    HStack(spacing: LCSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(access.isPremium
                                      ? Color.lcGold.opacity(0.14)
                                      : Color.lcPrimary.opacity(0.12))
                            Image(systemName: access.isPremium ? "sparkles" : "lock.open")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(access.isPremium ? Color.lcGold : Color.lcPrimary)
                        }
                        .frame(width: 34, height: 34)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(access.planLabel)
                                .font(LCFont.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(access.isPremium ? Color.lcGold : Color.lcTextPrimary)
                            Text(access.planSublabel)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.lcTextTertiary)
                        }

                        Spacer()

                        if access.isPremium {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Color.lcGold)
                        }
                    }
                    .padding(LCSpacing.md)

                    // Upgrade button (free only)
                    if !access.isPremium {
                        SettingsDivider()

                        Button { showPremium = true } label: {
                            HStack(spacing: LCSpacing.sm) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.lcPrimary)
                                    .frame(width: 24)
                                Text("Upgrade to Premium")
                                    .font(LCFont.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.lcPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.lcTextTertiary.opacity(0.40))
                            }
                            .padding(LCSpacing.md)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(isPresented: $showPremium) {
            PremiumView()
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
    }
}

// ============================================================
// MARK: - Account Section
// ============================================================

private struct AccountSection: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        SettingsSection(title: "ACCOUNT") {
            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.07) {
                VStack(spacing: 0) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        vm.restorePurchase()
                    } label: {
                        HStack(spacing: LCSpacing.sm) {
                            if vm.isRestoringPurchase {
                                ProgressView()
                                    .tint(Color.lcTextSecondary)
                                    .scaleEffect(0.75)
                                    .frame(width: 24, height: 24)
                            } else {
                                Image(systemName: "arrow.clockwise.circle")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundStyle(Color.lcTextSecondary.opacity(0.75))
                                    .frame(width: 24)
                            }
                            Text(vm.isRestoringPurchase ? "Restoring…" : "Restore Purchase")
                                .font(LCFont.body)
                                .foregroundStyle(Color.lcTextSecondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.lcTextTertiary.opacity(0.40))
                        }
                        .padding(LCSpacing.md)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isRestoringPurchase)

                    SettingsDivider()
                    SettingsNote("Tap to restore a previous Premium purchase on this Apple ID.")
                }
            }
        }
    }
}

// ============================================================
// MARK: - Legal Section
// ============================================================

private struct LegalSection: View {
    var body: some View {
        SettingsSection(title: "LEGAL") {
            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.07) {
                VStack(spacing: 0) {

                    // Privacy Policy
                    Link(destination: privacyPolicyURL) {
                        HStack(spacing: LCSpacing.sm) {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(Color.lcTextSecondary.opacity(0.75))
                                .frame(width: 24)
                            Text("Privacy Policy")
                                .font(LCFont.body)
                                .foregroundStyle(Color.lcTextSecondary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.lcTextTertiary.opacity(0.50))
                        }
                        .padding(LCSpacing.md)
                    }

                    SettingsDivider()

                    // Terms of Use
                    Link(destination: termsOfUseURL) {
                        HStack(spacing: LCSpacing.sm) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(Color.lcTextSecondary.opacity(0.75))
                                .frame(width: 24)
                            Text("Terms of Use (EULA)")
                                .font(LCFont.body)
                                .foregroundStyle(Color.lcTextSecondary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.lcTextTertiary.opacity(0.50))
                        }
                        .padding(LCSpacing.md)
                    }
                }
            }
        }
    }
}

// ============================================================
// MARK: - Support Section
// ============================================================

private struct SupportSection: View {
    @State private var showFAQ = false

    var body: some View {
        SettingsSection(title: "SUPPORT") {
            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.07) {
                VStack(spacing: 0) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showFAQ = true
                    } label: {
                        HStack(spacing: LCSpacing.sm) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 16, weight: .light))
                                .foregroundStyle(Color.lcTextSecondary.opacity(0.75))
                                .frame(width: 24)
                            Text("FAQ")
                                .font(LCFont.body)
                                .foregroundStyle(Color.lcTextSecondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.lcTextTertiary.opacity(0.40))
                        }
                        .padding(LCSpacing.md)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showFAQ) {
            FAQView()
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
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

    // ── Time bindings ──────────────────────────────────────────
    private var reflectionTimeBinding: Binding<Date> {
        Binding {
            var c = DateComponents(); c.hour = vm.reminderHour; c.minute = vm.reminderMinute
            return Calendar.current.date(from: c) ?? Date()
        } set: { date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            vm.reminderHour   = c.hour   ?? 20
            vm.reminderMinute = c.minute ?? 0
            vm.scheduleReflectionReminder()
        }
    }

    private var morningTimeBinding: Binding<Date> {
        Binding {
            var c = DateComponents(); c.hour = vm.morningHour; c.minute = 0
            return Calendar.current.date(from: c) ?? Date()
        } set: { date in
            vm.morningHour = Calendar.current.dateComponents([.hour], from: date).hour ?? 8
            vm.scheduleMorningReminder()
        }
    }

    private var eveningTimeBinding: Binding<Date> {
        Binding {
            var c = DateComponents(); c.hour = vm.eveningHour; c.minute = 0
            return Calendar.current.date(from: c) ?? Date()
        } set: { date in
            vm.eveningHour = Calendar.current.dateComponents([.hour], from: date).hour ?? 21
            vm.scheduleEveningReminder()
        }
    }

    // ── Status note ───────────────────────────────────────────
    private var statusNote: String {
        switch vm.notificationStatus {
        case .denied:
            return "Notifications are blocked in iOS Settings. Go to Settings → Notifications → Serein to enable them."
        case .authorized:
            var parts: [String] = []
            if vm.reminderEnabled  { parts.append("Weekly on \(vm.weekdayName)s at \(vm.timeLabel(hour: vm.reminderHour, minute: vm.reminderMinute))") }
            if vm.morningEnabled   { parts.append("Morning check-in at \(vm.timeLabel(hour: vm.morningHour, minute: 0))") }
            if vm.eveningEnabled   { parts.append("Evening review at \(vm.timeLabel(hour: vm.eveningHour, minute: 0))") }
            return parts.isEmpty
                ? "No reminders active. Toggle one on to stay consistent."
                : "Active: " + parts.joined(separator: " · ")
        default:
            return "Enable reminders to stay on track with your goals."
        }
    }

    var body: some View {
        SettingsSection(title: "NOTIFICATIONS") {
            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.08) {
                VStack(spacing: 0) {

                    // ── Weekly Reflection ──────────────────────
                    SettingsRow(icon: "moon.stars", label: "Weekly Reflection") {
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
                        SettingsRow(icon: "calendar", label: "Day") {
                            Picker("", selection: $vm.reminderWeekday) {
                                Text("Sunday").tag(1)
                                Text("Monday").tag(2)
                                Text("Tuesday").tag(3)
                                Text("Wednesday").tag(4)
                                Text("Thursday").tag(5)
                                Text("Friday").tag(6)
                                Text("Saturday").tag(7)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(Color.lcPrimary)
                            .onChange(of: vm.reminderWeekday) { _, _ in vm.scheduleReflectionReminder() }
                        }
                        SettingsDivider()
                        SettingsRow(icon: "clock", label: "Time") {
                            DatePicker("", selection: reflectionTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Color.lcPrimary)
                        }
                    }

                    SettingsDivider()

                    // ── Morning Check-in ───────────────────────
                    SettingsRow(icon: "sun.horizon", label: "Morning Check-in") {
                        Toggle("", isOn: Binding(
                            get: { vm.morningEnabled },
                            set: { vm.toggleMorningReminder($0) }
                        ))
                        .labelsHidden()
                        .tint(Color.lcGold)
                        .disabled(vm.notificationStatus == .denied)
                    }

                    if vm.morningEnabled && vm.notificationStatus == .authorized {
                        SettingsDivider()
                        SettingsRow(icon: "clock", label: "Time") {
                            DatePicker("", selection: morningTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Color.lcGold)
                        }
                    }

                    SettingsDivider()

                    // ── Evening Review ─────────────────────────
                    SettingsRow(icon: "moon", label: "Evening Review") {
                        Toggle("", isOn: Binding(
                            get: { vm.eveningEnabled },
                            set: { vm.toggleEveningReminder($0) }
                        ))
                        .labelsHidden()
                        .tint(Color.lcLavender)
                        .disabled(vm.notificationStatus == .denied)
                    }

                    if vm.eveningEnabled && vm.notificationStatus == .authorized {
                        SettingsDivider()
                        SettingsRow(icon: "clock", label: "Time") {
                            DatePicker("", selection: eveningTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.compact)
                                .tint(Color.lcLavender)
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
// MARK: - Appearance Section
// ============================================================

private struct AppearanceSection: View {
    @ObservedObject var vm: SettingsViewModel

    var body: some View {
        SettingsSection(title: "APPEARANCE") {
            GlassCard(glowColor: .lcPrimary, glowOpacity: 0.08) {
                VStack(spacing: 0) {
                    SettingsRow(icon: "circle.lefthalf.filled", label: "Theme") {
                        Picker("", selection: $vm.appColorScheme) {
                            Text("Dark").tag(0)
                            Text("Light").tag(1)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 130)
                    }
                    SettingsDivider()
                    SettingsNote("Dark keeps the deep navy look. Light switches to a warm, airy palette.")
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

// PremiumView.swift
// Life Compass — Premium Upgrade Screen
//
// App Store compliant:
//   ✓ Clear one-time pricing
//   ✓ Restore Purchase
//   ✓ Privacy Policy link
//   ✓ Terms of Use (EULA) link
//   ✓ No misleading UI

import SwiftUI

// ============================================================
// MARK: - PremiumView
// ============================================================

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var access = FeatureAccessManager.shared

    @State private var showErrorAlert   = false
    @State private var showRestoreAlert = false
    @State private var restoreFound     = false
    @State private var heroPulsing      = false
    @State private var appeared         = false

    private let privacyURL = URL(string: "https://manhcuong5311-hue.github.io/serein-legal/")!
    private let termsURL   = URL(string: "https://manhcuong5311-hue.github.io/serein-legal/")!

    // Convenience shorthands
    private var isPurchasing: Bool {
        access.purchaseState == .loading || access.purchaseState == .purchasing
    }
    private var isRestoring: Bool { access.purchaseState == .restoring }

    private let features: [PremiumFeature] = [
        .init("infinity",              .lcPrimary,   "Unlimited Goals",       "Create as many goals as you need across every life area."),
        .init("calendar.badge.plus",   .lcLavender,  "Advanced Planning",     "Schedule steps for exact dates and plan weeks ahead."),
        .init("arrow.clockwise",       .lcGold,      "Daily Habits",          "Recurring steps that automatically reset each morning."),
        .init("tray.full",             .cyan,         "Smart Backlog",         "Keep anytime steps visible and organised per goal."),
        .init("sparkles",              .mint,         "AI Suggestions",        "Intelligent nudges to keep your goals moving forward (coming soon)."),
    ]

    var body: some View {
        ZStack {
            LCBackground(showNoise: true)
            ambientGlow

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    dragHandle
                    heroSection
                    Spacer(minLength: LCSpacing.xl)
                    featureList
                    Spacer(minLength: LCSpacing.xl)
                    ctaSection
                    Spacer(minLength: LCSpacing.lg)
                    legalFooter
                    Spacer(minLength: LCSpacing.xxl)
                }
                .padding(.horizontal, LCSpacing.md)
            }

            closeButton
        }

        .onAppear { withAnimation(.lcSoftAppear.delay(0.10)) { appeared = true } }
        // Auto-dismiss on successful purchase
        .onChange(of: access.purchaseState) { _, state in
            if case .success = state {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    access.clearPurchaseState()
                    dismiss()
                }
            }
            if case .failed = state {
                showErrorAlert = true
            }
        }
        .alert("Purchase Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { access.clearPurchaseState() }
        } message: {
            if case .failed(let msg) = access.purchaseState {
                Text(msg)
            } else {
                Text("Something went wrong. Please try again.")
            }
        }
        .alert(restoreFound ? "Purchase Restored" : "Nothing to Restore",
               isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreFound
                 ? "Your Premium access has been restored. Enjoy unlimited goals and advanced planning."
                 : "No previous purchase was found for this Apple ID. If you believe this is an error, contact support."
            )
        }
    }

    // ── Sub-views ────────────────────────────────────────────────

    private var ambientGlow: some View {
        RadialGradient(
            colors: [Color.lcPrimary.opacity(0.20), .clear],
            center: .top,
            startRadius: 0,
            endRadius: UIScreen.main.bounds.width * 1.4
        )
        .ignoresSafeArea()
    }

    private var dragHandle: some View {
        Capsule()
            .fill(Color.white.opacity(0.14))
            .frame(width: 36, height: 4)
            .padding(.top, LCSpacing.md)
            .padding(.bottom, LCSpacing.lg)
    }

    private var heroSection: some View {
        VStack(spacing: LCSpacing.sm) {
            // Pulsing icon
            ZStack {
                Circle()
                    .fill(Color.lcPrimary.opacity(0.14))
                    .frame(width: 90, height: 90)
                    .scaleEffect(heroPulsing ? 1.14 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                        value: heroPulsing
                    )

                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .ultraLight))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.lcPrimary, Color.lcLavender],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .onAppear { heroPulsing = true }
            .softAppear(delay: 0.06)

            Text("Unlock Your Full Potential")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.lcTextPrimary)
                .multilineTextAlignment(.center)
                .softAppear(delay: 0.10)

            Text("Build unlimited goals & smart plans\nthat keep you moving forward every day.")
                .font(LCFont.insight)
                .foregroundStyle(Color.lcTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .softAppear(delay: 0.14)
        }
    }

    private var featureList: some View {
        GlassCard(glowColor: .lcPrimary, glowOpacity: 0.10) {
            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.offset) { idx, feature in
                    HStack(alignment: .top, spacing: LCSpacing.sm) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(feature.color.opacity(0.14))
                            Image(systemName: feature.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(feature.color)
                        }
                        .frame(width: 38, height: 38)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.title)
                                .font(LCFont.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.lcTextPrimary)
                            Text(feature.description)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.lcTextSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(LCSpacing.md)
                    .softAppear(delay: 0.18 + Double(idx) * 0.06)

                    if idx < features.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.horizontal, LCSpacing.md)
                    }
                }
            }
        }
        .softAppear(delay: 0.16)
    }

    private var ctaSection: some View {
        VStack(spacing: LCSpacing.sm) {

            // Live price badge
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(access.displayPrice)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.lcTextPrimary)
                    .contentTransition(.numericText())

                VStack(alignment: .leading, spacing: 0) {
                    Text("one-time")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)
                    Text("purchase")
                        .font(LCFont.overline)
                        .foregroundStyle(Color.lcTextTertiary)
                }
            }
            .softAppear(delay: 0.40)

            // Purchase button — drives App Store sheet
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await access.purchase() }
            } label: {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isPurchasing ? "Processing…" : "Unlock Premium")
                        .fontWeight(.semibold)
                }
                .font(LCFont.body)
                .foregroundStyle(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, LCSpacing.lg)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.lcPrimary, Color.lcLavender],
                                startPoint: .topLeading,
                                endPoint:   .bottomTrailing
                            )
                            .opacity(0.85)
                        )
                        .shadow(color: Color.lcPrimary.opacity(0.35), radius: 18, x: 0, y: 8)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || isRestoring || access.isPremium)
            .softAppear(delay: 0.44)

            Text("Payment will be charged to your Apple ID at confirmation of purchase.")
                .font(.system(size: 11))
                .foregroundStyle(Color.lcTextTertiary.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, LCSpacing.xs)
                .softAppear(delay: 0.48)
        }
    }

    private var legalFooter: some View {
        VStack(spacing: LCSpacing.sm) {
            Divider().background(Color.white.opacity(0.06))

            // Restore Purchase
            Button {
                Task {
                    let found = await access.restorePurchase()
                    restoreFound     = found
                    showRestoreAlert = true
                    if found { UINotificationFeedbackGenerator().notificationOccurred(.success) }
                }
            } label: {
                HStack(spacing: 6) {
                    if isRestoring {
                        ProgressView()
                            .tint(Color.lcTextTertiary)
                            .scaleEffect(0.75)
                    }
                    Text(isRestoring ? "Restoring…" : "Restore Purchase")
                        .font(LCFont.insight)
                        .foregroundStyle(Color.lcTextSecondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(isRestoring || isPurchasing)

            // Privacy + Terms
            // Privacy + Terms + EULA
            HStack(spacing: LCSpacing.md) {
                Link("Privacy Policy", destination: privacyURL)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lcTextTertiary)

                Text("·")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lcTextTertiary.opacity(0.40))

                Link("Terms of Use", destination: termsURL)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lcTextTertiary)

                Text("·")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lcTextTertiary.opacity(0.40))

                Link("EULA", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.lcTextTertiary)
            }
        }
        .softAppear(delay: 0.52)
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(Color.white.opacity(0.22))
                }
                .buttonStyle(.plain)
                .padding(LCSpacing.md)
            }
            Spacer()
        }
    }

}

// ============================================================
// MARK: - PremiumFeature Model
// ============================================================

private struct PremiumFeature {
    let icon:        String
    let color:       Color
    let title:       String
    let description: String

    init(_ icon: String, _ color: Color, _ title: String, _ description: String) {
        self.icon        = icon
        self.color       = color
        self.title       = title
        self.description = description
    }
}

// ============================================================
// MARK: - Locked Feature Overlay
// ============================================================
// Reusable overlay for any locked feature. Tap → PremiumView sheet.

struct LockedFeatureOverlay: View {
    let label: String
    @State private var showPremium = false

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showPremium = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.lcGold)
                Text(label)
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcGold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.lcGold.opacity(0.12))
                    .overlay(Capsule().strokeBorder(Color.lcGold.opacity(0.28), lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPremium) {
            PremiumView()
                .presentationDragIndicator(.visible)
                .presentationDetents([.large])
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Premium") {
    PremiumView()
}

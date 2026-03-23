// FAQView.swift
// Serein — In-App FAQ
//
// Self-contained FAQ with collapsible Q&A rows.
// Opened as a sheet from Settings → Support.

import SwiftUI

// ============================================================
// MARK: - FAQ Model
// ============================================================

private struct FAQItem: Identifiable {
    let id   = UUID()
    let q: String
    let a: String
}

private struct FAQCategory: Identifiable {
    let id    = UUID()
    let title: String
    let icon:  String
    let color: Color
    let items: [FAQItem]
}

private let faqData: [FAQCategory] = [

    FAQCategory(
        title: "Getting Started",
        icon:  "sparkles",
        color: .lcPrimary,
        items: [
            FAQItem(
                q: "What is Serein?",
                a: "Serein is a life design app that helps you set goals across 6 life areas, plan daily actions, and build momentum through consistent steps. It's not a to-do list — it's a direction compass. You decide where you're going; Serein helps you move there one day at a time."
            ),
            FAQItem(
                q: "How do I set my first goal?",
                a: "Go to the Goals tab, tap \"+ New Goal\" in the top-right, choose a life area, give your goal a meaningful title, and write your reason why. You can also add a first milestone. Your goal appears immediately and is ready for steps."
            ),
            FAQItem(
                q: "What are the 6 life areas?",
                a: "Health, Career, Relationships, Mindfulness, Creativity, and Finances. Each area has its own XP level and progress ring. Your Dashboard shows all six so you can spot which areas need more attention."
            ),
            FAQItem(
                q: "What is XP and why does it matter?",
                a: "XP (Experience Points) tracks your real progress in each life area. Completing milestones awards XP, which raises your level. It's a motivational signal — not a game score. Higher levels mean you've consistently invested in that area of your life."
            ),
        ]
    ),

    FAQCategory(
        title: "Goals & Steps",
        icon:  "scope",
        color: Color(lcHex: "#6C7AA6"),
        items: [
            FAQItem(
                q: "What's the difference between a goal and a step?",
                a: "A goal is a meaningful outcome you're working toward — something that matters (e.g., \"Build a healthier lifestyle\"). A step is a single concrete action that moves you closer (e.g., \"Run 2 km this morning\"). Goals live for weeks or months; steps are what you actually do today."
            ),
            FAQItem(
                q: "What are the different step types?",
                a: "Today — appears in your Dashboard immediately, high priority.\n\nTomorrow — automatically becomes a Today step the next morning.\n\nScheduled — appears on a specific date you choose. Great for planned work.\n\nAnytime — sits in your backlog with no deadline, ready when you are.\n\nRecurring Daily — resets every morning. Perfect for habits and routines like meditation or exercise."
            ),
            FAQItem(
                q: "How do I edit or delete a goal?",
                a: "Long-press any goal card, or tap the \"...\" context menu to see options. You can edit the title and your reason why, or permanently delete the goal and all its steps. Deletion cannot be undone."
            ),
            FAQItem(
                q: "How do I pin a goal?",
                a: "Swipe right on a goal card to pin it. Pinned goals float to the top of your Goals tab so they stay in focus. Swipe right again to unpin."
            ),
            FAQItem(
                q: "What are milestones?",
                a: "Milestones are the key checkpoints inside a goal — the stages that tell you you're making real progress. When you complete a milestone, you earn XP and the goal's progress bar advances. They're like mini-victories on the way to a bigger win."
            ),
        ]
    ),

    FAQCategory(
        title: "Daily Planning",
        icon:  "sun.max",
        color: .lcGold,
        items: [
            FAQItem(
                q: "What does the Dashboard show?",
                a: "Your Dashboard is your daily command center. At the top, you'll see your Today steps (up to 5 from all your goals), followed by your Focus Goal, your 6 Life Area cards, Life Balance rings, a rotating Daily Insight, and a Future Self teaser. It's everything you need to stay intentional."
            ),
            FAQItem(
                q: "How do I complete a step?",
                a: "In the Dashboard's \"Today\" section, tap the circle on the left side of any step. It animates away, your XP updates, and your streak grows if this is your first completion today."
            ),
            FAQItem(
                q: "What is the streak counter?",
                a: "The flame icon in the top-right of your Dashboard tracks consecutive days where you completed at least one step. It resets if you miss a day. Streaks build discipline — treat yours like a signal of consistency, not a source of stress."
            ),
            FAQItem(
                q: "What is the Focus Goal?",
                a: "Serein automatically selects your most active pinned goal (or highest-priority active goal) as your daily focus. It appears as a highlighted card on the Dashboard. Tapping it opens the full Goal Detail view."
            ),
        ]
    ),

    FAQCategory(
        title: "Notifications",
        icon:  "bell",
        color: .lcLavender,
        items: [
            FAQItem(
                q: "What notifications does Serein send?",
                a: "You can enable three types of optional reminders:\n\n• Weekly Reflection — a nudge on a day and time you choose to review your week.\n\n• Morning Check-in — a daily prompt to set your intention for the day.\n\n• Evening Review — a daily reminder to acknowledge what you accomplished.\n\nAll are fully optional and customizable in Settings → Notifications."
            ),
            FAQItem(
                q: "Why isn't my notification appearing?",
                a: "First, check iOS Settings → Notifications → Serein and make sure notifications are allowed. Then open Serein → Settings → Notifications and confirm your reminders are toggled on. If the toggle is greyed out, your OS-level permission is blocked."
            ),
            FAQItem(
                q: "Can I change the notification time?",
                a: "Yes. In Settings → Notifications, expand any enabled reminder to see a time picker. For the Weekly Reflection, you can also change the day of the week. Changes take effect immediately."
            ),
        ]
    ),

    FAQCategory(
        title: "Premium",
        icon:  "sparkles",
        color: .lcGold,
        items: [
            FAQItem(
                q: "What does Premium include?",
                a: "Premium unlocks:\n\n• Unlimited goals across all 6 life areas (Free = 1 per area)\n• Scheduled steps — appear on a specific future date\n• Anytime steps — no deadline backlog\n• Recurring Daily steps — habit tracking that resets each morning\n\nIt's a one-time purchase of $9.99. No subscription. No recurring charge."
            ),
            FAQItem(
                q: "How do I restore a previous purchase?",
                a: "Go to Settings → Account → Restore Purchase. This checks your Apple ID for an existing purchase of Serein Premium. If found, your access is restored instantly. Make sure you're signed into the same Apple ID used for the original purchase."
            ),
            FAQItem(
                q: "Is there a free plan?",
                a: "Yes. The free plan is fully functional: 1 goal per life area, Today and Tomorrow step types, all Dashboard features, Life Balance rings, Daily Insights, and Weekly Reflections. Upgrade to Premium whenever you're ready to go deeper."
            ),
        ]
    ),

    FAQCategory(
        title: "Privacy & Data",
        icon:  "lock.shield",
        color: Color(lcHex: "#7DB6A0"),
        items: [
            FAQItem(
                q: "Does Serein collect or share my data?",
                a: "No. Serein stores all your data locally on your device using iOS standard storage. Nothing is sent to any server. Your goals, reflections, vision statements, and progress belong entirely to you."
            ),
            FAQItem(
                q: "How do I permanently delete all my data?",
                a: "Open Settings → Data → Reset All Data. This permanently clears your goals, reflections, future vision, daily activity, and settings. The action cannot be undone. Your app reverts to the sample state."
            ),
            FAQItem(
                q: "What happens if I delete the app?",
                a: "All locally stored data (goals, reflections, progress) will be deleted with the app since Serein does not use cloud backup. If you have Premium, you can restore your purchase after reinstalling by going to Settings → Account → Restore Purchase."
            ),
        ]
    ),
]

// ============================================================
// MARK: - FAQView
// ============================================================

struct FAQView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var expandedId: UUID? = nil

    var body: some View {
        ZStack {
            LCBackground(showNoise: true)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // ── Header ─────────────────────────────────
                    VStack(alignment: .leading, spacing: LCSpacing.xs) {
                        Capsule()
                            .fill(Color.lcTextTertiary.opacity(0.30))
                            .frame(width: 36, height: 4)
                            .frame(maxWidth: .infinity)
                            .padding(.top, LCSpacing.md)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("FAQ")
                                    .font(LCFont.overline)
                                    .foregroundStyle(Color.lcTextTertiary)
                                Text("Common Questions")
                                    .font(LCFont.header)
                                    .foregroundStyle(Color.lcTextPrimary)
                            }
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 26, weight: .light))
                                    .foregroundStyle(Color.lcTextTertiary.opacity(0.70))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, LCSpacing.md)
                    .padding(.bottom, LCSpacing.lg)

                    // ── Categories ─────────────────────────────
                    VStack(alignment: .leading, spacing: LCSpacing.lg) {
                        ForEach(faqData) { category in
                            FAQCategorySection(
                                category:   category,
                                expandedId: $expandedId
                            )
                        }
                    }
                    .padding(.horizontal, LCSpacing.md)
                    .padding(.bottom, LCSpacing.xxl)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Category Section
// ============================================================

private struct FAQCategorySection: View {
    let category:   FAQCategory
    @Binding var expandedId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.sm) {

            // Section label
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(category.color.opacity(0.80))
                Text(category.title.uppercased())
                    .font(LCFont.overline)
                    .foregroundStyle(Color.lcTextTertiary)
            }

            GlassCard(glowColor: category.color, glowOpacity: 0.08) {
                VStack(spacing: 0) {
                    ForEach(Array(category.items.enumerated()), id: \.element.id) { idx, item in
                        FAQRow(
                            item:       item,
                            accent:     category.color,
                            isExpanded: expandedId == item.id,
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.30)) {
                                    expandedId = expandedId == item.id ? nil : item.id
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        )
                        if idx < category.items.count - 1 {
                            Divider()
                                .padding(.horizontal, LCSpacing.md)
                        }
                    }
                }
            }
        }
    }
}

// ============================================================
// MARK: - FAQ Row
// ============================================================

private struct FAQRow: View {
    let item:       FAQItem
    let accent:     Color
    let isExpanded: Bool
    let onTap:      () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {

                // Question row
                HStack(alignment: .top, spacing: LCSpacing.sm) {
                    Image(systemName: isExpanded ? "minus" : "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accent.opacity(isExpanded ? 0.90 : 0.55))
                        .frame(width: 20, height: 20)
                        .padding(.top, 2)
                        .animation(.easeInOut(duration: 0.20), value: isExpanded)

                    Text(item.q)
                        .font(LCFont.body)
                        .fontWeight(isExpanded ? .semibold : .regular)
                        .foregroundStyle(isExpanded ? Color.lcTextPrimary : Color.lcTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(.easeInOut(duration: 0.20), value: isExpanded)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, LCSpacing.md)
                .padding(.vertical, 16)

                // Answer (expanded)
                if isExpanded {
                    Text(item.a)
                        .font(LCFont.insight)
                        .foregroundStyle(Color.lcTextSecondary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, LCSpacing.md)
                        .padding(.leading, 28)   // aligns under question text
                        .padding(.bottom, 18)
                        .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }
        }
        .buttonStyle(.plain)
        .background(
            isExpanded ? accent.opacity(0.05) : Color.clear
        )
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("FAQ") {
    FAQView()
        .environmentObject(AppState())
}

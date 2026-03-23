import SwiftUI

// MARK: - Subscription & Billing View
// A StoreKit 2-ready placeholder screen for subscription management.
// Currently displays plan information and premium features with "Coming soon" alerts.

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var billingPeriod: BillingPeriod = .monthly
    @State private var showComingSoonAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // ── Current Plan Section ────────────────────
                    currentPlanSection

                    // ── Premium Plan Card ────────────────────
                    premiumPlanCard

                    // ── Billing Period Picker ────────────────────
                    billingPeriodPicker

                    // ── Price Display ────────────────────
                    priceSection

                    // ── Upgrade & Restore Buttons ────────────────────
                    buttonSection

                    Spacer(minLength: Spacing.lg)
                }
                .padding(Spacing.lg)
            }
            .background(Color.adaptiveBackground.ignoresSafeArea())
            .navigationTitle("Subscription & Billing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsCloseButton {
                        dismiss()
                    }
                }
            }
        }
        .alert("Coming Soon", isPresented: $showComingSoonAlert) {
            Button("OK") { }
        } message: {
            Text("Premium features will be available in a future update.")
        }
    }

    // MARK: - Current Plan Section

    private var currentPlanSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Current Plan")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.oxfordGold)

                    Text("Free Plan")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    PlanFeatureRow(
                        icon: "globe",
                        text: "Browse all CEFR levels (A1–C2)"
                    )

                    PlanFeatureRow(
                        icon: "bookmark.fill",
                        text: "Bookmark and track learned words"
                    )

                    PlanFeatureRow(
                        icon: "speaker.wave.2.fill",
                        text: "Limited audio pronunciations"
                    )
                }
            }
            .padding(Spacing.md)
            .background(Color.adaptiveCardBackground)
            .cornerRadius(Spacing.md)
        }
    }

    // MARK: - Premium Plan Card

    private var premiumPlanCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Premium Plan")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.oxfordGold)

                    Text("Premium")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("Unlock All")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.webPrimary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs / 2)
                        .background(
                            Capsule()
                                .fill(Color.webPrimary.opacity(0.15))
                        )
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    PlanFeatureRow(
                        icon: "speaker.wave.3.fill",
                        text: "Unlimited audio pronunciations"
                    )

                    PlanFeatureRow(
                        icon: "chart.bar.fill",
                        text: "Advanced statistics & insights"
                    )

                    PlanFeatureRow(
                        icon: "star.fill",
                        text: "Priority support"
                    )

                    PlanFeatureRow(
                        icon: "arrow.down.circle.fill",
                        text: "Offline word lists"
                    )
                }
            }
            .padding(Spacing.md)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.webPrimary.opacity(0.08),
                        Color.adaptiveCardBackground
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(Spacing.md)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.md)
                    .stroke(Color.webPrimary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Billing Period Picker

    private var billingPeriodPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Billing Period")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Picker("Billing Period", selection: $billingPeriod) {
                Text("Monthly").tag(BillingPeriod.monthly)
                Text("Annual").tag(BillingPeriod.annual)
            }
            .pickerStyle(.segmented)
            .tint(.webPrimary)
        }
    }

    // MARK: - Price Section

    private var priceSection: some View {
        VStack(spacing: Spacing.sm) {
            Text("Price")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.md) {
                VStack(alignment: .center, spacing: Spacing.xs) {
                    Text(billingPeriod == .monthly ? "$4.99" : "$29.99")
                        .font(.title.weight(.bold))
                        .foregroundStyle(Color.webPrimary)

                    Text(billingPeriod == .monthly ? "per month" : "per year")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(Color.adaptiveCardBackground)
                .cornerRadius(Spacing.md)

                if billingPeriod == .annual {
                    VStack(alignment: .center, spacing: Spacing.xs) {
                        Text("Save")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.webPrimary)

                        Text("38%")
                            .font(.body.weight(.bold))
                            .foregroundStyle(Color.webPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.md)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.webPrimary.opacity(0.15),
                                Color.oxfordGold.opacity(0.08)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(Spacing.md)
                }
            }
        }
    }

    // MARK: - Button Section

    private var buttonSection: some View {
        VStack(spacing: Spacing.md) {
            // Upgrade Button
            Button(action: {
                showComingSoonAlert = true
            }) {
                HStack {
                    Spacer()
                    Text("Upgrade to Premium")
                        .font(.body.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(.white)
                .padding(Spacing.md)
                .background(
                    Capsule()
                        .fill(Color.webPrimary)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Upgrade to Premium")
            .accessibilityHint("Opens purchase options for premium subscription")

            // Restore Purchases Button
            Button(action: {
                showComingSoonAlert = true
            }) {
                HStack {
                    Spacer()
                    Text("Restore Purchases")
                        .font(.body.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(Color.webPrimary)
                .padding(Spacing.md)
                .background(
                    Capsule()
                        .stroke(Color.webPrimary.opacity(0.3), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restore Purchases")
            .accessibilityHint("Restores previously purchased subscriptions")
        }
    }
}

// MARK: - Plan Feature Row

struct PlanFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.webPrimary)
                .frame(width: 20, alignment: .center)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()
        }
    }
}

// MARK: - Billing Period Enum

enum BillingPeriod {
    case monthly
    case annual
}

// MARK: - Preview

#Preview {
    SubscriptionView()
}

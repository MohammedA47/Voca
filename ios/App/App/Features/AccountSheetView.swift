import SwiftUI

// MARK: - Account Sheet View
// Native iOS Settings-style screen presented as a sheet from the profile avatar.
// Uses push navigation for sub-pages and standard iOS controls throughout.

struct AccountSheetView: View {
    @Environment(\.dismiss) private var dismiss
    // MARK: - Persisted Settings
    @AppStorage("isLooping") private var isLooping: Bool = true
    @AppStorage("phoneticsMode") private var phoneticsMode: String = "us"
    @AppStorage("loopGapSeconds") private var loopGapSeconds: Double = 1.0
    @AppStorage("playbackSpeed") private var playbackSpeed: Double = 1.0
    @AppStorage("randomSpeedEnabled") private var randomSpeedEnabled: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"

    // Auth State
    private var authService = AuthService.shared
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            List {
                // ── Profile Row ──────────────────────────────
                profileSection

                // ── Preferences ──────────────────────────────
                preferencesSection

                // ── General ──────────────────────────────────
                generalSection

                // ── Sign Out & Delete ────────────────────────
                signOutSection
                deleteAccountSection

                // ── Footer ───────────────────────────────────
                footerSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsCloseButton {
                        dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(
            appearanceMode == "dark" ? .dark :
            appearanceMode == "light" ? .light : nil
        )
        .alert("Delete Account?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                isDeleting = true
                Task {
                    do {
                        try await authService.deleteAccount()
                        dismiss()
                    } catch {
                        print("Error deleting account: \(error)")
                        isDeleting = false
                    }
                }
            }
        } message: {
            Text("Are you sure? This will delete your account and all progress. This action cannot be undone.")
        }
    }

    // MARK: - Profile Section (Apple ID Style)

    @ViewBuilder
    private var profileSection: some View {
        Section {
            if authService.isAuthenticated {
                NavigationLink(destination: AccountSettingsView()) {
                    HStack(spacing: Spacing.sm + Spacing.xs) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(authService.currentUser?.email?.components(separatedBy: "@").first?.capitalized ?? "User")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text(authService.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
                .accessibilityLabel("Account settings")
                .accessibilityHint("Opens account details and security settings")
            } else {
                NavigationLink(destination: LoginSheetView()) {
                    HStack(spacing: Spacing.sm + Spacing.xs) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 44))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.gray)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sign In")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                            Text("Sign in to sync your progress")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
                .accessibilityLabel("Sign in")
                .accessibilityHint("Opens the sign-in page")
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        Section(header: Text("Settings")) {
            // ── Loop Words ────────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                SettingsIcon(systemName: "repeat", color: .green)

                Toggle(isOn: $isLooping) {
                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Loop Words")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Repeat list when finished")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            // ── Phonetics Mode ────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                SettingsIcon(
                    systemName: "character.phonetic",
                    color: .indigo
                )

                Picker(selection: $phoneticsMode) {
                    Text("US English").tag("us")
                    Text("UK English").tag("uk")
                } label: {
                    Text("Phonetics")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .pickerStyle(.menu)
            }
            .accessibilityElement(children: .combine)

            // ── Loop Gap ──────────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                SettingsIcon(systemName: "timer", color: .orange)

                VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                    Text("Loop Gap")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("\(loopGapSeconds, specifier: "%.1f")s between repeats")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Stepper("", value: $loopGapSeconds, in: 0...10, step: 0.5)
                    .labelsHidden()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loop gap \(loopGapSeconds, specifier: "%.1f") seconds")

            // ── Playback Speed ────────────────────────────
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm + Spacing.xs) {
                    SettingsIcon(systemName: "gauge.with.needle", color: .blue)

                    Text("Playback Speed")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(playbackSpeed, specifier: "%.1f")×")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.1)
                    .accessibilityLabel("Playback speed")
                    .accessibilityValue("\(playbackSpeed, specifier: "%.1f") times")
            }
            .padding(.vertical, Spacing.xs)

            // ── Random Speed ──────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                SettingsIcon(systemName: "dice", color: .purple)

                Toggle(isOn: $randomSpeedEnabled) {
                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Random Speed")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Vary playback speed randomly")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            // ── Appearance ────────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                SettingsIcon(
                    systemName: appearanceMode == "dark" ? "moon.fill" : "sun.max.fill",
                    color: appearanceMode == "dark" ? .indigo : .yellow
                )

                Picker(selection: $appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                } label: {
                    Text("Appearance")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .pickerStyle(.menu)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section {
            // ── Notifications (push navigation) ──────────
            NavigationLink(destination: NotificationsSettingsView()) {
                SettingsRow(
                    icon: "bell.badge.fill",
                    iconColor: .red,
                    title: "Notifications"
                )
            }

            // ── Subscription (sheet) ─────────────────────
            NavigationLink(destination: AppSubscriptionView()) {
                SettingsRow(
                    icon: "creditcard.fill",
                    iconColor: .green,
                    title: "Subscription & Billing"
                )
            }
            .accessibilityLabel("Subscription & Billing")
            .accessibilityHint("Opens subscription and billing settings")

            // ── Help & Support (push navigation) ─────────
            NavigationLink(destination: HelpSupportView()) {
                SettingsRow(
                    icon: "questionmark.circle.fill",
                    iconColor: .purple,
                    title: "Help & Support"
                )
            }
            .accessibilityLabel("Help & Support")
        }
    }

    // MARK: - Sign Out Section

    @ViewBuilder
    private var signOutSection: some View {
        if authService.isAuthenticated {
            Section {
                Button(action: {
                    authService.logout()
                }) {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
                .accessibilityLabel("Sign out")
                .accessibilityHint("Signs you out of your account")
            }
        }
    }

    // MARK: - Delete Account Section

    @ViewBuilder
    private var deleteAccountSection: some View {
        if authService.isAuthenticated {
            Section {
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    HStack {
                        Spacer()
                        Text("Delete Account")
                            .font(.body)
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
                .accessibilityLabel("Delete Account")
                .accessibilityHint("Permanently delete your account and all data")
            }
        }
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        Section {
            EmptyView()
        } footer: {
            Text("Oxford Pronunciation v\(appVersion) (\(appBuild))")
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Settings Row
// Reusable row component for settings list items with colored icon.
// When used inside NavigationLink, omit showChevron (NavigationLink provides its own).
// When used inside Button, set showChevron: true for manual chevron.

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    var showChevron: Bool = false

    var body: some View {
        HStack(spacing: Spacing.sm + Spacing.xs) {
            SettingsIcon(systemName: icon, color: iconColor)

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Account Menu Item (Legacy Compatibility)

struct AccountMenuItem: View {
    let icon: String
    let iconColor: Color
    let title: String

    var body: some View {
        SettingsRow(icon: icon, iconColor: iconColor, title: title)
    }
}

// MARK: - Settings Icon
// Small rounded-rect icon matching Apple Settings style.

struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color)
            )
    }
}

// MARK: - Navigation Button Components
// Neutral circular buttons that match Apple's settings sheet chrome.

struct SettingsToolbarCircleButton: View {
    @Environment(\.isEnabled) private var isEnabled

    let systemName: String
    let accessibilityLabel: String
    var iconSize: CGFloat = 17
    var weight: Font.Weight = .semibold
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .opacity(isEnabled ? 1 : 0.65)
        .accessibilityLabel(accessibilityLabel)
    }

    private var iconColor: Color {
        Color.primary.opacity(isEnabled ? 0.88 : 0.35)
    }
}

struct SettingsCloseButton: View {
    let action: () -> Void

    var body: some View {
        SettingsToolbarCircleButton(
            systemName: "xmark",
            accessibilityLabel: "Close",
            iconSize: 16,
            weight: .medium,
            action: action
        )
    }
}

struct SettingsBackButton: View {
    let action: () -> Void

    var body: some View {
        SettingsToolbarCircleButton(
            systemName: "chevron.left",
            accessibilityLabel: "Back",
            iconSize: 18,
            weight: .semibold,
            action: action
        )
    }
}

// MARK: - App Subscription View
// Kept local to the settings target so it participates in the same push navigation flow.

private struct AppSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ContentUnavailableView(
            "Subscriptions",
            systemImage: "creditcard",
            description: Text("Subscription management is not available yet.")
        )
        .navigationTitle("Subscription & Billing")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AccountSheetView()
}

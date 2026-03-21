import SwiftUI

// MARK: - Account Sheet View
// A native iOS bottom sheet presented when tapping the profile avatar.
// Designed to match Apple Music / App Store account panel style.

struct AccountSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Persisted Settings
    @AppStorage("isLooping") private var isLooping: Bool = true
    @AppStorage("phoneticsMode") private var phoneticsMode: String = "us"
    @AppStorage("loopGapSeconds") private var loopGapSeconds: Double = 1.0
    @AppStorage("playbackSpeed") private var playbackSpeed: Double = 1.0
    @AppStorage("randomSpeedEnabled") private var randomSpeedEnabled: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    
    // Auth State
    private var authService = AuthService.shared
    @State private var showingLoginSheet = false
    @State private var showingEditProfile = false
    @State private var showingNotificationsSheet = false
    @State private var showingSubscriptionView = false
    @State private var showingAccountSettings = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    var body: some View {
        NavigationStack {
            List {
                // ── Profile Header ────────────────────────────
                profileHeaderSection
                
                // ── Menu Items ────────────────────────────────
                accountSection
                preferencesSection
                supportSection
                signOutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.webPrimary)
                }
            }
        }
        .preferredColorScheme(
            appearanceMode == "dark" ? .dark :
            appearanceMode == "light" ? .light : nil
        )
        .sheet(isPresented: $showingLoginSheet) {
            LoginSheetView()
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingNotificationsSheet) {
            NotificationsSettingsView()
        }
        .sheet(isPresented: $showingSubscriptionView) {
            SubscriptionView()
        }
        .sheet(isPresented: $showingAccountSettings) {
            AccountSettingsView()
        }
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
    
    // MARK: - Profile Header
    
    private var profileHeaderSection: some View {
        Section {
            VStack(spacing: Spacing.sm + Spacing.xs) {
                // Avatar
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 72))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.webPrimary)
                    .accessibilityLabel("Profile avatar")
                
                if authService.isAuthenticated {
                    // Name
                    Text(authService.currentUser?.email?.components(separatedBy: "@").first?.capitalized ?? "User")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    
                    // Email
                    Text(authService.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Edit Profile Button
                    Button(action: {
                        showingEditProfile = true
                    }) {
                        Text("Edit Profile")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.webPrimary)
                            .padding(.horizontal, Spacing.md + Spacing.xs)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(Color.webPrimary.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit profile")
                    .accessibilityHint("Opens profile editing screen")
                } else {
                    Text("Guest User")
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    
                    Text("Sign in to sync your progress")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Log In Button
                    Button(action: {
                        showingLoginSheet = true
                    }) {
                        Text("Log In / Sign Up")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Spacing.lg)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                Capsule()
                                    .fill(Color.webPrimary)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Spacing.xs)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm + Spacing.xs)
            .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            Button(action: {
                showingAccountSettings = true
            }) {
                HStack(spacing: Spacing.sm + Spacing.xs) {
                    // Icon with rounded-rect background (Apple Settings style)
                    Image(systemName: "person.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.blue)
                        )

                    Text("Account")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Account")
            .accessibilityHint("Opens account settings")

            Button(action: {
                showingSubscriptionView = true
            }) {
                HStack(spacing: Spacing.sm + Spacing.xs) {
                    // Icon with rounded-rect background (Apple Settings style)
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.green)
                        )

                    Text("Subscription & Billing")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Subscription & Billing")
            .accessibilityHint("Opens subscription and billing settings")

            if authService.isAuthenticated {
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    HStack(spacing: Spacing.sm + Spacing.xs) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.red)
                            )

                        Text("Delete Account")
                            .font(.body)
                            .foregroundStyle(.red)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete Account")
                .accessibilityHint("Permanently delete your account and all data")
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
                .tint(.webPrimary)
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
                .tint(.webPrimary)
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
                        .foregroundStyle(Color.webPrimary)
                }
                
                Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.1)
                    .tint(.webPrimary)
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
                .tint(.webPrimary)
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
                .tint(.webPrimary)
            }
            .accessibilityElement(children: .combine)
            
            // ── Notifications ──────────────────────────────
            Button(action: {
                showingNotificationsSheet = true
            }) {
                AccountMenuItem(
                    icon: "bell.badge.fill",
                    iconColor: .red,
                    title: "Notifications"
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        Section {
            NavigationLink(destination: HelpSupportView()) {
                HStack(spacing: Spacing.sm + Spacing.xs) {
                    // Icon with rounded-rect background (Apple Settings style)
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.purple)
                        )

                    Text("Help & Support")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary.opacity(0.5))
                }
                .contentShape(Rectangle()) // Full-row tap target (44pt+)
            }
            .accessibilityLabel("Help & Support")
            .accessibilityAddTraits(.isButton)
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
}

// MARK: - Account Menu Item
// Reusable row component matching Apple's settings-style list items.

struct AccountMenuItem: View {
    let icon: String
    let iconColor: Color
    let title: String
    
    var body: some View {
        HStack(spacing: Spacing.sm + Spacing.xs) {
            // Icon with rounded-rect background (Apple Settings style)
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor)
                )
            
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .contentShape(Rectangle()) // Full-row tap target (44pt+)
    }
}

// MARK: - Settings Icon
// Small rounded-rect icon matching Apple Settings style, for use in custom rows.

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

// MARK: - Subscription View

private struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Subscriptions",
                systemImage: "creditcard",
                description: Text("Subscription management is not available yet.")
            )
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.webPrimary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    AccountSheetView()
}

import SwiftUI

// MARK: - Account Sheet View
// A native iOS bottom sheet presented when tapping the profile avatar.
// Designed to match Apple Music / App Store account panel style.

struct AccountSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Persisted Settings
    @AppStorage("loopGapSeconds") private var loopGapSeconds: Double = 1.0
    @AppStorage("playbackSpeed") private var playbackSpeed: Double = 1.0
    @AppStorage("randomSpeedEnabled") private var randomSpeedEnabled: Bool = false
    @AppStorage("appearanceMode") private var appearanceMode: String = "system"
    
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
                    .foregroundColor(.webPrimary)
                }
            }
        }
        .preferredColorScheme(
            appearanceMode == "dark" ? .dark :
            appearanceMode == "light" ? .light : nil
        )
    }
    
    // MARK: - Profile Header
    
    private var profileHeaderSection: some View {
        Section {
            VStack(spacing: 12) {
                // Avatar
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 72))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.webPrimary)
                    .accessibilityLabel("Profile avatar")
                
                // Name
                Text("User Name")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                
                // Email
                Text("user@example.com")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Edit Profile Button
                Button(action: {
                    // TODO: Navigate to edit profile
                }) {
                    Text("Edit Profile")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.webPrimary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.webPrimary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit profile")
                .accessibilityHint("Opens profile editing screen")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Account Section
    
    private var accountSection: some View {
        Section {
            AccountMenuItem(
                icon: "person.fill",
                iconColor: .blue,
                title: "Account"
            )
            
            AccountMenuItem(
                icon: "creditcard.fill",
                iconColor: .green,
                title: "Subscription & Billing"
            )
        }
    }
    
    // MARK: - Preferences Section
    
    private var preferencesSection: some View {
        Section(header: Text("Settings")) {
            // ── Loop Gap ──────────────────────────────────
            HStack(spacing: 14) {
                SettingsIcon(systemName: "timer", color: .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loop Gap")
                        .font(.body)
                        .foregroundColor(.primary)
                    Text("\(loopGapSeconds, specifier: "%.1f")s between repeats")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Stepper("", value: $loopGapSeconds, in: 0...10, step: 0.5)
                    .labelsHidden()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loop gap \(loopGapSeconds, specifier: "%.1f") seconds")
            
            // ── Playback Speed ────────────────────────────
            VStack(spacing: 8) {
                HStack(spacing: 14) {
                    SettingsIcon(systemName: "gauge.with.needle", color: .blue)
                    
                    Text("Playback Speed")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(playbackSpeed, specifier: "%.1f")×")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundColor(.webPrimary)
                }
                
                Slider(value: $playbackSpeed, in: 0.5...2.0, step: 0.1)
                    .tint(.webPrimary)
                    .accessibilityLabel("Playback speed")
                    .accessibilityValue("\(playbackSpeed, specifier: "%.1f") times")
            }
            .padding(.vertical, 4)
            
            // ── Random Speed ──────────────────────────────
            HStack(spacing: 14) {
                SettingsIcon(systemName: "dice", color: .purple)
                
                Toggle(isOn: $randomSpeedEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Random Speed")
                            .font(.body)
                            .foregroundColor(.primary)
                        Text("Vary playback speed randomly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.webPrimary)
            }
            .accessibilityElement(children: .combine)
            
            // ── Appearance ────────────────────────────────
            HStack(spacing: 14) {
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
                        .foregroundColor(.primary)
                }
                .pickerStyle(.menu)
                .tint(.webPrimary)
            }
            .accessibilityElement(children: .combine)
            
            // ── Notifications (existing) ──────────────────
            AccountMenuItem(
                icon: "bell.badge.fill",
                iconColor: .red,
                title: "Notifications"
            )
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        Section {
            AccountMenuItem(
                icon: "questionmark.circle.fill",
                iconColor: .purple,
                title: "Help & Support"
            )
        }
    }
    
    // MARK: - Sign Out Section
    
    private var signOutSection: some View {
        Section {
            Button(action: {
                // TODO: Handle sign out
            }) {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .font(.body.weight(.medium))
                        .foregroundColor(.red)
                    Spacer()
                }
            }
            .accessibilityLabel("Sign out")
            .accessibilityHint("Signs you out of your account")
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
        Button(action: {
            // TODO: Handle navigation
        }) {
            HStack(spacing: 14) {
                // Icon with rounded-rect background (Apple Settings style)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(iconColor)
                    )
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .contentShape(Rectangle()) // Full-row tap target (44pt+)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
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
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color)
            )
    }
}

// MARK: - Preview

#Preview {
    AccountSheetView()
}

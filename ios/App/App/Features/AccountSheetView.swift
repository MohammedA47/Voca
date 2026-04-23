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

    // Theme
    @State private var themeManager = ThemeManager.shared
    @State private var selectedPhoneticsMode = UserDefaults.standard.string(forKey: "phoneticsMode") ?? "us"
    @State private var selectedAppearanceMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
    @State private var selectedAccentTheme = ThemeManager.shared.accent

    // Auth State
    private var authService = AuthService.shared
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            List {
                // ── Profile Row ──────────────────────────────
                profileSection

                // ── Learning ─────────────────────────────────
                learningSection

                // ── Appearance ───────────────────────────────
                appearanceSection

                // ── App ──────────────────────────────────────
                appSection

                // ── Support ──────────────────────────────────
                supportSection

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
        .onAppear {
            syncDraftSelections()
        }
        .onChange(of: phoneticsMode) { _, newValue in
            if selectedPhoneticsMode != newValue {
                selectedPhoneticsMode = newValue
            }
        }
        .onChange(of: appearanceMode) { _, newValue in
            if selectedAppearanceMode != newValue {
                selectedAppearanceMode = newValue
            }
        }
        .onChange(of: themeManager.accent) { _, newValue in
            if selectedAccentTheme != newValue {
                selectedAccentTheme = newValue
            }
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
            } else if authService.isPendingConfirmation {
                NavigationLink(destination: ConfirmationStatusView()) {
                    HStack(spacing: Spacing.sm + Spacing.xs) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 40))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.orange)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Confirm Your Email")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)

                            if let deadline = authService.graceDeadline {
                                Text(timeRemainingText(until: deadline))
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }

                            Text(authService.pendingConfirmationEmail ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, Spacing.xs)
                }
                .accessibilityLabel("Confirm your email")
                .accessibilityHint("Opens email confirmation status")
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

    // MARK: - Learning Section

    private var learningSection: some View {
        Section(header: Text("Learning")) {
            // ── Phonetics Mode ────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                SettingsIcon(
                    systemName: "character.phonetic",
                    color: .indigo
                )

                Picker(selection: Binding(
                    get: { selectedPhoneticsMode },
                    set: applyPhoneticsSelection
                )) {
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

            // ── Loop Gap ──────────────────────────────────
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm + Spacing.xs) {
                    SettingsIcon(systemName: "timer", color: .orange)

                    VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                        Text("Loop Gap")
                            .font(.body)
                            .foregroundStyle(.primary)
                        Text("Time between repeats")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("\(loopGapSeconds, specifier: "%.1f")s")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(.secondary)
                }

                Slider(value: $loopGapSeconds, in: 0...10)
                    .accessibilityLabel("Loop gap")
                    .accessibilityValue("\(loopGapSeconds, specifier: "%.1f") seconds")
            }
            .padding(.vertical, Spacing.xs)

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

                Slider(value: $playbackSpeed, in: 0.5...2.0)
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
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {

            // ── Appearance ────────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                SettingsIcon(
                    systemName: selectedAppearanceMode == "dark" ? "moon.fill" : "sun.max.fill",
                    color: selectedAppearanceMode == "dark" ? .indigo : .yellow
                )

                Picker(selection: Binding(
                    get: { selectedAppearanceMode },
                    set: applyAppearanceSelection
                )) {
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

            // ── Accent Color ──────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                SettingsIcon(
                    systemName: "paintpalette.fill",
                    color: selectedAccentTheme.swatch
                )

                Picker(
                    selection: Binding(
                        get: { selectedAccentTheme },
                        set: applyAccentSelection
                    )
                ) {
                    ForEach(AccentTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                } label: {
                    Text("Accent Color")
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                .pickerStyle(.menu)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        Section(header: Text("App")) {
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
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section(header: Text("Support")) {
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
        if authService.isAuthenticated || authService.isPendingConfirmation {
            Section {
                Button(action: {
                    authService.logout()
                    dismiss()
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
            Text("Voca v\(appVersion) (\(appBuild))")
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

    private func syncDraftSelections() {
        selectedPhoneticsMode = phoneticsMode
        selectedAppearanceMode = appearanceMode
        selectedAccentTheme = themeManager.accent
    }

    private func applyPhoneticsSelection(_ newValue: String) {
        selectedPhoneticsMode = newValue
        Task { @MainActor in
            await Task.yield()
            if phoneticsMode != newValue {
                phoneticsMode = newValue
            }
        }
    }

    private func applyAppearanceSelection(_ newValue: String) {
        selectedAppearanceMode = newValue
        Task { @MainActor in
            await Task.yield()
            if appearanceMode != newValue {
                appearanceMode = newValue
            }
        }
    }

    private func applyAccentSelection(_ newValue: AccentTheme) {
        selectedAccentTheme = newValue
        Task { @MainActor in
            await Task.yield()
            if themeManager.accent != newValue {
                themeManager.accent = newValue
            }
        }
    }

    private func timeRemainingText(until deadline: Date) -> String {
        let remaining = deadline.timeIntervalSince(Date())
        if remaining <= 0 { return "Grace period expired" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left to confirm"
        }
        return "\(minutes)m left to confirm"
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

// MARK: - Confirmation Status View
// Pushed from the profile row when the user has a pending email confirmation.
// Shows the confirmation email, a live countdown, and resend / sign-in actions.

struct ConfirmationStatusView: View {
    @Environment(\.dismiss) private var dismiss
    private var authService = AuthService.shared

    @State private var resendLoading = false
    @State private var resendSuccess = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.orange)
                        .padding(.bottom, Spacing.xs)

                    Text("Check Your Email")
                        .font(.title2.bold())

                    if let email = authService.pendingConfirmationEmail {
                        Text("We sent a confirmation email to **\(email)**. You can use the app while you confirm.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, Spacing.xl)

                // Countdown
                if let deadline = authService.graceDeadline {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(deadline.timeIntervalSince(context.date), 0)
                        let hours = Int(remaining) / 3600
                        let minutes = (Int(remaining) % 3600) / 60
                        let seconds = Int(remaining) % 60

                        VStack(spacing: Spacing.sm) {
                            Text("Time remaining")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(String(format: "%02d:%02d:%02d", hours, minutes, seconds))
                                .font(.system(size: 40, weight: .bold, design: .monospaced))
                                .foregroundStyle(remaining < 3600 ? .red : .orange)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                }

                // Actions
                VStack(spacing: Spacing.md) {
                    // Already confirmed? Sign in
                    NavigationLink(destination: LoginSheetView()) {
                        HStack {
                            Spacer()
                            Text("I've Confirmed — Sign In")
                                .font(.headline)
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.webPrimary)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    // Resend
                    Button(action: {
                        Task { await resendEmail() }
                    }) {
                        HStack {
                            Spacer()
                            if resendLoading {
                                ProgressView()
                            } else if resendSuccess {
                                Label("Email Sent", systemImage: "checkmark")
                                    .font(.subheadline.weight(.medium))
                            } else {
                                Text("Resend Confirmation Email")
                                    .font(.subheadline.weight(.medium))
                            }
                            Spacer()
                        }
                        .foregroundStyle(Color.webPrimary)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .disabled(resendLoading || resendSuccess)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton { dismiss() }
            }
        }
    }

    private func resendEmail() async {
        resendLoading = true
        defer { resendLoading = false }
        do {
            try await authService.resendConfirmationEmail()
            resendSuccess = true
        } catch {}
    }
}

// MARK: - Preview

#Preview {
    AccountSheetView()
}

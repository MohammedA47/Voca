import SwiftUI

// MARK: - Account Settings View
// Displays user account information and security settings.
// Pushed via NavigationLink from AccountSheetView — inherits parent NavigationStack.

struct AccountSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // Auth state
    private var authService = AuthService.shared

    // Password change state
    @State private var showPasswordForm = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isChangingPassword = false
    @State private var passwordChangeError: String?
    @State private var passwordChangeSuccess = false

    var body: some View {
        List {
            // ── Account Info Section ────────────────────────────
            accountInfoSection

            // ── Profile Section ─────────────────────────────────
            profileSection

            // ── Security Section ────────────────────────────────
            securitySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Account")
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

    // MARK: - Account Info Section

    private var accountInfoSection: some View {
        Section(header: Text("Account Info")) {
            HStack {
                Text("Email")
                    .font(.body)
                Spacer()
                Text(authService.currentUser?.email ?? "—")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Member Since")
                    .font(.body)
                Spacer()
                Text("Since you signed up")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Account Type")
                    .font(.body)
                Spacer()
                Text("Email & Password")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        Section {
            NavigationLink(destination: EditProfileView()) {
                SettingsRow(
                    icon: "person.fill",
                    iconColor: .blue,
                    title: "Edit Profile"
                )
            }
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        Section(header: Text("Security")) {
            if !showPasswordForm {
                Button(action: {
                    showPasswordForm = true
                    passwordChangeError = nil
                    passwordChangeSuccess = false
                }) {
                    SettingsRow(
                        icon: "lock.fill",
                        iconColor: .blue,
                        title: "Change Password",
                        showChevron: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change Password")
            } else {
                // ── Password Change Form ──────────────────────────
                passwordChangeForm
            }
        }
    }

    // MARK: - Password Change Form

    @ViewBuilder
    private var passwordChangeForm: some View {
        // Error Message
        if let error = passwordChangeError {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                Spacer()
            }
        }

        // Success Message
        if passwordChangeSuccess {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Password changed successfully")
                    .font(.caption)
                    .foregroundStyle(.green)
                Spacer()
            }
        }

        // Current Password
        SecureField("Current Password", text: $currentPassword)
            .textContentType(.password)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

        // New Password
        SecureField("New Password", text: $newPassword)
            .textContentType(.newPassword)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

        // Confirm Password
        SecureField("Confirm New Password", text: $confirmPassword)
            .textContentType(.newPassword)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)

        // Validation Info
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: newPassword.count >= 6 ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(newPassword.count >= 6 ? .green : .secondary)
                Text("At least 6 characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Spacing.xs) {
                Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(passwordsMatch ? .green : .secondary)
                Text("Passwords match")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        // Action Buttons
        HStack(spacing: Spacing.sm) {
            Button(action: {
                resetForm()
            }) {
                Text("Cancel")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.sm)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
            }
            .disabled(isChangingPassword)

            Button(action: {
                changePassword()
            }) {
                if isChangingPassword {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save")
                        .font(.body.weight(.medium))
                }
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .padding(Spacing.sm)
            .background(Color.accentColor)
            .cornerRadius(8)
            .disabled(!isFormValid || isChangingPassword)
        }
    }

    // MARK: - Helper Methods

    private var passwordsMatch: Bool {
        newPassword == confirmPassword && !newPassword.isEmpty
    }

    private var isFormValid: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= 6 &&
        passwordsMatch
    }

    private func resetForm() {
        showPasswordForm = false
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        passwordChangeError = nil
        passwordChangeSuccess = false
    }

    private func changePassword() {
        isChangingPassword = true
        passwordChangeError = nil
        passwordChangeSuccess = false

        Task {
            do {
                try await authService.updatePassword(newPassword: newPassword)

                // Success
                await MainActor.run {
                    passwordChangeSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        resetForm()
                    }
                }
            } catch {
                await MainActor.run {
                    passwordChangeError = error.localizedDescription
                    isChangingPassword = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AccountSettingsView()
    }
}

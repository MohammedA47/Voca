import SwiftUI

// MARK: - Account Settings View
// Displays user account information and security settings.
// Allows users to change their password via inline form.

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
        NavigationStack {
            List {
                // ── Account Info Section ────────────────────────────
                accountInfoSection

                // ── Security Section ────────────────────────────────
                securitySection
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
    }

    // MARK: - Account Info Section

    private var accountInfoSection: some View {
        Section(header: Text("Account Info")) {
            // ── Email Address ────────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                    Text("Email Address")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(authService.currentUser?.email ?? "—")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // ── Member Since ────────────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                    Text("Member Since")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("Since you signed up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // ── Account Type ────────────────────────────────────
            HStack(spacing: Spacing.sm + Spacing.xs) {
                VStack(alignment: .leading, spacing: Spacing.xs / 2) {
                    Text("Account Type")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text("Email & Password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
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
                    HStack(spacing: Spacing.sm + Spacing.xs) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.blue)
                            )

                        Text("Change Password")
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
                .accessibilityLabel("Change Password")
            } else {
                // ── Password Change Form ──────────────────────────
                passwordChangeForm
            }
        }
    }

    // MARK: - Password Change Form

    private var passwordChangeForm: some View {
        VStack(spacing: Spacing.md) {
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
                .padding(Spacing.sm)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
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
                .padding(Spacing.sm)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            // Current Password Field
            SecureField("Current Password", text: $currentPassword)
                .textContentType(.password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(Spacing.sm)
                .background(Color.adaptiveCardBackground)
                .cornerRadius(8)
                .border(Color.secondary.opacity(0.3), width: 1)

            // New Password Field
            SecureField("New Password", text: $newPassword)
                .textContentType(.newPassword)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(Spacing.sm)
                .background(Color.adaptiveCardBackground)
                .cornerRadius(8)
                .border(Color.secondary.opacity(0.3), width: 1)

            // Confirm Password Field
            SecureField("Confirm New Password", text: $confirmPassword)
                .textContentType(.newPassword)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(Spacing.sm)
                .background(Color.adaptiveCardBackground)
                .cornerRadius(8)
                .border(Color.secondary.opacity(0.3), width: 1)

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
            .padding(.vertical, Spacing.xs)

            // Action Buttons
            HStack(spacing: Spacing.sm) {
                Button(action: {
                    resetForm()
                }) {
                    Text("Cancel")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color.webPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(Spacing.sm)
                        .background(Color.webPrimary.opacity(0.1))
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
                .background(Color.webPrimary)
                .cornerRadius(8)
                .disabled(!isFormValid || isChangingPassword)
            }
        }
        .padding(Spacing.md)
        .background(Color.adaptiveBackground)
        .cornerRadius(8)
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
        guard let sessionToken = authService.sessionToken else {
            passwordChangeError = "No active session"
            return
        }

        isChangingPassword = true
        passwordChangeError = nil
        passwordChangeSuccess = false

        Task {
            do {
                // Call Supabase PUT /auth/v1/user endpoint
                guard let url = URL(string: "https://brknoeqgpejhxsqsjnan.supabase.co/auth/v1/user") else {
                    throw URLError(.badURL)
                }

                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let body: [String: String] = ["password": newPassword]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }

                if !(200...299).contains(httpResponse.statusCode) {
                    let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("Password change failed with status \(httpResponse.statusCode): \(errorBody)")

                    if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let msg = errorDict["msg"] as? String {
                        throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
                    }
                    throw URLError(.badServerResponse)
                }

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
    AccountSettingsView()
}

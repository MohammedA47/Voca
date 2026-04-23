import SwiftUI

struct SetNewPasswordView: View {
    private var authService = AuthService.shared

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.adaptiveBackground, Color.adaptiveBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        header
                        formCard
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.xl)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        authService.finishPasswordRecovery()
                    }
                    .foregroundStyle(Color.accentPrimary)
                    .disabled(isLoading)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "key.horizontal.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentPrimary)

            Text("Set New Password")
                .font(.title2.bold())
                .foregroundStyle(Color.appForeground)

            Text("Choose a new password to finish your recovery flow.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Spacing.md)
    }

    private var formCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if let errorMessage {
                    statusRow(text: errorMessage, systemImage: "exclamationmark.circle.fill", color: .red)
                }

                if let successMessage {
                    statusRow(text: successMessage, systemImage: "checkmark.circle.fill", color: .green)
                }

                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.adaptiveCardBackground)
                    .clipShape(.rect(cornerRadius: 14))

                SecureField("Confirm New Password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.adaptiveCardBackground)
                    .clipShape(.rect(cornerRadius: 14))

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    validationRow(
                        isValid: newPassword.count >= 6,
                        text: "At least 6 characters"
                    )
                    validationRow(
                        isValid: passwordsMatch,
                        text: "Passwords match"
                    )
                }

                Button {
                    Task {
                        await submit()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Update Password")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.primary)
                .disabled(isLoading || !isFormValid)
                .opacity((isLoading || !isFormValid) ? 0.6 : 1.0)

                if successMessage != nil {
                    Button("Continue") {
                        authService.finishPasswordRecovery()
                    }
                    .buttonStyle(.secondary)
                }
            }
        }
    }

    private var passwordsMatch: Bool {
        !newPassword.isEmpty && newPassword == confirmPassword
    }

    private var isFormValid: Bool {
        newPassword.count >= 6 && passwordsMatch
    }

    private func statusRow(text: String, systemImage: String, color: Color) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
            Spacer()
        }
    }

    private func validationRow(isValid: Bool, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isValid ? .green : .secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    @MainActor
    private func submit() async {
        guard isFormValid else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil

        do {
            try await authService.updatePassword(newPassword: newPassword)
            successMessage = "Password updated. You can continue into the app."
            newPassword = ""
            confirmPassword = ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    SetNewPasswordView()
}

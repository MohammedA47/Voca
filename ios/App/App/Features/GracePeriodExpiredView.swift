import SwiftUI

/// Blocking full-screen view shown when the 48-hour email confirmation
/// grace period has expired. The user must confirm their email (and sign in)
/// before they can continue using the app.
struct GracePeriodExpiredView: View {
    private var authService = AuthService.shared

    @State private var resendLoading = false
    @State private var resendSuccess = false
    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                Spacer()

                // Icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)

                // Title & Description
                VStack(spacing: Spacing.sm) {
                    Text("Email Confirmation Required")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("Your 48-hour grace period has expired. Please confirm your email and sign in to continue. If your account was deleted, you can create a new one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let email = authService.pendingConfirmationEmail {
                        Text(email)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                }

                Spacer()

                // Actions
                VStack(spacing: Spacing.md) {
                    // Sign In (after confirming via email link)
                    NavigationLink(destination: LoginSheetView()) {
                        HStack {
                            Spacer()
                            Text("Sign In")
                                .font(.headline)
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.webPrimary)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    // Resend Confirmation Email
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

                    // Start Over
                    Button(action: {
                        authService.clearPendingConfirmation()
                    }) {
                        Text("Create New Account")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .padding(.horizontal, Spacing.lg)
        }
    }

    private func resendEmail() async {
        resendLoading = true
        defer { resendLoading = false }
        do {
            try await authService.resendConfirmationEmail()
            resendSuccess = true
        } catch {
            // Silently fail
        }
    }
}

#Preview {
    GracePeriodExpiredView()
}

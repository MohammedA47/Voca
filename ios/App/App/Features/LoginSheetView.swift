import SwiftUI

struct LoginSheetView: View {
    @Environment(\.dismiss) private var dismiss
    private var authService = AuthService.shared

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showingResetPassword = false
    @State private var resetEmail = ""
    @State private var resetLoading = false
    @State private var resetSuccess = false
    @State private var showPendingConfirmation = false
    @State private var resendLoading = false
    @State private var resendSuccess = false
    
    var body: some View {
        if showPendingConfirmation {
            pendingConfirmationView
        } else if showingResetPassword {
            resetPasswordView
        } else {
            loginSignUpView
        }
    }

    private var loginSignUpView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.webPrimary)
                        .padding(.bottom, Spacing.xs)

                    Text(isSignUp ? "Create Account" : "Welcome Back")
                        .font(.title2.bold())

                    Text(isSignUp ? "Sign up to track your learning progress." : "Log in to continue your learning journey.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xl)

                // Form fields
                VStack(spacing: Spacing.md) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 0) {
                        TextField("Email Address", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))

                        Divider()

                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))

                        if isSignUp {
                            Divider()

                            SecureField("Confirm Password", text: $confirmPassword)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                        }
                    }
                    .clipShape(.rect(cornerRadius: 12))

                    // Forgot Password Button (only in sign-in mode)
                    if !isSignUp {
                        HStack {
                            Spacer()
                            Button(action: {
                                resetEmail = email
                                withAnimation {
                                    showingResetPassword = true
                                }
                            }) {
                                Text("Forgot Password?")
                                    .font(.footnote)
                                    .foregroundStyle(Color.webPrimary)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Action Button
                    Button(action: {
                        Task {
                            await authenticate()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Sign Up" : "Log In")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.webPrimary)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUp && confirmPassword.isEmpty))
                    .opacity((isLoading || email.isEmpty || password.isEmpty || (isSignUp && confirmPassword.isEmpty)) ? 0.6 : 1.0)

                    // Toggle Button
                    Button(action: {
                        withAnimation {
                            isSignUp.toggle()
                            errorMessage = nil
                        }
                    }) {
                        Text(isSignUp ? "Already have an account? Log In" : "Don't have an account? Sign Up")
                            .font(.footnote)
                            .foregroundStyle(Color.webPrimary)
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    dismiss()
                }
            }
        }
        .onChange(of: authService.isAuthenticated) { _ in
            if authService.isAuthenticated {
                dismiss()
            }
        }
    }

    private var pendingConfirmationView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .padding(.bottom, Spacing.xs)

                    Text("Account Created!")
                        .font(.title2.bold())

                    Text("We sent a confirmation email to **\(email)**. You can use the app for 48 hours while you confirm.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xl)

                VStack(spacing: Spacing.md) {
                    // Continue Button
                    Button(action: { dismiss() }) {
                        HStack {
                            Spacer()
                            Text("Continue")
                                .font(.headline)
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.webPrimary)
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    // Resend Email Button
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
                .padding(.horizontal, Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    dismiss()
                }
            }
        }
    }

    private var resetPasswordView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Header
                VStack(spacing: Spacing.sm) {
                    Image(systemName: "envelope.badge.shield.half.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Color.webPrimary)
                        .padding(.bottom, Spacing.xs)

                    Text("Reset Password")
                        .font(.title2.bold())

                    Text("Enter your email to receive a password reset link.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xl)

                // Form fields
                VStack(spacing: Spacing.md) {
                    // Success message
                    if resetSuccess {
                        VStack(spacing: Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.green)

                            Text("Check your email")
                                .font(.headline)

                            Text("We've sent a password reset link to \(resetEmail)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    } else {
                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }

                        // Email field
                        VStack(spacing: 0) {
                            TextField("Email Address", text: $resetEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                        }
                        .clipShape(.rect(cornerRadius: 12))

                        // Send Button
                        Button(action: {
                            Task {
                                await sendResetLink()
                            }
                        }) {
                            HStack {
                                Spacer()
                                if resetLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send Reset Link")
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.webPrimary)
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .disabled(resetLoading || resetEmail.isEmpty)
                        .opacity((resetLoading || resetEmail.isEmpty) ? 0.6 : 1.0)
                    }

                    // Back to Login Button
                    Button(action: {
                        withAnimation {
                            showingResetPassword = false
                            resetSuccess = false
                            errorMessage = nil
                        }
                    }) {
                        Text("Back to Login")
                            .font(.footnote)
                            .foregroundStyle(Color.webPrimary)
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    dismiss()
                }
            }
        }
    }
    
    private func authenticate() async {
        errorMessage = nil

        if isSignUp && password != confirmPassword {
            errorMessage = "Passwords do not match."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if isSignUp {
                let session = try await authService.signUp(email: email, password: password)
                if session == nil {
                    // Email confirmation required — show success view
                    withAnimation { showPendingConfirmation = true }
                }
            } else {
                _ = try await authService.signIn(email: email, password: password)
            }
            // Dismissal is handled by the onChange publisher above
        } catch {
            errorMessage = authService.lastError ?? error.localizedDescription
        }
    }

    private func resendEmail() async {
        resendLoading = true
        defer { resendLoading = false }
        do {
            try await authService.resendConfirmationEmail()
            resendSuccess = true
        } catch {
            // Silently fail — the button text stays unchanged
        }
    }

    private func sendResetLink() async {
        errorMessage = nil

        resetLoading = true
        defer { resetLoading = false }

        do {
            try await authService.resetPassword(email: resetEmail)
            resetSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        LoginSheetView()
    }
}

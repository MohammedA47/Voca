import SwiftUI

private enum AuthStep: Equatable {
    case methodPicker
    case emailForm
    case pendingConfirmation
    case resetPassword
}

private enum AuthProvider: String, Identifiable {
    case apple = "Apple"
    case google = "Google"

    var id: String { rawValue }
}

struct LoginSheetView: View {
    @Environment(\.dismiss) private var dismiss
    private var authService = AuthService.shared

    @State private var authStep: AuthStep
    @State private var isSignUp: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var resetEmail = ""
    @State private var resetLoading = false
    @State private var resetSuccess = false
    @State private var resendLoading = false
    @State private var resendSuccess = false
    @State private var resendError: String? = nil
    @State private var verifyLoading = false
    @State private var verifyError: String? = nil
    @State private var unavailableProvider: AuthProvider?

    init(startInPendingConfirmation: Bool = false) {
        _authStep = State(initialValue: startInPendingConfirmation ? .pendingConfirmation : .methodPicker)
        _isSignUp = State(initialValue: startInPendingConfirmation)

        if startInPendingConfirmation,
           let pending = AuthService.shared.pendingConfirmationEmail {
            _email = State(initialValue: pending)
        }
    }

    var body: some View {
        Group {
            switch authStep {
            case .methodPicker:
                methodPickerView
            case .emailForm:
                emailAuthView
            case .pendingConfirmation:
                pendingConfirmationView
            case .resetPassword:
                resetPasswordView
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    handleBack()
                }
            }
        }
        .alert(item: $unavailableProvider) { provider in
            Alert(
                title: Text("\(provider.rawValue) Coming Soon"),
                message: Text("\(provider.rawValue) sign-in is part of the new flow, but it is not connected yet. Use Email for now."),
                dismissButton: .default(Text("OK"))
            )
        }
        .task(id: authStep) {
            if authStep == .pendingConfirmation,
               await authService.checkConfirmationStatus() {
                dismiss()
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                dismiss()
            }
        }
    }

    private var methodPickerView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.webPrimary.opacity(0.12))

                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.webPrimary)
                    }
                    .frame(width: 78, height: 78)

                    VStack(spacing: Spacing.sm) {
                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text(isSignUp
                             ? "Choose how you want to start with Oxford Pronunciation."
                             : "Choose how you want to sign in to keep your learning in sync.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, Spacing.xxl)

                VStack(spacing: Spacing.sm + Spacing.xs) {
                    AuthMethodButton(
                        title: isSignUp ? "Continue with Apple" : "Sign in with Apple",
                        style: .apple
                    ) {
                        unavailableProvider = .apple
                    }

                    AuthMethodButton(
                        title: isSignUp ? "Continue with Google" : "Sign in with Google",
                        style: .google
                    ) {
                        unavailableProvider = .google
                    }

                    AuthMethodButton(
                        title: isSignUp ? "Continue with Email" : "Sign in with Email",
                        style: .email
                    ) {
                        errorMessage = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            authStep = .emailForm
                        }
                    }
                }

                Text("Email is available now. Apple and Google are shown in the final flow, but they are not wired up yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: {
                    errorMessage = nil
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSignUp.toggle()
                    }
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Create one")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.webPrimary)
                }
                .padding(.top, Spacing.xs)

                Spacer(minLength: Spacing.xl)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: .infinity)
        }
    }

    private var emailAuthView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.md) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.webPrimary.opacity(0.12))

                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.webPrimary)
                    }
                    .frame(width: 72, height: 72)

                    VStack(spacing: Spacing.sm) {
                        Text(isSignUp ? "Create account with email" : "Sign in with email")
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text(isSignUp
                             ? "Use your email to create an account and save your learning progress."
                             : "Enter your email and password to continue where you left off.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, Spacing.xl)

                if let error = errorMessage {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)

                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.red.opacity(0.08))
                    )
                }

                VStack(spacing: Spacing.md) {
                    VStack(spacing: 0) {
                        TextField("Email Address", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))

                        Divider()

                        SecureField("Password", text: $password)
                            .textContentType(isSignUp ? .newPassword : .password)
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))

                        if isSignUp {
                            Divider()

                            SecureField("Confirm Password", text: $confirmPassword)
                                .textContentType(.newPassword)
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    if !isSignUp {
                        HStack {
                            Spacer()
                            Button(action: {
                                resetEmail = email
                                errorMessage = nil
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    authStep = .resetPassword
                                }
                            }) {
                                Text("Forgot Password?")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.webPrimary)
                            }
                        }
                    }

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
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.webPrimary, Color.webPrimary.opacity(0.82)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!canSubmitCredentials)
                    .opacity(canSubmitCredentials ? 1 : 0.55)
                }

                VStack(spacing: Spacing.sm) {
                    Button(action: {
                        errorMessage = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            authStep = .methodPicker
                        }
                    }) {
                        Text("Other Sign-In Options")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.webPrimary)
                    }

                    Button(action: {
                        errorMessage = nil
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSignUp.toggle()
                        }
                    }) {
                        Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Create one")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, Spacing.xs)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.xl)
            .frame(maxWidth: .infinity)
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

                    Text("We sent a confirmation email to **\(authService.pendingConfirmationEmail ?? email)**. You can use the app for 48 hours while you confirm.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Spacing.xl)

                VStack(spacing: Spacing.md) {
                    if let verifyError {
                        Text(verifyError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: {
                        Task { await verifyConfirmation() }
                    }) {
                        HStack {
                            Spacer()
                            if verifyLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("I've Confirmed My Email")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.webPrimary)
                        .clipShape(.rect(cornerRadius: 12))
                    }
                    .disabled(verifyLoading)

                    Button(action: { dismiss() }) {
                        HStack {
                            Spacer()
                            Text("Continue Without Confirming")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        .foregroundStyle(Color.webPrimary)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(.rect(cornerRadius: 12))
                    }

                    if let resendError {
                        Text(resendError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

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
    }

    private var resetPasswordView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
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

                VStack(spacing: Spacing.md) {
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
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.horizontal)
                                .multilineTextAlignment(.center)
                        }

                        VStack(spacing: 0) {
                            TextField("Email Address", text: $resetEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                        }
                        .clipShape(.rect(cornerRadius: 12))

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

                    Button(action: {
                        email = resetEmail.isEmpty ? email : resetEmail
                        errorMessage = nil
                        resetSuccess = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            authStep = .emailForm
                        }
                    }) {
                        Text("Back to Sign In")
                            .font(.footnote)
                            .foregroundStyle(Color.webPrimary)
                    }
                    .padding(.top, Spacing.xs)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
    }

    private var canSubmitCredentials: Bool {
        !isLoading &&
        !email.isEmpty &&
        !password.isEmpty &&
        (!isSignUp || !confirmPassword.isEmpty)
    }

    private func handleBack() {
        switch authStep {
        case .methodPicker:
            dismiss()
        case .emailForm:
            errorMessage = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                authStep = .methodPicker
            }
        case .resetPassword:
            errorMessage = nil
            resetSuccess = false
            withAnimation(.easeInOut(duration: 0.2)) {
                authStep = .emailForm
            }
        case .pendingConfirmation:
            dismiss()
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        authStep = .pendingConfirmation
                    }
                }
            } else {
                _ = try await authService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = authService.lastError ?? error.localizedDescription
        }
    }

    private func verifyConfirmation() async {
        verifyError = nil
        verifyLoading = true
        defer { verifyLoading = false }

        let confirmed = await authService.checkConfirmationStatus(force: true)
        if confirmed {
            return
        }

        verifyError = authService.lastError
            ?? "We couldn't verify your email yet. Please tap the link in your inbox, then try again."
    }

    private func resendEmail() async {
        resendError = nil
        resendLoading = true
        defer { resendLoading = false }

        do {
            try await authService.resendConfirmationEmail()
            resendSuccess = true
            try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
            resendSuccess = false
        } catch {
            resendError = error.localizedDescription
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

private enum AuthMethodStyle {
    case apple
    case google
    case email
}

private struct AuthMethodButton: View {
    let title: String
    let style: AuthMethodStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(backgroundFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(borderColor, lineWidth: borderLineWidth)
                    )

                HStack {
                    icon
                        .frame(width: 24, height: 24)

                    Spacer()
                }
                .padding(.horizontal, Spacing.md)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 44)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 58)
        }
        .buttonStyle(.plain)
    }

    private var backgroundFill: AnyShapeStyle {
        switch style {
        case .apple:
            return AnyShapeStyle(Color.black)
        case .google:
            return AnyShapeStyle(Color(UIColor.systemBackground))
        case .email:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.webPrimary, Color.webPrimary.opacity(0.82)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private var borderColor: Color {
        switch style {
        case .google:
            return Color(UIColor.separator)
        default:
            return .clear
        }
    }

    private var borderLineWidth: CGFloat {
        switch style {
        case .google:
            return 1
        default:
            return 0
        }
    }

    private var textColor: Color {
        switch style {
        case .google:
            return .primary
        default:
            return .white
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch style {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        case .google:
            Text("G")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 0.25, green: 0.49, blue: 0.96),
                            Color(red: 0.92, green: 0.28, blue: 0.20),
                            Color(red: 0.98, green: 0.74, blue: 0.18),
                            Color(red: 0.20, green: 0.66, blue: 0.33)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        case .email:
            Image(systemName: "envelope.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    NavigationStack {
        LoginSheetView()
    }
}

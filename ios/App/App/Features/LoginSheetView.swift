import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginSheetView: View {
    @Environment(\.dismiss) private var dismiss
    private var authService = AuthService.shared

    @State private var showEmailForm: Bool
    @State private var showPendingConfirmation: Bool
    @State private var showResetPassword = false
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
    @State private var appleLoading = false
    @State private var currentAppleNonce: String?
    @State private var appleCoordinator: AppleSignInCoordinator?

    init(startInPendingConfirmation: Bool = false) {
        _showEmailForm = State(initialValue: false)
        _showPendingConfirmation = State(initialValue: startInPendingConfirmation)
        _isSignUp = State(initialValue: startInPendingConfirmation)

        if startInPendingConfirmation,
           let pending = AuthService.shared.pendingConfirmationEmail {
            _email = State(initialValue: pending)
        }
    }

    var body: some View {
        methodPickerView
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    dismiss()
                }
            }
        }
        .task(id: showPendingConfirmation) {
            if showPendingConfirmation,
               await authService.checkConfirmationStatus() {
                dismiss()
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                dismiss()
            }
        }
        .navigationDestination(isPresented: $showEmailForm) {
            emailAuthView
        }
        .navigationDestination(isPresented: $showPendingConfirmation) {
            pendingConfirmationView
        }
    }

    private var methodPickerView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.12))

                        Image(systemName: "person.badge.key.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color.accentPrimary)
                    }
                    .frame(width: 78, height: 78)

                    VStack(spacing: Spacing.sm) {
                        Text(isSignUp ? "Create your account" : "Welcome back")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)

                        Text(isSignUp
                             ? "Choose how you want to start with Voca."
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
                        style: .apple,
                        isLoading: appleLoading
                    ) {
                        Task { await signInWithApple() }
                    }

                    AuthMethodButton(
                        title: isSignUp ? "Continue with Email" : "Sign in with Email",
                        style: .email
                    ) {
                        errorMessage = nil
                        showEmailForm = true
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }


                Button(action: {
                    errorMessage = nil
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSignUp.toggle()
                    }
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Create one")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentPrimary)
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
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.12))

                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.accentPrimary)
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
                                showResetPassword = true
                            }) {
                                Text("Forgot Password?")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.accentPrimary)
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
                                colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.82)],
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
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    errorMessage = nil
                    showEmailForm = false
                }
            }
        }
        .navigationDestination(isPresented: $showResetPassword) {
            resetPasswordView
        }
    }

    private var pendingConfirmationView: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                VStack(spacing: Spacing.sm) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.green.opacity(0.12))

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    .frame(width: 72, height: 72)
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
                        .background(
                            LinearGradient(
                                colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.82)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(verifyLoading)

                    Button(action: { dismiss() }) {
                        HStack {
                            Spacer()
                            Text("Continue Without Confirming")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                        }
                        .foregroundStyle(Color.accentPrimary)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                        .foregroundStyle(Color.accentPrimary)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                VStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(Color.accentPrimary.opacity(0.12))

                        Image(systemName: "lock.rotation")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.accentPrimary)
                    }
                    .frame(width: 72, height: 72)
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
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                            .background(
                                LinearGradient(
                                    colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.82)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(resetLoading || resetEmail.isEmpty)
                        .opacity((resetLoading || resetEmail.isEmpty) ? 0.6 : 1.0)
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SettingsBackButton {
                    errorMessage = nil
                    resetSuccess = false
                    showResetPassword = false
                }
            }
        }
    }

    private var canSubmitCredentials: Bool {
        !isLoading &&
        !email.isEmpty &&
        !password.isEmpty &&
        (!isSignUp || !confirmPassword.isEmpty)
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
                    verifyError = nil
                    resendError = nil
                    resendSuccess = false
                    showPendingConfirmation = true
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

    private func signInWithApple() async {
        guard !appleLoading else { return }
        errorMessage = nil
        appleLoading = true
        defer { appleLoading = false }

        let rawNonce = Self.randomNonceString()
        currentAppleNonce = rawNonce

        let coordinator = AppleSignInCoordinator()
        appleCoordinator = coordinator

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(rawNonce)

        do {
            let credential = try await coordinator.perform(request: request)
            guard let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "Apple didn't return an identity token. Please try again."
                return
            }
            _ = try await authService.signInWithApple(idToken: idToken, rawNonce: rawNonce)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            // User tapped cancel — stay silent.
        } catch {
            errorMessage = authService.lastError ?? error.localizedDescription
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-._")
        var result = ""
        var remaining = length

        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                // Fallback to a non-crypto source; still produces a unique string.
                randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
            }
            for byte in randoms where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }

        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
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
    case email
}

private struct AuthMethodButton: View {
    let title: String
    let style: AuthMethodStyle
    var isLoading: Bool = false
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

                if isLoading {
                    ProgressView()
                        .tint(textColor)
                } else {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(textColor)
                        .padding(.horizontal, 44)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(height: 58)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private var backgroundFill: AnyShapeStyle {
        switch style {
        case .apple:
            return AnyShapeStyle(Color.black)
        case .email:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.82)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }

    private var borderColor: Color { .clear }
    private var borderLineWidth: CGFloat { 0 }
    private var textColor: Color { .white }

    @ViewBuilder
    private var icon: some View {
        switch style {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        case .email:
            Image(systemName: "envelope.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Apple Sign-In Coordinator

@MainActor
private final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?

    func perform(request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { continuation = nil }
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            continuation?.resume(returning: credential)
        } else {
            continuation?.resume(throwing: ASAuthorizationError(.failed))
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive })
            ?? scenes.first
        else {
            preconditionFailure("A window scene is required to present Sign in with Apple.")
        }
        return scene.keyWindow
            ?? scene.windows.first
            ?? ASPresentationAnchor(windowScene: scene)
    }
}

#Preview {
    NavigationStack {
        LoginSheetView()
    }
}

import Foundation
import Security

private enum AuthServiceError: LocalizedError {
    case missingSession

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "No active session."
        }
    }
}

struct Session: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let user: AuthUser?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        self.expiresIn = try container.decodeIfPresent(Int.self, forKey: .expiresIn)
        self.user = try container.decodeIfPresent(AuthUser.self, forKey: .user)

        // Try to decode createdAt, otherwise use current date
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            self.createdAt = Self.iso8601Formatter.date(from: createdAtString)
        } else {
            self.createdAt = Date()
        }
    }

    init(accessToken: String, refreshToken: String?, expiresIn: Int?, user: AuthUser?, createdAt: Date?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.user = user
        self.createdAt = createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(refreshToken, forKey: .refreshToken)
        try container.encodeIfPresent(expiresIn, forKey: .expiresIn)
        try container.encodeIfPresent(user, forKey: .user)

        if let createdAt = createdAt {
            try container.encode(Self.iso8601Formatter.string(from: createdAt), forKey: .createdAt)
        }
    }

    private static let iso8601Formatter = ISO8601DateFormatter()
}

struct AuthUser: Codable {
    let id: String
    let email: String?
}

/// Lightweight response returned by Supabase when email confirmations are
/// enabled and the user has not yet verified their address.
struct SignUpUser: Codable {
    let id: String
    let email: String?
}

/// Handles Supabase email/password authentication.
///
/// Persists the session to `UserDefaults` so users stay logged in across launches.
@Observable
@MainActor
final class AuthService {
    static let shared = AuthService()
    private static let sessionKey = "supabase_session"
    private static let pendingConfirmationEmailKey = "pending_confirmation_email"
    private static let pendingConfirmationDateKey = "pending_confirmation_date"
    private static let authSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    var currentUser: AuthUser?
    var sessionToken: String?
    var lastError: String? = nil

    // MARK: - Grace Period State

    var pendingConfirmationEmail: String?
    var signUpDate: Date?

    /// Set to `true` when the user opens a password-recovery email link.
    /// The UI observes this to present a "set new password" screen.
    var isPasswordRecovery: Bool = false

    var isPendingConfirmation: Bool {
        pendingConfirmationEmail != nil && !isAuthenticated
    }

    var isGracePeriodExpired: Bool {
        guard let signUpDate, isPendingConfirmation else { return false }
        return Date().timeIntervalSince(signUpDate) > 48 * 60 * 60
    }

    var graceDeadline: Date? {
        signUpDate?.addingTimeInterval(48 * 60 * 60)
    }

    private var storedSession: Session?

    /// Timestamp of the most recent silent confirmation probe. Used to
    /// throttle `checkConfirmationStatus` against scene-phase churn.
    private var lastConfirmationCheck: Date?

    /// Keychain account identifier for the sign-up password cached during
    /// the email-confirmation grace period.
    private let pendingPasswordKeychainAccount = "pending_confirmation_password"

    private init() {
        loadSession()
        loadPendingConfirmation()
        Task {
            await checkAndRefreshIfNeeded()
            _ = await checkConfirmationStatus()
        }
    }

    /// Whether the user has an active session.
    var isAuthenticated: Bool {
        return sessionToken != nil
    }

    private func saveSession(session: Session) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(session) {
            UserDefaults.standard.set(encoded, forKey: Self.sessionKey)
        }
        self.storedSession = session
        self.sessionToken = session.accessToken
        self.currentUser = session.user
    }

    private func loadSession() {
        if let savedData = UserDefaults.standard.data(forKey: Self.sessionKey) {
            let decoder = JSONDecoder()
            if let loadedSession = try? decoder.decode(Session.self, from: savedData) {
                self.storedSession = loadedSession
                self.sessionToken = loadedSession.accessToken
                self.currentUser = loadedSession.user
            }
        }
    }

    // MARK: - Pending Confirmation Persistence

    private func savePendingConfirmation(email: String) {
        UserDefaults.standard.set(email, forKey: Self.pendingConfirmationEmailKey)
        UserDefaults.standard.set(Date(), forKey: Self.pendingConfirmationDateKey)
        self.pendingConfirmationEmail = email
        self.signUpDate = Date()
    }

    private func loadPendingConfirmation() {
        self.pendingConfirmationEmail = UserDefaults.standard.string(forKey: Self.pendingConfirmationEmailKey)
        self.signUpDate = UserDefaults.standard.object(forKey: Self.pendingConfirmationDateKey) as? Date
    }

    func clearPendingConfirmation() {
        UserDefaults.standard.removeObject(forKey: Self.pendingConfirmationEmailKey)
        UserDefaults.standard.removeObject(forKey: Self.pendingConfirmationDateKey)
        self.pendingConfirmationEmail = nil
        self.signUpDate = nil
        clearPendingPassword()
        lastConfirmationCheck = nil
    }

    // MARK: - Pending Password Keychain

    /// Stores the sign-up password in the Keychain so the app can silently
    /// verify confirmation status later without asking the user to retype it.
    /// Cleared the moment a real session is established.
    private func savePendingPassword(_ password: String) {
        guard let data = password.data(using: .utf8) else { return }

        // Delete any existing entry first so we can upsert cleanly.
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: pendingPasswordKeychainAccount
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: pendingPasswordKeychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadPendingPassword() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: pendingPasswordKeychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        return password
    }

    private func clearPendingPassword() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: pendingPasswordKeychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Clears the stored session and signs the user out.
    func logout() {
        UserDefaults.standard.removeObject(forKey: Self.sessionKey)
        self.sessionToken = nil
        self.currentUser = nil
        clearPendingConfirmation()
    }

    /// Deletes the user account by clearing all local data and authentication.
    func deleteAccount() async throws {
        // Clear all app-specific UserDefaults
        UserDefaults.standard.removeObject(forKey: Self.sessionKey)
        UserDefaults.standard.removeObject(forKey: "Oxford_BookmarkedWords")
        UserDefaults.standard.removeObject(forKey: "Oxford_LearnedWords")
        UserDefaults.standard.removeObject(forKey: "Oxford_LearnedWords_V2")

        // Clear all @AppStorage data
        let defaults = UserDefaults.standard
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
        }

        // Clear authentication state
        self.sessionToken = nil
        self.currentUser = nil
        clearPendingConfirmation()
    }

    /// Creates a new account and returns the session, or `nil` when
    /// email confirmation is pending (grace period starts).
    func signUp(email: String, password: String) async throws -> Session? {
        lastError = nil
        guard let url = authURL(path: "signup", redirectTo: Config.authRedirectURL) else { throw URLError(.badURL) }

        let body = ["email": email, "password": password]
        let (data, response) = try await sendJSONRequest(to: url, method: "POST", body: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            lastError = "Network error. Check your connection."
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("Auth API Sign Up failed with status \(httpResponse.statusCode): \(errorBody)")
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = errorDict["msg"] as? String {
                lastError = msg
                throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            lastError = "Sign up failed. Please try again."
            throw URLError(.badServerResponse)
        }

        // Try to decode a full session (returned when email confirmations are disabled).
        if let session = try? JSONDecoder().decode(Session.self, from: data) {
            saveSession(session: session)
            clearPendingConfirmation()
            return session
        }

        // No session means email confirmation is required — start the grace period.
        if let _ = try? JSONDecoder().decode(SignUpUser.self, from: data) {
            savePendingConfirmation(email: email)
            savePendingPassword(password)
            return nil
        }

        lastError = "Sign up failed. Please try again."
        throw URLError(.badServerResponse)
    }

    /// Signs in with email + password and returns the session.
    func signIn(email: String, password: String) async throws -> Session {
        lastError = nil
        guard let url = URL(string: "\(Config.supabaseUrl)/auth/v1/token?grant_type=password") else { throw URLError(.badURL) }

        let body = ["email": email, "password": password]
        let (data, response) = try await sendJSONRequest(to: url, method: "POST", body: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            lastError = "Network error. Check your connection."
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("Auth API Sign In failed with status \(httpResponse.statusCode): \(errorBody)")
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorDict["error_description"] as? String {
                // Friendly message for unconfirmed email
                if errorMessage.lowercased().contains("email not confirmed") {
                    lastError = "Please confirm your email first. Check your inbox for the confirmation link."
                } else {
                    lastError = errorMessage
                }
                throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: lastError!])
            }
            lastError = "Sign in failed. Please try again."
            throw URLError(.badServerResponse)
        }

        let session = try JSONDecoder().decode(Session.self, from: data)
        saveSession(session: session)
        clearPendingConfirmation()
        return session
    }

    /// Sends a password reset email to the given address.
    func resetPassword(email: String) async throws {
        guard let url = authURL(path: "recover", redirectTo: Config.authRedirectURL) else { throw URLError(.badURL) }

        let body = ["email": email]
        let (data, response) = try await sendJSONRequest(to: url, method: "POST", body: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("Auth API Password Reset failed with status \(httpResponse.statusCode): \(errorBody)")
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = errorDict["msg"] as? String {
                throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.badServerResponse)
        }
    }

    /// Refreshes the session token using the stored refresh token.
    /// On success, updates sessionToken, currentUser, and persists the new session.
    /// On failure, logs out the user.
    func refreshSession() async {
        guard let refreshToken = storedSession?.refreshToken else {
            print("No refresh token available")
            logout()
            return
        }

        guard let url = URL(string: "\(Config.supabaseUrl)/auth/v1/token?grant_type=refresh_token") else {
            print("Invalid refresh URL")
            logout()
            return
        }

        let body = ["refresh_token": refreshToken]
        do {
            let (data, response) = try await sendJSONRequest(to: url, method: "POST", body: body)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid response from refresh token endpoint")
                logout()
                return
            }

            if !(200...299).contains(httpResponse.statusCode) {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                print("Token refresh failed with status \(httpResponse.statusCode): \(errorBody)")
                logout()
                return
            }

            let newSession = try JSONDecoder().decode(Session.self, from: data)
            saveSession(session: newSession)
            print("Session token refreshed successfully")
        } catch {
            print("Error refreshing session: \(error.localizedDescription)")
            logout()
        }
    }

    /// Resends the sign-up confirmation email for the pending address.
    func resendConfirmationEmail() async throws {
        guard let email = pendingConfirmationEmail, !email.isEmpty else {
            throw NSError(
                domain: "AuthError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No pending email to resend. Please sign up again."]
            )
        }
        guard let url = authURL(path: "resend", redirectTo: Config.authRedirectURL) else { throw URLError(.badURL) }

        let body: [String: String] = ["type": "signup", "email": email]
        let (data, response) = try await sendJSONRequest(to: url, method: "POST", body: body)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("Resend confirmation failed with status \(httpResponse.statusCode): \(errorBody)")

            // Parse a human-readable message from Supabase's error body.
            var message = "Could not resend the confirmation email. Please try again."
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let msg = errorDict["msg"] as? String { message = msg }
                else if let msg = errorDict["error_description"] as? String { message = msg }
                else if let msg = errorDict["message"] as? String { message = msg }
            }

            // Supabase rate-limits resends (default: once every 60 seconds).
            if httpResponse.statusCode == 429 {
                message = "Please wait a minute before requesting another email."
            }

            throw NSError(
                domain: "AuthError",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }
    }

    /// Silently probes Supabase to see whether the user's email has been
    /// confirmed since sign-up. If so, a real session is established and the
    /// pending state is cleared automatically by `signIn`.
    ///
    /// Returns `true` iff the user ends up authenticated. Never surfaces the
    /// expected "email not confirmed" response as a user-facing error.
    func checkConfirmationStatus(force: Bool = false) async -> Bool {
        // Nothing to check.
        if pendingConfirmationEmail == nil {
            return isAuthenticated
        }

        // Throttle unless forced (e.g. explicit button tap).
        if !force, let last = lastConfirmationCheck,
           Date().timeIntervalSince(last) < 10 {
            return isAuthenticated
        }
        lastConfirmationCheck = Date()

        guard let email = pendingConfirmationEmail,
              let password = loadPendingPassword() else {
            return false
        }

        let previousError = lastError
        do {
            _ = try await signIn(email: email, password: password)
            return true
        } catch {
            let description = (error as NSError).localizedDescription.lowercased()
            if description.contains("email not confirmed") ||
                description.contains("confirm your email") {
                // Expected: the user hasn't confirmed yet. Don't pollute UI.
                lastError = previousError
            }
            return false
        }
    }

    /// Checks if the current session token is expired or about to expire (within 60 seconds).
    /// If so, attempts to refresh it using the refresh token.
    func checkAndRefreshIfNeeded() async {
        guard let session = storedSession else {
            return
        }

        guard let createdAt = session.createdAt, let expiresIn = session.expiresIn else {
            return
        }

        let expiryTime = createdAt.addingTimeInterval(TimeInterval(expiresIn))
        let bufferTime: TimeInterval = 60 // Refresh if within 60 seconds of expiry

        if Date() >= expiryTime.addingTimeInterval(-bufferTime) {
            print("Session token is expired or about to expire, refreshing...")
            await refreshSession()
        }
    }

    /// Handles auth callbacks coming back from Supabase email links.
    ///
    /// Supabase appends `type=signup` for email confirmations and `type=recovery`
    /// for password reset links. For recovery, we flip `isPasswordRecovery` so
    /// the UI can present the "set new password" screen instead of simply
    /// signing the user in silently.
    func handleIncomingAuthURL(_ url: URL) async {
        guard matchesAuthRedirect(url) else { return }

        let parameters = urlParameters(from: url)

        if let message = parameters["error_description"] ?? parameters["error"] {
            lastError = message
            return
        }

        guard let accessToken = parameters["access_token"] else {
            return
        }

        let session = Session(
            accessToken: accessToken,
            refreshToken: parameters["refresh_token"],
            expiresIn: parameters["expires_in"].flatMap(Int.init),
            user: currentUser,
            createdAt: Date()
        )

        let linkType = parameters["type"]?.lowercased()
        saveSession(session: session)
        lastError = nil

        if linkType == "recovery" {
            // Keep the user on the "set new password" screen. Do not clear the
            // pending-confirmation grace period here — the user hasn't completed
            // a sign-up flow.
            isPasswordRecovery = true
        } else {
            clearPendingConfirmation()
        }

        await fetchCurrentUser()
    }

    /// Updates the current user's password. Used after the user opens a
    /// password-recovery email link and enters a new password.
    func updatePassword(newPassword: String) async throws {
        _ = try await updateCurrentUser(payload: ["password": newPassword])
    }

    @discardableResult
    func updateProfile(displayName: String) async throws -> Data {
        try await updateCurrentUser(payload: ["user_metadata": ["display_name": displayName]])
    }

    /// Called by the UI when the user finishes or cancels the recovery flow.
    func finishPasswordRecovery() {
        isPasswordRecovery = false
    }

    private func authURL(path: String, redirectTo: URL? = nil) -> URL? {
        guard var components = URLComponents(string: "\(Config.supabaseUrl)/auth/v1/\(path)") else {
            return nil
        }

        if let redirectTo {
            components.queryItems = [URLQueryItem(name: "redirect_to", value: redirectTo.absoluteString)]
        }

        return components.url
    }

    private func matchesAuthRedirect(_ url: URL) -> Bool {
        guard let expectedScheme = Config.authRedirectURL.scheme?.lowercased(),
              url.scheme?.lowercased() == expectedScheme else {
            return false
        }

        if let expectedHost = Config.authRedirectURL.host, !expectedHost.isEmpty {
            return url.host?.lowercased() == expectedHost.lowercased()
        }

        return true
    }

    private func urlParameters(from url: URL) -> [String: String] {
        var parameters: [String: String] = [:]

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            for item in components.queryItems ?? [] {
                parameters[item.name] = item.value ?? ""
            }
        }

        if let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment,
           let fragmentComponents = URLComponents(string: "auth://callback?\(fragment)") {
            for item in fragmentComponents.queryItems ?? [] {
                parameters[item.name] = item.value ?? ""
            }
        }

        return parameters
    }

    private func fetchCurrentUser() async {
        guard let sessionToken,
              let url = URL(string: "\(Config.supabaseUrl)/auth/v1/user") else {
            return
        }

        do {
            let (data, response) = try await sendRequest(
                to: url,
                method: "GET",
                bearerToken: sessionToken
            )
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  let user = try? JSONDecoder().decode(AuthUser.self, from: data) else {
                return
            }

            self.currentUser = user

            if let storedSession {
                saveSession(
                    session: Session(
                        accessToken: storedSession.accessToken,
                        refreshToken: storedSession.refreshToken,
                        expiresIn: storedSession.expiresIn,
                        user: user,
                        createdAt: storedSession.createdAt
                    )
                )
            }
        } catch {
            print("Failed to load confirmed user: \(error.localizedDescription)")
        }
    }

    private func updateCurrentUser(payload: [String: Any]) async throws -> Data {
        guard let sessionToken else { throw AuthServiceError.missingSession }
        guard let url = URL(string: "\(Config.supabaseUrl)/auth/v1/user") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await sendJSONRequest(
            to: url,
            method: "PUT",
            body: payload,
            bearerToken: sessionToken
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("Update user failed with status \(httpResponse.statusCode): \(errorBody)")
            throw authError(from: data, statusCode: httpResponse.statusCode)
        }

        return data
    }

    private func sendJSONRequest(
        to url: URL,
        method: String,
        body: Any,
        bearerToken: String? = nil
    ) async throws -> (Data, URLResponse) {
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        return try await sendRequest(
            to: url,
            method: method,
            body: bodyData,
            bearerToken: bearerToken
        )
    }

    private func sendRequest(
        to url: URL,
        method: String,
        body: Data? = nil,
        bearerToken: String? = nil
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body
        return try await Self.authSession.data(for: request)
    }

    private func authError(from data: Data, statusCode: Int) -> NSError {
        if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let message = (errorDict["msg"] as? String)
                ?? (errorDict["error_description"] as? String)
                ?? (errorDict["message"] as? String)
            if let message {
                return NSError(
                    domain: "AuthError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }
        }

        return NSError(
            domain: "AuthError",
            code: statusCode,
            userInfo: [NSLocalizedDescriptionKey: "Request failed. Please try again."]
        )
    }
}

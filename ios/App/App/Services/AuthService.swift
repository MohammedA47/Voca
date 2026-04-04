import Foundation

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
            let formatter = ISO8601DateFormatter()
            self.createdAt = formatter.date(from: createdAtString)
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
            let formatter = ISO8601DateFormatter()
            try container.encode(formatter.string(from: createdAt), forKey: .createdAt)
        }
    }
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

    var currentUser: AuthUser?
    var sessionToken: String?
    var lastError: String? = nil

    // MARK: - Grace Period State

    var pendingConfirmationEmail: String?
    var signUpDate: Date?

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

    private init() {
        loadSession()
        loadPendingConfirmation()
        Task {
            await checkAndRefreshIfNeeded()
        }
    }

    /// Whether the user has an active session.
    var isAuthenticated: Bool {
        return sessionToken != nil
    }

    private func saveSession(session: Session) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(session) {
            UserDefaults.standard.set(encoded, forKey: "supabase_session")
        }
        self.storedSession = session
        self.sessionToken = session.accessToken
        self.currentUser = session.user
    }

    private func loadSession() {
        if let savedData = UserDefaults.standard.data(forKey: "supabase_session") {
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
        UserDefaults.standard.set(email, forKey: "pending_confirmation_email")
        UserDefaults.standard.set(Date(), forKey: "pending_confirmation_date")
        self.pendingConfirmationEmail = email
        self.signUpDate = Date()
    }

    private func loadPendingConfirmation() {
        self.pendingConfirmationEmail = UserDefaults.standard.string(forKey: "pending_confirmation_email")
        self.signUpDate = UserDefaults.standard.object(forKey: "pending_confirmation_date") as? Date
    }

    func clearPendingConfirmation() {
        UserDefaults.standard.removeObject(forKey: "pending_confirmation_email")
        UserDefaults.standard.removeObject(forKey: "pending_confirmation_date")
        self.pendingConfirmationEmail = nil
        self.signUpDate = nil
    }

    /// Clears the stored session and signs the user out.
    func logout() {
        UserDefaults.standard.removeObject(forKey: "supabase_session")
        self.sessionToken = nil
        self.currentUser = nil
        clearPendingConfirmation()
    }

    /// Deletes the user account by clearing all local data and authentication.
    func deleteAccount() async throws {
        // Clear all app-specific UserDefaults
        UserDefaults.standard.removeObject(forKey: "supabase_session")
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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

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
            return nil
        }

        lastError = "Sign up failed. Please try again."
        throw URLError(.badServerResponse)
    }

    /// Signs in with email + password and returns the session.
    func signIn(email: String, password: String) async throws -> Session {
        lastError = nil
        guard let url = URL(string: "\(Config.supabaseUrl)/auth/v1/token?grant_type=password") else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

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

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["refresh_token": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

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
        guard let email = pendingConfirmationEmail else { return }
        guard let url = authURL(path: "resend", redirectTo: Config.authRedirectURL) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["type": "signup", "email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("Resend confirmation failed: \(errorBody)")
            throw URLError(.badServerResponse)
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

        saveSession(session: session)
        clearPendingConfirmation()
        lastError = nil
        await fetchCurrentUser()
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

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
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
}

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

    private var storedSession: Session?

    private init() {
        loadSession()
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

    /// Clears the stored session and signs the user out.
    func logout() {
        UserDefaults.standard.removeObject(forKey: "supabase_session")
        self.sessionToken = nil
        self.currentUser = nil
    }

    /// Deletes the user account by clearing all local data and authentication.
    func deleteAccount() async throws {
        // Clear all app-specific UserDefaults
        UserDefaults.standard.removeObject(forKey: "supabase_session")
        UserDefaults.standard.removeObject(forKey: "bookmarkedWords")
        UserDefaults.standard.removeObject(forKey: "learnedWords")

        // Clear all @AppStorage data
        let defaults = UserDefaults.standard
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
        }

        // Clear authentication state
        self.sessionToken = nil
        self.currentUser = nil
    }

    /// Creates a new account and returns the session.
    func signUp(email: String, password: String) async throws -> Session {
        lastError = nil
        guard let url = URL(string: "\(Config.supabaseUrl)/auth/v1/signup") else { throw URLError(.badURL) }

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

        let session = try JSONDecoder().decode(Session.self, from: data)
        saveSession(session: session)
        return session
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
                lastError = errorMessage
                throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            lastError = "Sign in failed. Please try again."
            throw URLError(.badServerResponse)
        }

        let session = try JSONDecoder().decode(Session.self, from: data)
        saveSession(session: session)
        return session
    }

    /// Sends a password reset email to the given address.
    func resetPassword(email: String) async throws {
        guard let url = URL(string: "\(Config.supabaseUrl)/auth/v1/recover") else { throw URLError(.badURL) }

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
}

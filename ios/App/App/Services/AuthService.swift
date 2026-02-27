import Foundation
import Combine

struct Session: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let user: User?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

struct User: Codable {
    let id: String
    let email: String?
}

class AuthService: ObservableObject {
    static let shared = AuthService()
    
    // Hardcoded for frontend parity
    private let supabaseUrl = "https://brknoeqgpejhxsqsjnan.supabase.co"
    private let supabaseAnonKey = "sb_publishable_SIqMFd0McVuxDH7u6V_1RA_okuvvVmT"
    
    @Published var currentUser: User?
    @Published var sessionToken: String?
    
    private init() {
        loadSession()
    }
    
    var isAuthenticated: Bool {
        return sessionToken != nil
    }
    
    private func saveSession(session: Session) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(session) {
            UserDefaults.standard.set(encoded, forKey: "supabase_session")
        }
        DispatchQueue.main.async {
            self.sessionToken = session.accessToken
            self.currentUser = session.user
        }
    }
    
    private func loadSession() {
        if let savedData = UserDefaults.standard.data(forKey: "supabase_session") {
            let decoder = JSONDecoder()
            if let loadedSession = try? decoder.decode(Session.self, from: savedData) {
                self.sessionToken = loadedSession.accessToken
                self.currentUser = loadedSession.user
            }
        }
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: "supabase_session")
        DispatchQueue.main.async {
            self.sessionToken = nil
            self.currentUser = nil
        }
    }
    
    func signUp(email: String, password: String) async throws -> Session {
        guard let url = URL(string: "\(supabaseUrl)/auth/v1/signup") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("Auth API Sign Up failed with status \(httpResponse.statusCode): \(errorBody)")
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = errorDict["msg"] as? String {
                throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw URLError(.badServerResponse)
        }
        
        let session = try JSONDecoder().decode(Session.self, from: data)
        saveSession(session: session)
        return session
    }
    
    func signIn(email: String, password: String) async throws -> Session {
        guard let url = URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=password") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("Auth API Sign In failed with status \(httpResponse.statusCode): \(errorBody)")
            if let errorDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = errorDict["error_description"] as? String {
                throw NSError(domain: "AuthError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            throw URLError(.badServerResponse)
        }
        
        let session = try JSONDecoder().decode(Session.self, from: data)
        saveSession(session: session)
        return session
    }
}

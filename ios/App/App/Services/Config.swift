import Foundation

/// Configuration for external services (Supabase, etc.).
///
/// NOTE: For production apps, these values should ideally come from xcconfig files
/// that are not checked into source control, rather than hardcoded defaults here.
/// The Info.plist approach is acceptable for internal/test builds but should be
/// replaced with environment-specific configuration before shipping to production.
enum Config {
    /// Supabase project URL loaded from Info.plist or hardcoded fallback.
    static var supabaseUrl: String {
        Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? "https://brknoeqgpejhxsqsjnan.supabase.co"
    }

    /// Supabase anonymous public key loaded from Info.plist or hardcoded fallback.
    static var supabaseAnonKey: String {
        Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? "sb_publishable_SIqMFd0McVuxDH7u6V_1RA_okuvvVmT"
    }
}

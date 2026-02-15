import Foundation

typealias Level = String // A1, A2, etc.

struct Word: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let type: String // noun, verb, etc.
    let level: Level
    let phonetics: Phonetics
    let examples: [String]?
    
    // Computed property for backward compatibility or easy access
    var example: String? {
        examples?.first
    }
}

struct Phonetics: Codable, Hashable {
    let us: String?
    let uk: String?
}

// Extension to map from JSON key format if needed, or just clean init.

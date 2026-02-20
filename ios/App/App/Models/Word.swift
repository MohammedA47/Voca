import Foundation

typealias Level = String // A1, A2, etc.

struct Word: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    let type: String // noun, verb, etc.
    let level: Level
    let phonetics: Phonetics
    let examples: [String]?
    let definition: String?
    let example: String?
    let synonyms: [String]?
}

struct Phonetics: Codable, Hashable {
    let us: String?
    let uk: String?
}

// Extension to map from JSON key format if needed, or just clean init.

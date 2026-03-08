import Foundation

/// CEFR proficiency level (A1, A2, B1, B2, C1, C2).
typealias Level = String

/// A vocabulary word with pronunciation, examples, and metadata.
///
/// Words are loaded from the bundled `oxford_vocabulary.json` and displayed
/// on learn cards, search results, and detail screens.
struct Word: Codable, Identifiable, Hashable {
    let id: String
    let word: String
    /// Part of speech — e.g. "noun", "verb", "adjective".
    let type: String
    /// CEFR proficiency level this word belongs to.
    let level: Level
    /// IPA pronunciation strings for US and UK English.
    let phonetics: Phonetics
    /// Usage examples shown on the front of the learn card.
    let examples: [String]?
    /// Dictionary definition shown on the back of the learn card.
    let definition: String?
    /// A single example sentence (legacy field, prefer `examples`).
    let example: String?
    /// Related words with similar meaning.
    let synonyms: [String]?
}

/// IPA phonetic transcriptions for a word.
struct Phonetics: Codable, Hashable {
    /// US English IPA, e.g. "/əˈbaʊt/".
    let us: String?
    /// UK English IPA, e.g. "/əˈbaʊt/".
    let uk: String?
}

// MARK: - Preview Data

extension Word {
    /// A sample word for Xcode previews.
    static let preview = Word(
        id: "preview-achieve",
        word: "achieve",
        type: "verb",
        level: "B1",
        phonetics: Phonetics(us: "/əˈtʃiːv/", uk: "/əˈtʃiːv/"),
        examples: ["She achieved her goal of running a marathon.", "Hard work helps you achieve success."],
        definition: "To succeed in reaching a particular goal or standard by effort, skill, or courage.",
        example: "She achieved her goal of running a marathon.",
        synonyms: ["accomplish", "attain", "reach"]
    )
}

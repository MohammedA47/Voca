import Foundation

/// Loads and indexes the Oxford vocabulary JSON from the app bundle.
///
/// Provides O(1) lookups by ID and pre-grouped dictionaries by level and type.
@Observable
@MainActor
final class VocabularyService {
    static let shared = VocabularyService()

    var words: [Word] = []
    var isLoaded: Bool = false

    /// Words grouped by CEFR level for quick level-based filtering.
    var wordsByLevel: [Level: [Word]] = [:]
    /// Words grouped by part-of-speech type for search filtering.
    var wordsByType: [String: [Word]] = [:]
    /// Dictionary for O(1) ID lookups.
    var wordsById: [String: Word] = [:]

    private init() {
        Task {
            await loadWords()
        }
    }

    private func loadWords() async {
        guard let url = Bundle.main.url(forResource: "oxford_vocabulary", withExtension: "json") else {
            print("ERROR: oxford_vocabulary.json not found in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([Word].self, from: data)
            let byLevel = Dictionary(grouping: decoded, by: { $0.level })
            let byType = Dictionary(grouping: decoded, by: { $0.type })
            let byId = decoded.reduce(into: [String: Word]()) { result, word in result[word.id] = word }

            self.words = decoded
            self.wordsByLevel = byLevel
            self.wordsByType = byType
            self.wordsById = byId
            self.isLoaded = true
            print("Successfully loaded \(decoded.count) words.")
        } catch {
            print("ERROR: Failed to decode vocabulary: \(error)")
        }
    }
}

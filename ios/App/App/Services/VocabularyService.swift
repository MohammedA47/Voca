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
    var loadError: String? = nil

    /// Words grouped by CEFR level for quick level-based filtering.
    var wordsByLevel: [Level: [Word]] = [:]
    /// Words grouped by part-of-speech type for search filtering.
    var wordsByType: [String: [Word]] = [:]
    /// Dictionary for O(1) ID lookups.
    var wordsById: [String: Word] = [:]

    private var loadContinuation: CheckedContinuation<Void, Never>?

    private init() {
        Task {
            await loadWords()
        }
    }

    func reloadWords() async {
        await loadWords()
    }

    /// Waits until vocabulary is loaded using continuation-based async/await.
    ///
    /// If already loaded, returns immediately. Otherwise, suspends until loadWords() completes.
    func waitUntilLoaded() async {
        if isLoaded {
            return
        }

        await withCheckedContinuation { continuation in
            self.loadContinuation = continuation
        }
    }

    private func loadWords() async {
        guard let url = Bundle.main.url(forResource: "oxford_vocabulary", withExtension: "json") else {
            let errorMsg = "oxford_vocabulary.json not found in bundle."
            print("ERROR: \(errorMsg)")
            self.loadError = errorMsg
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
            self.loadError = nil
            print("Successfully loaded \(decoded.count) words.")

            // Resume any waiters
            self.loadContinuation?.resume()
            self.loadContinuation = nil
        } catch {
            let errorMsg = "Failed to decode vocabulary: \(error)"
            print("ERROR: \(errorMsg)")
            self.loadError = errorMsg

            // Resume waiters even on error
            self.loadContinuation?.resume()
            self.loadContinuation = nil
        }
    }
}

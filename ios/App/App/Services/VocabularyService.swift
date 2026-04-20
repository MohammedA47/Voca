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

    private var loadContinuations: [CheckedContinuation<Void, Never>] = []

    private init() {
        Task {
            await loadWords()
        }
    }

    func reloadWords() async {
        await loadWords(force: true)
    }

    /// Waits until vocabulary is loaded using continuation-based async/await.
    ///
    /// If already loaded, returns immediately. Otherwise, suspends until loadWords() completes.
    func waitUntilLoaded() async {
        if isLoaded {
            return
        }

        await withCheckedContinuation { continuation in
            loadContinuations.append(continuation)
        }
    }

    private func loadWords(force: Bool = false) async {
        if isLoaded && !force { return }

        guard let url = Bundle.main.url(forResource: "oxford_vocabulary", withExtension: "json") else {
            let errorMsg = "oxford_vocabulary.json not found in bundle."
            print("ERROR: \(errorMsg)")
            loadError = errorMsg
            resumeWaiters()
            return
        }

        do {
            let snapshot = try await Task.detached(priority: .userInitiated) {
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                let decoded = try JSONDecoder().decode([Word].self, from: data)
                let byLevel = Dictionary(grouping: decoded, by: \.level)
                let byType = Dictionary(grouping: decoded, by: \.type)
                let byId = decoded.reduce(into: [String: Word]()) { result, word in
                    result[word.id] = word
                }
                return VocabularySnapshot(
                    words: decoded,
                    wordsByLevel: byLevel,
                    wordsByType: byType,
                    wordsById: byId
                )
            }.value

            words = snapshot.words
            wordsByLevel = snapshot.wordsByLevel
            wordsByType = snapshot.wordsByType
            wordsById = snapshot.wordsById
            isLoaded = true
            loadError = nil
            print("Successfully loaded \(snapshot.words.count) words.")
            resumeWaiters()
        } catch {
            let errorMsg = "Failed to decode vocabulary: \(error)"
            print("ERROR: \(errorMsg)")
            loadError = errorMsg
            resumeWaiters()
        }
    }

    private func resumeWaiters() {
        let continuations = loadContinuations
        loadContinuations.removeAll(keepingCapacity: false)
        continuations.forEach { $0.resume() }
    }
}

private struct VocabularySnapshot {
    let words: [Word]
    let wordsByLevel: [Level: [Word]]
    let wordsByType: [String: [Word]]
    let wordsById: [String: Word]
}

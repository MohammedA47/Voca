import AppIntents
import CoreSpotlight
import Foundation

// MARK: - Learn Word Intent

/// Opens the app to the Learn tab so the user can study vocabulary.
struct LearnWordIntent: AppIntent {
    static let title: LocalizedStringResource = "Learn a Word"
    static let description: IntentDescription = "Opens Oxford Pronunciation to study vocabulary words."
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // The app will open to the LearnView by default
        return .result()
    }
}

// MARK: - Search Word Intent

/// Searches for a specific word in the vocabulary.
struct SearchWordIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Word"
    static let description: IntentDescription = "Look up a word in Oxford Pronunciation and hear its pronunciation."
    static let openAppWhenRun = true

    @Parameter(title: "Word")
    var word: String

    func perform() async throws -> some IntentResult {
        // Open search with the given word
        return .result()
    }
}

// MARK: - App Shortcuts Provider

/// Registers shortcuts that appear in the Shortcuts app and Spotlight.
struct PronunciationAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LearnWordIntent(),
            phrases: [
                "Learn a word in \(.applicationName)",
                "Study vocabulary in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: "Learn a Word",
            systemImageName: "book.fill"
        )
    }
}

// MARK: - Spotlight Indexing

/// Indexes vocabulary words in Core Spotlight for system-wide search.
enum SpotlightIndexer {
    private static let indexedVocabularyCountKey = "spotlightIndexedVocabularyCount"

    /// Call once after vocabulary loads to index all words in batches.
    static func indexAllWordsIfNeeded() async {
        let words = await MainActor.run { () -> [Word] in
            let vocabularyService = VocabularyService.shared
            guard vocabularyService.isLoaded else { return [] }
            return vocabularyService.words
        }
        let totalWords = words.count
        guard totalWords > 0 else { return }
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: indexedVocabularyCountKey) != totalWords else { return }

        let batchSize = 500
        let batches = stride(from: 0, to: words.count, by: batchSize).map { batchStart in
            let batchEnd = min(batchStart + batchSize, words.count)
            return words[batchStart..<batchEnd].map { word -> CSSearchableItem in
                let attributes = CSSearchableItemAttributeSet(contentType: .text)
                attributes.title = word.word.capitalized
                attributes.contentDescription = "\(word.type) (\(word.level)) — \(word.definition ?? "Learn this word")"
                attributes.keywords = [word.word, word.type, word.level]

                return CSSearchableItem(
                    uniqueIdentifier: "word-\(word.id)",
                    domainIdentifier: "com.oxford.pronunciation.words",
                    attributeSet: attributes
                )
            }
        }

        do {
            try await Task.detached(priority: .utility) {
                let searchableIndex = CSSearchableIndex.default()
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    searchableIndex.deleteSearchableItems(withDomainIdentifiers: ["com.oxford.pronunciation.words"]) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }

                for items in batches {
                    try Task.checkCancellation()
                    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                        searchableIndex.indexSearchableItems(items) { error in
                            if let error {
                                continuation.resume(throwing: error)
                            } else {
                                continuation.resume()
                            }
                        }
                    }
                }
            }.value

            defaults.set(totalWords, forKey: indexedVocabularyCountKey)
        } catch {
            print("Spotlight indexing error: \(error.localizedDescription)")
        }
    }
}

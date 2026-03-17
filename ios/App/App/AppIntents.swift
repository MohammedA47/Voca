import AppIntents
import CoreSpotlight

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
@MainActor
enum SpotlightIndexer {
    /// Call once after vocabulary loads to index all words in batches.
    static func indexAllWords() {
        let vocabularyService = VocabularyService.shared
        guard vocabularyService.isLoaded else { return }

        let batchSize = 500
        let words = Array(vocabularyService.words)
        let totalWords = words.count
        let searchableIndex = CSSearchableIndex.default()
        var indexedCount = 0

        // Index words in batches of 500 to avoid memory spikes
        for batchStart in stride(from: 0, to: words.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, words.count)
            let batchWords = Array(words[batchStart..<batchEnd])

            let items = batchWords.map { word -> CSSearchableItem in
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

            searchableIndex.indexSearchableItems(items) { error in
                if let error {
                    print("Spotlight indexing error for batch [\(batchStart)-\(batchEnd)]: \(error.localizedDescription)")
                } else {
                    indexedCount += items.count
                    print("Indexed batch [\(batchStart)-\(batchEnd)]: \(items.count) words (\(indexedCount)/\(totalWords) total).")
                }
            }
        }
    }
}

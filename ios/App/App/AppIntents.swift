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
    /// Call once after vocabulary loads to index all words.
    static func indexAllWords() {
        let vocabularyService = VocabularyService.shared
        guard vocabularyService.isLoaded else { return }

        let items = vocabularyService.words.prefix(500).map { word -> CSSearchableItem in
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

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                print("Spotlight indexing error: \(error.localizedDescription)")
            } else {
                print("Indexed \(items.count) words in Spotlight.")
            }
        }
    }
}

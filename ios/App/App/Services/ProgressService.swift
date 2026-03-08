import Foundation

/// Tracks which words the user has learned and bookmarked.
///
/// Persists progress to `UserDefaults` so it survives app restarts.
@Observable
final class ProgressService {
    var learnedWords: Set<String> = []
    var bookmarkedWords: Set<String> = []

    private let learnedKey = "Oxford_LearnedWords"
    private let bookmarkedKey = "Oxford_BookmarkedWords"

    init() {
        loadProgress()
    }

    private func loadProgress() {
        if let learned = UserDefaults.standard.array(forKey: learnedKey) as? [String] {
            self.learnedWords = Set(learned)
        }

        if let bookmarked = UserDefaults.standard.array(forKey: bookmarkedKey) as? [String] {
            self.bookmarkedWords = Set(bookmarked)
        }
    }

    /// Marks a word as learned and persists the change.
    func markAsLearned(_ wordId: String) {
        learnedWords.insert(wordId)
        saveLearned()
    }

    /// Removes a word from the learned set.
    func unmarkLearned(_ wordId: String) {
        learnedWords.remove(wordId)
        saveLearned()
    }

    /// Toggles whether a word is bookmarked.
    func toggleBookmark(_ wordId: String) {
        if bookmarkedWords.contains(wordId) {
            bookmarkedWords.remove(wordId)
        } else {
            bookmarkedWords.insert(wordId)
        }
        saveBookmarks()
    }

    func isLearned(_ wordId: String) -> Bool {
        learnedWords.contains(wordId)
    }

    func isBookmarked(_ wordId: String) -> Bool {
        bookmarkedWords.contains(wordId)
    }

    private func saveLearned() {
        let array = Array(learnedWords)
        Task.detached(priority: .background) {
            UserDefaults.standard.set(array, forKey: self.learnedKey)
        }
    }

    private func saveBookmarks() {
        let array = Array(bookmarkedWords)
        Task.detached(priority: .background) {
            UserDefaults.standard.set(array, forKey: self.bookmarkedKey)
        }
    }
}

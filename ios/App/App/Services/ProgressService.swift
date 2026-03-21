import Foundation

/// Tracks which words the user has learned and bookmarked.
///
/// Persists progress to `UserDefaults` so it survives app restarts.
@Observable
final class ProgressService {
    /// Mapping of word ID to the date it was marked as learned.
    var learnedWords: [String: Date] = [:]
    var bookmarkedWords: Set<String> = []

    private let learnedKey = "Oxford_LearnedWords_V2" // Use new key for dictionary migration
    private let legacyLearnedKey = "Oxford_LearnedWords"
    private let bookmarkedKey = "Oxford_BookmarkedWords"

    init() {
        loadProgress()
    }

    private func loadProgress() {
        // Load learned words dictionary
        if let data = UserDefaults.standard.data(forKey: learnedKey),
           let learned = try? JSONDecoder().decode([String: Date].self, from: data) {
            self.learnedWords = learned
        } else if let legacy = UserDefaults.standard.array(forKey: legacyLearnedKey) as? [String] {
            // Migration: Assume legacy words were learned today
            self.learnedWords = Dictionary(uniqueKeysWithValues: legacy.map { ($0, Date()) })
            saveLearned()
        }

        if let bookmarked = UserDefaults.standard.array(forKey: bookmarkedKey) as? [String] {
            self.bookmarkedWords = Set(bookmarked)
        }
    }

    /// Marks a word as learned and persists the change.
    func markAsLearned(_ wordId: String) {
        learnedWords[wordId] = Date()
        saveLearned()
    }

    /// Removes a word from the learned set.
    func unmarkLearned(_ wordId: String) {
        learnedWords.removeValue(forKey: wordId)
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
        learnedWords[wordId] != nil
    }

    func isBookmarked(_ wordId: String) -> Bool {
        bookmarkedWords.contains(wordId)
    }

    /// Calculates the current daily learning streak.
    ///
    /// A streak is incremented for each consecutive day (working backwards from today)
    /// where at least one word was marked as learned.
    func calculateStreak() -> Int {
        guard !learnedWords.isEmpty else { return 0 }

        // Group learned dates by day (ignoring time)
        let calendar = Calendar.current
        let learnedDays = Set(learnedWords.values.map { calendar.startOfDay(for: $0) })
        
        let today = calendar.startOfDay(for: Date())
        var currentStreak = 0
        var checkDay = today

        // If nothing learned today, streak might still be alive if learned yesterday
        if !learnedDays.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                  learnedDays.contains(yesterday) else {
                return 0
            }
            checkDay = yesterday
        }

        // Count consecutive days backwards
        while learnedDays.contains(checkDay) {
            currentStreak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDay) else {
                break
            }
            checkDay = previousDay
        }

        return currentStreak
    }

    private func saveLearned() {
        if let data = try? JSONEncoder().encode(learnedWords) {
            Task.detached(priority: .background) {
                UserDefaults.standard.set(data, forKey: self.learnedKey)
            }
        }
    }

    private func saveBookmarks() {
        let array = Array(bookmarkedWords)
        Task.detached(priority: .background) {
            UserDefaults.standard.set(array, forKey: self.bookmarkedKey)
        }
    }
}

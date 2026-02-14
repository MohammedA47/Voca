import Foundation

class ProgressService: ObservableObject {
    @Published var learnedWords: Set<String> = []
    @Published var bookmarkedWords: Set<String> = []
    
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
    
    func markAsLearned(_ wordId: String) {
        learnedWords.insert(wordId)
        saveLearned()
    }
    
    func unmarkLearned(_ wordId: String) {
        learnedWords.remove(wordId)
        saveLearned()
    }
    
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
        UserDefaults.standard.set(Array(learnedWords), forKey: learnedKey)
    }
    
    private func saveBookmarks() {
        UserDefaults.standard.set(Array(bookmarkedWords), forKey: bookmarkedKey)
    }
}

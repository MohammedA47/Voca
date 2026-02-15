import Foundation

class VocabularyService: ObservableObject {
    @Published var words: [Word] = []
    
    // Grouped by level for easy access
    var wordsByLevel: [Level: [Word]] = [:]
    
    init() {
        loadWords()
    }
    
    private func loadWords() {
        guard let url = Bundle.main.url(forResource: "oxford_vocabulary", withExtension: "json") else {
            print("ERROR: oxford_vocabulary.json not found in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            self.words = try decoder.decode([Word].self, from: data)
            self.groupWords()
            print("Successfully loaded \(words.count) words.")
        } catch {
            print("ERROR: Failed to decode vocabulary: \(error)")
        }
    }
    
    private func groupWords() {
        self.wordsByLevel = Dictionary(grouping: words, by: { $0.level })
    }
}

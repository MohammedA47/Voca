import Foundation

class VocabularyService: ObservableObject {
    static let shared = VocabularyService()
    
    @Published var words: [Word] = []
    @Published var isLoaded: Bool = false
    
    // Grouped by level for easy access
    var wordsByLevel: [Level: [Word]] = [:]
    // Grouped by type for fast search filtering
    var wordsByType: [String: [Word]] = [:]
    
    private init() {
        Task.detached(priority: .userInitiated) { [weak self] in
            self?.loadWords()
        }
    }
    
    private func loadWords() {
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
            
            DispatchQueue.main.async { [weak self] in
                self?.words = decoded
                self?.wordsByLevel = byLevel
                self?.wordsByType = byType
                self?.isLoaded = true
                print("Successfully loaded \(decoded.count) words.")
            }
        } catch {
            print("ERROR: Failed to decode vocabulary: \(error)")
        }
    }
}

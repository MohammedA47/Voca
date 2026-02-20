import SwiftUI
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedWordType: String? = nil
    @Published var filteredWords: [Word] = []
    
    private let vocabularyService = VocabularyService()
    private var cancellables = Set<AnyCancellable>()
    
    var allWordTypes: [String] {
        let counts = Dictionary(grouping: vocabularyService.words, by: { $0.type }).mapValues { $0.count }
        return counts.keys.sorted { counts[$0, default: 0] > counts[$1, default: 0] }
    }
    
    init() {
        // Debounce search text
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.filterWords()
            }
            .store(in: &cancellables)
        
        // React to type filter changes
        $selectedWordType
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.filterWords()
            }
            .store(in: &cancellables)
            
        // Initial load
        filterWords()
    }
    
    private func filterWords() {
        var results = vocabularyService.words
        
        if !searchText.isEmpty {
            results = results.filter {
                $0.word.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if let type = selectedWordType {
            results = results.filter { $0.type == type }
        }
        
        self.filteredWords = results
    }
}

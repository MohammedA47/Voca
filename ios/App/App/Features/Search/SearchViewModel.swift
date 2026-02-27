import SwiftUI
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedWordType: String? = nil
    @Published var filteredWords: [Word] = []
    
    private let vocabularyService = VocabularyService.shared
    private var cancellables = Set<AnyCancellable>()
    
    var allWordTypes: [String] {
        // Use pre-built wordsByType for O(1) access
        let counts = vocabularyService.wordsByType.mapValues { $0.count }
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
        
        // Reload when vocabulary finishes async loading
        vocabularyService.$isLoaded
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .first()
            .sink { [weak self] _ in
                self?.filterWords()
            }
            .store(in: &cancellables)
            
        // Initial load (if already loaded)
        if vocabularyService.isLoaded {
            filterWords()
        }
    }
    
    private func filterWords() {
        // Start from type-filtered subset if a type is selected (faster)
        var results: [Word]
        if let type = selectedWordType {
            results = vocabularyService.wordsByType[type] ?? []
        } else {
            results = vocabularyService.words
        }
        
        if !searchText.isEmpty {
            results = results.filter {
                $0.word.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        self.filteredWords = results
    }
}


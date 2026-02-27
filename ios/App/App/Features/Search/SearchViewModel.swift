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
        let currentSearchText = searchText
        let currentType = selectedWordType
        let wordsByType = vocabularyService.wordsByType
        let allWords = vocabularyService.words
        
        Task.detached(priority: .userInitiated) { [weak self] in
            var results: [Word]
            if let type = currentType {
                results = wordsByType[type] ?? []
            } else {
                results = allWords
            }
            
            if !currentSearchText.isEmpty {
                results = results.filter {
                    $0.word.localizedCaseInsensitiveContains(currentSearchText)
                }
            }
            
            let finalResults = results
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Only update if search text hasn't changed while we were filtering
                if self.searchText == currentSearchText && self.selectedWordType == currentType {
                    self.filteredWords = finalResults
                }
            }
        }
    }
}


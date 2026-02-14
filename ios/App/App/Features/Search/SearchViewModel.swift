import SwiftUI
import Combine

class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var filteredWords: [Word] = []
    
    private let vocabularyService = VocabularyService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Debounce search
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.filterWords()
            }
            .store(in: &cancellables)
            
        // Initial load
        filterWords()
    }
    
    private func filterWords() {
        if searchText.isEmpty {
            self.filteredWords = vocabularyService.words
        } else {
            self.filteredWords = vocabularyService.words.filter { 
                $0.word.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
}

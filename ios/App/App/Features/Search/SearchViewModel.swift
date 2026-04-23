import SwiftUI

/// Handles debounced search and type-based filtering for the vocabulary search tab.
@Observable
@MainActor
final class SearchViewModel {
    var searchText: String = "" {
        didSet { scheduleFilter() }
    }
    var selectedWordType: String? = nil {
        didSet { filterWords() }
    }
    var filteredWords: [Word] = []

    private let vocabularyService = VocabularyService.shared

    var allWordTypes: [String] {
        let counts = vocabularyService.wordsByType.mapValues { $0.count }
        return counts.keys.sorted { counts[$0, default: 0] > counts[$1, default: 0] }
    }

    private var filterTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?

    init() {
        if vocabularyService.isLoaded {
            filterWords()
        } else {
            initialLoadTask = Task { [weak self] in
                await self?.vocabularyService.waitUntilLoaded()
                guard let self else { return }
                self.filterWords()
            }
        }
    }

    private func scheduleFilter() {
        filterTask?.cancel()
        filterTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            filterWords()
        }
    }

    private func filterWords() {
        filterTask?.cancel()
        let currentSearchText = searchText
        let currentType = selectedWordType
        let wordsByType = vocabularyService.wordsByType
        let allWords = vocabularyService.words

        filterTask = Task.detached(priority: .userInitiated) { [weak self] in
            let base: [Word]
            if let type = currentType {
                base = wordsByType[type] ?? []
            } else {
                base = allWords
            }

            let results: [Word]
            let trimmed = currentSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                results = base
            } else {
                results = base.filter {
                    $0.word.range(of: trimmed, options: .caseInsensitive) != nil
                }
            }

            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self = self else { return }
                if self.searchText == currentSearchText && self.selectedWordType == currentType {
                    self.filteredWords = results
                }
            }
        }
    }
}

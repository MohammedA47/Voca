import Foundation

class VocabularyService: ObservableObject {
    @Published var words: [Word] = []
    
    // Grouped by level for easy access
    var wordsByLevel: [Level: [Word]] = [:]
    
    init() {
        loadWords()
    }
    
    private func loadWords() {
        // ideally load from Bundle.main.url(forResource: "oxford_vocabulary", withExtension: "json")
        // For now we will mock some data or expect the user to provide the JSON file.
        // I will create a small subset of data for testing.
        self.words = MockData.words
        self.groupWords()
    }
    
    private func groupWords() {
        self.wordsByLevel = Dictionary(grouping: words, by: { $0.level })
    }
}

// TODO: Replace with real JSON loading
struct MockData {
    static let words: [Word] = [
        Word(id: "1", word: "Ability", type: "noun", level: "A2", phonetics: Phonetics(us: "/əˈbɪləti/", uk: "/əˈbɪləti/"), example: "She has the ability to pass the test."),
        Word(id: "2", word: "Able", type: "adjective", level: "A2", phonetics: Phonetics(us: "/ˈeɪbl/", uk: "/ˈeɪbl/"), example: "You must be able to speak English."),
        Word(id: "3", word: "About", type: "preposition", level: "A1", phonetics: Phonetics(us: "/əˈbaʊt/", uk: "/əˈbaʊt/"), example: "Tell me about yourself.")
    ]
}

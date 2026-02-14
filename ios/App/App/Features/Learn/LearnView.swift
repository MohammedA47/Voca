import SwiftUI

struct LearnView: View {
    @StateObject private var viewModel = LearnViewModel()
    @EnvironmentObject var progressService: ProgressService
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Level Selection Header
                        LevelSelector(selectedLevel: $viewModel.selectedLevel)
                        
                        if let currentWord = viewModel.currentWord {
                            WordCardView(word: currentWord,
                                         isBookmarked: viewModel.isBookmarked,
                                         onPlay: viewModel.playAudio, 
                                         onNext: viewModel.nextWord,
                                         onPrevious: viewModel.previousWord,
                                         onBookmark: viewModel.toggleBookmark)
                                .transition(.scale)
                        } else {
                            ContentUnavailableView("No words found", systemImage: "text.book.closed")
                        }
                    }
                    .padding()
                }
            }
            .onAppear {
                viewModel.setProgressService(progressService)
            }
            .navigationTitle("Learn")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: viewModel.toggleSettings) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
}

class LearnViewModel: ObservableObject {
    @Published var selectedLevel: String = "A1" {
        didSet {
            loadWordsForLevel()
        }
    }
    @Published var currentWord: Word?
    
    private var words: [Word] = []
    private var currentIndex: Int = 0
    private let vocabularyService = VocabularyService()
    // In a real app, use Dependency Injection. Passing via init for simplicity.
    private var progressService: ProgressService?
    
    // Audio player placeholder
    // private let audioPlayer = AudioPlayer()
    
    init(progressService: ProgressService? = nil) {
        self.progressService = progressService
        loadWordsForLevel()
    }
    
    func setProgressService(_ service: ProgressService) {
        self.progressService = service
    }
    
    private func loadWordsForLevel() {
        self.words = vocabularyService.wordsByLevel[selectedLevel] ?? []
        self.currentIndex = 0
        self.currentWord = words.first
    }
    
    var isBookmarked: Bool {
        guard let id = currentWord?.id, let service = progressService else { return false }
        return service.isBookmarked(id)
    }
    
    func toggleBookmark() {
        guard let id = currentWord?.id, let service = progressService else { return }
        service.toggleBookmark(id)
        objectWillChange.send() // Force UI update
    }
    
    func playAudio() {
        guard let word = currentWord else { return }
        AudioService.shared.speak(text: word.word)
    }
    
    func nextWord() {
        guard !words.isEmpty else { return }
        if currentIndex < words.count - 1 {
            currentIndex += 1
        } else {
            currentIndex = 0 // Loop back or show completion
        }
        updateCurrentWord()
    }
    
    func previousWord() {
        guard !words.isEmpty else { return }
        if currentIndex > 0 {
            currentIndex -= 1
        } else {
            currentIndex = words.count - 1
        }
        updateCurrentWord()
    }
    
    private func updateCurrentWord() {
        withAnimation {
            self.currentWord = words[currentIndex]
        }
    }
    
    func toggleSettings() {
        // Show settings sheet
    }
}

struct LevelSelector: View {
    @Binding var selectedLevel: String
    let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                foreachLevel
            }
            .padding(.horizontal, 4)
        }
    }
    
    var foreachLevel: some View {
        ForEach(levels, id: \.self) { level in
            Button(action: {
                withAnimation { selectedLevel = level }
            }) {
                Text(level)
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedLevel == level ? Color.brandPrimary : Color.surface)
                    .foregroundColor(selectedLevel == level ? .white : .webForeground)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle()) // remove default flash
        }
    }
}

struct WordCardView: View {
    let word: Word
    var isBookmarked: Bool
    var onPlay: () -> Void
    var onNext: () -> Void
    var onPrevious: () -> Void
    var onBookmark: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(spacing: 24) {
                // Top Actions
                HStack {
                    Spacer()
                    Button(action: onBookmark) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.title2)
                            .foregroundColor(isBookmarked ? .accentColor : .secondary)
                    }
                }
                
                // Word Header
                VStack(spacing: 8) {
                    Text(word.word)
                        .font(.oxfordDisplay(size: 48))
                        .foregroundColor(.webForeground)
                    
                    HStack {
                        Text(word.type)
                            .italic()
                            .font(.oxfordBody(size: 18))
                            .foregroundColor(.webSecondary) // Pinkish secondary
                        
                        Divider().frame(height: 12)
                        
                        Text(word.phonetics.us ?? "")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Audio Control
                Button(action: onPlay) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.webPrimary)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(color: .webPrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                
                Divider()
                
                // Example
                if let example = word.example {
                    Text(example)
                        .font(.oxfordDisplay(size: 20)) // Using Display font for example for elegance
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .foregroundColor(.webForeground.opacity(0.8))
                }
                
                // Navigation Controls
                HStack {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.secondary)
                    
                    Spacer()
                    
                    Button("Next", action: onNext)
                        .buttonStyle(.primary)
                        .frame(width: 120)
                }
                .padding(.top)
            }
            .padding()
        }
    }
}

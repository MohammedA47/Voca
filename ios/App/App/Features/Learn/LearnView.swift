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
                                         index: viewModel.currentIndex,
                                         total: viewModel.totalWords,
                                         isBookmarked: viewModel.isBookmarked,
                                         isLearned: viewModel.isLearned,
                                         onPlay: viewModel.playAudio,
                                         onNext: viewModel.nextWord,
                                         onPrevious: viewModel.previousWord,
                                         onBookmark: viewModel.toggleBookmark,
                                         onToggleLearned: viewModel.toggleLearned)
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
    var currentIndex: Int = 0 
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
    
    var isLearned: Bool {
        guard let id = currentWord?.id, let service = progressService else { return false }
        return service.isLearned(id)
    }
    
    var totalWords: Int {
        words.count
    }
    
    func toggleBookmark() {
        guard let id = currentWord?.id, let service = progressService else { return }
        service.toggleBookmark(id)
        objectWillChange.send() // Force UI update
    }
    
    func toggleLearned() {
        guard let id = currentWord?.id, let service = progressService else { return }
        if service.isLearned(id) {
            service.unmarkLearned(id)
        } else {
            service.markAsLearned(id)
        }
        objectWillChange.send()
    }
    
    func playAudio() {
        guard let word = currentWord else { return }
        AudioService.shared.speak(text: word.word)
    }
    
    func nextWord() {
        guard !words.isEmpty else { return }
        // Simple sequential navigation
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
    let index: Int
    let total: Int
    var isBookmarked: Bool
    var isLearned: Bool
    var onPlay: () -> Void
    var onNext: () -> Void
    var onPrevious: () -> Void
    var onBookmark: () -> Void
    var onToggleLearned: () -> Void
    
    @State private var currentExampleIndex = 0
    
    var body: some View {
        GlassCard {
            VStack(spacing: 12) {
                // Top Row: Count & Bookmark
                HStack {
                    Text("WORD \(index + 1) OF \(total)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .tracking(1)
                    
                    Spacer()
                    
                    Button(action: onBookmark) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.title3)
                            .foregroundColor(isBookmarked ? .webPrimary : .secondary)
                    }
                }
                
                // Word Row with Navigation
                HStack(spacing: 16) {
                    Button(action: onPrevious) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(word.word)
                        .font(.oxfordDisplay(size: 48))
                        .foregroundColor(.webForeground)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    
                    Button(action: onNext) {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
                
                // Phonetics Row
                HStack(spacing: 8) {
                    Text("US")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.webPrimary)
                    
                    Text(word.phonetics.us ?? "/.../")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Button(action: onPlay) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.subheadline)
                            .foregroundColor(.webPrimary)
                    }
                }
                
                // Type / Part of Speech Pill
                HStack(spacing: 4) {
                    Image(systemName: "book")
                        .font(.caption)
                    Text(word.type)
                        .italic()
                        .font(.oxfordBody(size: 14))
                }
                .foregroundColor(.webForeground)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(Color.webPrimary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Divider()
                    .padding(.vertical, 4)
                
                // Example Carousel
                if let examples = word.examples, !examples.isEmpty {
                    VStack(spacing: 8) {
                        // Example Nav
                        HStack {
                            Button(action: {
                                withAnimation {
                                    currentExampleIndex = (currentExampleIndex - 1 + examples.count) % examples.count
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Example \(currentExampleIndex + 1) of \(examples.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                withAnimation {
                                    currentExampleIndex = (currentExampleIndex + 1) % examples.count
                                }
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Example Text
                        Text("\"" + examples[currentExampleIndex] + "\"")
                            .font(.oxfordDisplay(size: 18))
                            .italic()
                            .multilineTextAlignment(.center)
                            .foregroundColor(.webForeground.opacity(0.9))
                            .frame(height: 60) // Reduced fixed height
                            .id("example-\(word.id)-\(currentExampleIndex)")
                            .transition(.opacity)
                    }
                } else {
                    Text("No examples available")
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary)
                        .padding(.vertical, 20)
                }
                
                Spacer(minLength: 0) // Allow collapsing if needed
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: onPlay) {
                        Label("Listen", systemImage: "speaker.wave.3")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.webForeground)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.webBorder, lineWidth: 1)
                            )
                    }
                    
                    Button(action: {}) {
                        Label("Example", systemImage: "text.book.closed")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.webForeground)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.webBorder, lineWidth: 1)
                            )
                    }
                }
                
                // Mark as Learned
                Button(action: onToggleLearned) {
                    HStack {
                        Image(systemName: isLearned ? "checkmark.circle.fill" : "checkmark.circle")
                        Text(isLearned ? "Learned" : "Mark as Learned")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(colors: [.webPrimary, .webPrimary.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: .webPrimary.opacity(0.3), radius: 8, y: 4)
                }
            }
            .padding(16) // Reduced outer padding
        }
        .onChange(of: word.id) { _ in
            currentExampleIndex = 0
        }
    }
}

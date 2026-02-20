import SwiftUI

struct LearnView: View {
    @StateObject private var viewModel = LearnViewModel()
    @EnvironmentObject var progressService: ProgressService
    @State private var showAccountSheet = false
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.96, blue: 0.97),
                    Color(red: 0.95, green: 0.93, blue: 0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────
                HStack {
                    Text(viewModel.selectedLevel)
                        .font(.title2.bold())
                        .foregroundColor(.webPrimary)
                    
                    Spacer()
                    
                    Button {
                        // Haptic feedback on tap (matches Apple system apps)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        showAccountSheet = true
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.webPrimary)
                    }
                    .accessibilityLabel("Account")
                    .accessibilityHint("Opens your account panel")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)
                
                // ── Level Selector Pills ────────────────────
                LevelSelector(selectedLevel: $viewModel.selectedLevel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                
                // ── Main Card ───────────────────────────────
                if let currentWord = viewModel.currentWord {
                    ScrollView(.vertical, showsIndicators: false) {
                        WordCardView(
                            word: currentWord,
                            index: viewModel.currentIndex,
                            total: viewModel.totalWords,
                            isBookmarked: viewModel.isBookmarked,
                            isLearned: viewModel.isLearned,
                            onPlay: viewModel.playAudio,
                            onBookmark: viewModel.toggleBookmark,
                            onToggleLearned: viewModel.toggleLearned
                        )
                        .padding(.horizontal, 16)
                    }
                } else {
                    Spacer()
                    ContentUnavailableView("No words found", systemImage: "text.book.closed")
                    Spacer()
                }
                
                Spacer(minLength: 8)
                
                // ── Progress Bar ────────────────────────────
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.webPrimary.opacity(0.15))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(Color.webPrimary)
                                .frame(width: max(0, geo.size.width * CGFloat(viewModel.currentIndex + 1) / CGFloat(max(viewModel.totalWords, 1))), height: 6)
                        }
                    }
                    .frame(height: 6)
                    
                    HStack {
                        Text("STUDY PROGRESS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.8)
                        
                        Spacer()
                        
                        Text("\(viewModel.currentIndex + 1) / \(viewModel.totalWords) WORDS")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .tracking(0.8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // ── Playback Controls ───────────────────────
                HStack(spacing: 0) {
                    Button(action: viewModel.previousWord) {
                        Image(systemName: "chevron.left")
                            .font(.title2.bold())
                            .foregroundColor(.webPrimary)
                            .frame(width: 56, height: 56)
                    }
                    
                    Spacer()
                    
                    // Big Play Button
                    Button(action: viewModel.playAudio) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(
                                Circle()
                                    .fill(Color.webPrimary)
                                    .shadow(color: .webPrimary.opacity(0.35), radius: 12, y: 6)
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: viewModel.nextWord) {
                        Image(systemName: "chevron.right")
                            .font(.title2.bold())
                            .foregroundColor(.webPrimary)
                            .frame(width: 56, height: 56)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            viewModel.setProgressService(progressService)
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - ViewModel

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
    private var progressService: ProgressService?
    
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
    
    var totalWords: Int { words.count }
    
    func toggleBookmark() {
        guard let id = currentWord?.id, let service = progressService else { return }
        service.toggleBookmark(id)
        objectWillChange.send()
    }
    
    func toggleLearned() {
        guard let id = currentWord?.id, let service = progressService else { return }
        if service.isLearned(id) { service.unmarkLearned(id) }
        else { service.markAsLearned(id) }
        objectWillChange.send()
    }
    
    func playAudio() {
        guard let word = currentWord else { return }
        AudioService.shared.speak(text: word.word)
    }
    
    func nextWord() {
        guard !words.isEmpty else { return }
        currentIndex = (currentIndex + 1) % words.count
        updateCurrentWord()
    }
    
    func previousWord() {
        guard !words.isEmpty else { return }
        currentIndex = (currentIndex - 1 + words.count) % words.count
        updateCurrentWord()
    }
    
    private func updateCurrentWord() {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.currentWord = words[currentIndex]
        }
    }
    
    // Settings toggle removed — replaced by AccountSheetView
}

// MARK: - Level Selector

struct LevelSelector: View {
    @Binding var selectedLevel: String
    let levels = ["A1", "A2", "B1", "B2", "C1", "C2"]
    
    var body: some View {
        HStack(spacing: 10) {
            ForEach(levels, id: \.self) { level in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedLevel = level }
                }) {
                    Text(level)
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 48, height: 34)
                        .background(selectedLevel == level ? Color.webPrimary : Color.white.opacity(0.7))
                        .foregroundColor(selectedLevel == level ? .white : .webForeground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedLevel == level ? Color.clear : Color.black.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Word Card (Flippable)

struct WordCardView: View {
    let word: Word
    let index: Int
    let total: Int
    var isBookmarked: Bool
    var isLearned: Bool
    var onPlay: () -> Void
    var onBookmark: () -> Void
    var onToggleLearned: () -> Void
    
    @State private var isFlipped = false
    @State private var currentExampleIndex = 0
    
    private let cardHeight: CGFloat = 420
    
    var body: some View {
        ZStack {
            // ── FRONT FACE ──────────────────────────────
            CardFrontFace(
                word: word,
                isBookmarked: isBookmarked,
                isLearned: isLearned,
                cardHeight: cardHeight,
                onPlay: onPlay,
                onBookmark: onBookmark,
                onToggleLearned: onToggleLearned
            )
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            
            // ── BACK FACE ───────────────────────────────
            CardBackFace(
                word: word,
                cardHeight: cardHeight
            )
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(
                .degrees(isFlipped ? 0 : -180),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
        }
        .frame(height: cardHeight)
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }
        .onChange(of: word.id) { _ in
            // Reset to front when word changes
            isFlipped = false
            currentExampleIndex = 0
        }
    }
}

// MARK: - Card Front Face

private struct CardFrontFace: View {
    let word: Word
    var isBookmarked: Bool
    var isLearned: Bool
    let cardHeight: CGFloat
    var onPlay: () -> Void
    var onBookmark: () -> Void
    var onToggleLearned: () -> Void
    
    @State private var currentExampleIndex = 0
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 16) {
                // ── Word Title + Learned Circle ─────────────
                HStack(alignment: .top) {
                    Text(word.word.capitalized)
                        .font(.oxfordDisplay(size: 36))
                        .foregroundColor(.oxfordNavy)
                    
                    Spacer()
                    
                    Button(action: onToggleLearned) {
                        Circle()
                            .strokeBorder(isLearned ? Color.webPrimary : Color.secondary.opacity(0.3), lineWidth: 2)
                            .background(
                                Circle().fill(isLearned ? Color.webPrimary : Color.clear)
                            )
                            .frame(width: 28, height: 28)
                            .overlay(
                                isLearned
                                    ? Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                    : nil
                            )
                    }
                }
                
                // ── Phonetics ───────────────────────────────
                HStack(spacing: 8) {
                    Text(word.phonetics.us ?? "/.../")
                        .font(.system(size: 17, weight: .medium, design: .monospaced))
                        .foregroundColor(.webPrimary)
                    
                    Button(action: onPlay) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.callout)
                            .foregroundColor(.webPrimary)
                    }
                }
                
                // ── Part of Speech Pill ─────────────────────
                Text(word.type.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(6)
                
                // ── Usage Examples ──────────────────────────
                if let examples = word.examples, !examples.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("USAGE EXAMPLES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.webPrimary)
                                .tracking(1)
                            
                            Spacer()
                            
                            Text("\(currentExampleIndex + 1) of \(examples.count)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\"" + examples[currentExampleIndex] + "\"")
                                .font(.oxfordBody(size: 16))
                                .foregroundColor(.webForeground)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                                .id("front-ex-\(word.id)-\(currentExampleIndex)")
                            
                            HStack(spacing: 6) {
                                Button(action: onPlay) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.webPrimary)
                                }
                                
                                Spacer()
                                
                                ForEach(0..<min(examples.count, 5), id: \.self) { i in
                                    Circle()
                                        .fill(i == currentExampleIndex ? Color.webPrimary : Color.secondary.opacity(0.25))
                                        .frame(width: 7, height: 7)
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.97, green: 0.96, blue: 0.98))
                        )
                        .gesture(
                            DragGesture(minimumDistance: 30).onEnded { value in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if value.translation.width < -30 {
                                        currentExampleIndex = (currentExampleIndex + 1) % examples.count
                                    } else if value.translation.width > 30 {
                                        currentExampleIndex = (currentExampleIndex - 1 + examples.count) % examples.count
                                    }
                                }
                            }
                        )
                    }
                }
                
                Spacer(minLength: 0)
                
                // ── Tap Hint ────────────────────────────────
                HStack {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 13))
                        Text("Tap to see definition")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.secondary.opacity(0.5))
                    Spacer()
                }
                .padding(.bottom, 24)
            }
            .padding(22)
            
            // ── Bookmark Button (pinned bottom-left) ────
            Button(action: onBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.title3)
                    .foregroundColor(isBookmarked ? .webPrimary : .secondary.opacity(0.4))
            }
            .padding(.leading, 22)
            .padding(.bottom, 22)
        }
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 8)
        )
    }
}

// MARK: - Card Back Face

private struct CardBackFace: View {
    let word: Word
    let cardHeight: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ── Header ──────────────────────────────────
            HStack {
                Text(word.word.capitalized)
                    .font(.oxfordDisplay(size: 24))
                    .foregroundColor(.oxfordNavy)
                
                Spacer()
                
                // Part of Speech Pill
                Text(word.type.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.webPrimary)
                    .cornerRadius(6)
            }
            
            Divider()
                .background(Color.webPrimary.opacity(0.2))
            
            // ── Definition ──────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("DEFINITION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.webPrimary)
                    .tracking(1)
                
                Text(word.definition ?? "No definition available.")
                    .font(.oxfordBody(size: 17))
                    .foregroundColor(.webForeground)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                
                // ── Example ──────────────────────────────────
                if let example = word.example, !example.isEmpty {
                    Text("“\(example)”")
                        .font(.oxfordBody(size: 16))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // ── Synonyms ─────────────────────────────────
                if let synonyms = word.synonyms, !synonyms.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Synonyms:")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(synonyms, id: \.self) { syn in
                                    Text(syn)
                                        .font(.system(size: 14))
                                        .foregroundColor(.webForeground)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                    .padding(.top, 12)
                }
            }
            .padding(.top, 4)
            
            Spacer(minLength: 8)
            
            // ── Tap Hint ────────────────────────────────
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 13))
                    Text("Tap to flip back")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.secondary.opacity(0.5))
                Spacer()
            }
        }
        .padding(22)
        .frame(height: cardHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.97, green: 0.96, blue: 0.99)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.webPrimary.opacity(0.08), radius: 16, x: 0, y: 8)
        )
    }
}


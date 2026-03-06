import SwiftUI
import Combine

struct LearnView: View {
    @StateObject private var viewModel = LearnViewModel()
    @EnvironmentObject var progressService: ProgressService
    @State private var showAccountSheet = false
    @State private var dragOffset: CGFloat = 0
    @State private var cardScale: CGFloat = 1.0
    @State private var cardOpacity: Double = 1.0
    @State private var isTransitioning = false
    
    // Reusable haptic generators (Apple recommends pre-creating these)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [
                    Color.adaptiveBackground,
                    Color.adaptiveBackgroundEnd
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────
                LearnHeaderView(
                    selectedLevel: viewModel.selectedLevel,
                    selectedWordType: $viewModel.selectedWordType,
                    availableWordTypes: viewModel.availableWordTypes,
                    onAccountTapped: { showAccountSheet = true },
                    lightHaptic: lightHaptic
                )
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.sm + Spacing.xs)
                
                // ── Level Selector Pills ────────────────────
                LevelSelector(selectedLevel: $viewModel.selectedLevel)
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.md)
                    
                Spacer(minLength: 0)
                
                // ── Main Card (Swipeable) ───────────────────
                if let currentWord = viewModel.currentWord {
                    GeometryReader { geometry in
                        let screenW = geometry.size.width
                        let dragPct = dragOffset / screenW  // -1…0…1
                        
                        ZStack(alignment: .center) {
                            WordCardView(
                                word: currentWord,
                                index: viewModel.currentIndex,
                                total: viewModel.totalWords,
                                isBookmarked: viewModel.isBookmarked,
                                isLearned: viewModel.isLearned,
                                phoneticsMode: viewModel.phoneticsMode,
                                onPlay: { viewModel.playAudio() },
                                onPlayExample: { text in viewModel.playAudio(text: text) },
                                onBookmark: viewModel.toggleBookmark,
                                onToggleLearned: viewModel.toggleLearned
                            )
                            .padding(.horizontal, Spacing.md)
                            .padding(.top, Spacing.sm) // Reduced top padding slightly since it's centered now
                            .padding(.bottom, Spacing.sm)
                        }
                        // ── Card transforms ──
                        .offset(x: dragOffset)
                        .rotationEffect(
                            .degrees(Double(dragPct) * 12),
                            anchor: .bottom
                        )
                        .scaleEffect(cardScale)
                        .opacity(cardOpacity)
                        // ── Gesture ──
                        .allowsHitTesting(!isTransitioning)
                        .gesture(
                            DragGesture(minimumDistance: 25)
                                .onChanged { value in
                                    guard !isTransitioning else { return }
                                    if abs(value.translation.width) > abs(value.translation.height) {
                                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                                            dragOffset = value.translation.width
                                        }
                                    }
                                }
                                .onEnded { value in
                                    guard !isTransitioning else { return }
                                    let threshold: CGFloat = screenW * 0.2
                                    let velocity = value.predictedEndTranslation.width
                                    
                                    if value.translation.width < -threshold || velocity < -250 {
                                        performSwipe(direction: -1, screenWidth: screenW, action: viewModel.nextWord)
                                    } else if value.translation.width > threshold || velocity > 250 {
                                        performSwipe(direction: 1, screenWidth: screenW, action: viewModel.previousWord)
                                    } else {
                                        // Snap back with bounce
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                                            dragOffset = 0
                                        }
                                    }
                                }
                        )
                    }
                } else {
                    Spacer()
                    ContentUnavailableView("No words found", systemImage: "text.book.closed")
                    Spacer()
                }
                
                Spacer(minLength: 8)
                
                // ── Progress Bar ────────────────────────────
                LearnProgressView(
                    currentIndex: viewModel.currentIndex,
                    totalWords: viewModel.totalWords
                )
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
                
                // ── Play / Pause Button ─────────────────────
                PlayPronunciationView(
                    isPlayAnimating: viewModel.isPlayAnimating,
                    onPlayPause: { viewModel.togglePlayPause() },
                    lightHaptic: lightHaptic
                )
                .padding(.bottom, Spacing.xl)
            }
        }
        .onAppear {
            viewModel.setProgressService(progressService)
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Swipe Animation
    
    private func performSwipe(direction: CGFloat, screenWidth: CGFloat, action: @escaping () -> Void) {
        isTransitioning = true
        
        // Phase 1: Toss the card off-screen with rotation
        withAnimation(.easeIn(duration: 0.28)) {
            dragOffset = direction * screenWidth * 1.4
            cardOpacity = 0
        }
        
        // Phase 2: Swap the data while card is invisible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            action()
            mediumHaptic.impactOccurred()
            
            // Reset position, shrink for pop-in
            dragOffset = 0
            cardScale = 0.85
            cardOpacity = 0
            
            // Phase 3: Pop the new card in with scale + fade
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                cardScale = 1.0
                cardOpacity = 1.0
            }
            
            // Light secondary haptic for the "land"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                softHaptic.impactOccurred()
                isTransitioning = false
            }
        }
    }
}

// MARK: - Play Button Style

private struct PlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Phonetics Mode

enum PhoneticsMode: String {
    case us, uk
}

// MARK: - ViewModel

class LearnViewModel: ObservableObject {
    @Published var selectedLevel: String = "A1" {
        didSet {
            selectedWordType = nil
            loadWordsForLevel()
        }
    }
    @Published var selectedWordType: String? = nil {
        didSet {
            loadWordsForLevel()
        }
    }
    @Published var currentWord: Word?
    
    // Settings — synced via @AppStorage (no broad NotificationCenter listener needed)
    @AppStorage("isLooping") var isLooping: Bool = true
    @AppStorage("phoneticsMode") private var phoneticsModeRaw: String = "us"
    @AppStorage("playbackSpeed") var playbackSpeed: Double = 1.0
    @AppStorage("randomSpeedEnabled") var randomSpeedEnabled: Bool = false
    
    var phoneticsMode: PhoneticsMode {
        PhoneticsMode(rawValue: phoneticsModeRaw) ?? .us
    }
    
    @Published var isSpeaking: Bool = false
    @Published var isPlayAnimating: Bool = false
    
    private var speakingObserver: Any?
    private var animationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private var words: [Word] = []
    var currentIndex: Int = 0
    private let vocabularyService = VocabularyService.shared
    private var progressService: ProgressService?
    
    init(progressService: ProgressService? = nil) {
        self.progressService = progressService
        
        // If vocabulary is already loaded, populate immediately
        if vocabularyService.isLoaded {
            loadWordsForLevel()
        }
        
        // Observe when vocabulary finishes loading (async)
        vocabularyService.$isLoaded
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .first()
            .sink { [weak self] _ in
                self?.loadWordsForLevel()
            }
            .store(in: &cancellables)
        
        // Observe AudioService speaking state
        speakingObserver = AudioService.shared.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speaking in
                guard let self = self else { return }
                self.isSpeaking = speaking
                
                if self.isLooping {
                    // Loop mode: follow real speaking state
                    self.isPlayAnimating = speaking
                }
                // Non-loop mode: animation is handled by timer in togglePlayPause
            }
    }
    
    func setProgressService(_ service: ProgressService) {
        self.progressService = service
    }
    
    var availableWordTypes: [String] {
        let levelWords = vocabularyService.wordsByLevel[selectedLevel] ?? []
        let counts = Dictionary(grouping: levelWords, by: { $0.type }).mapValues { $0.count }
        return counts.keys.sorted { counts[$0, default: 0] > counts[$1, default: 0] }
    }
    
    private func loadWordsForLevel() {
        var levelWords = vocabularyService.wordsByLevel[selectedLevel] ?? []
        if let type = selectedWordType {
            levelWords = levelWords.filter { $0.type == type }
        }
        self.words = levelWords
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
    
    func playAudio(text: String? = nil) {
        guard let word = currentWord else { return }
        
        // Calculate effective speed
        var finalSpeed = playbackSpeed
        if randomSpeedEnabled {
            finalSpeed = 0.7 + Double.random(in: 0...0.5) // Ranges from 0.7 to 1.2
        }
        
        AudioService.shared.speak(
            text: text ?? word.word,
            accent: phoneticsMode.rawValue,
            speed: finalSpeed
        )
    }
    
    func togglePlayPause() {
        if isPlayAnimating {
            // Stop everything
            AudioService.shared.stop()
            animationTimer?.invalidate()
            animationTimer = nil
            withAnimation(.easeOut(duration: 0.2)) {
                isPlayAnimating = false
            }
        } else if isLooping {
            // Loop mode: animation follows real speech
            playAudio()
        } else {
            // Non-loop mode: animation follows real speech state instead of 1 second timer,
            // because network delays can make a fixed 1-second pulse inaccurate.
            playAudio()
            withAnimation(.easeInOut(duration: 0.25)) {
                isPlayAnimating = true
            }
        }
    }
    
    func nextWord() {
        guard !words.isEmpty else { return }
        if isLooping {
            currentIndex = (currentIndex + 1) % words.count
        } else {
            currentIndex = min(currentIndex + 1, words.count - 1)
        }
        updateCurrentWord()
    }
    
    func previousWord() {
        guard !words.isEmpty else { return }
        if isLooping {
            currentIndex = (currentIndex - 1 + words.count) % words.count
        } else {
            currentIndex = max(currentIndex - 1, 0)
        }
        updateCurrentWord()
    }
    
    private func updateCurrentWord() {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.currentWord = words[currentIndex]
        }
    }
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
                        .background(selectedLevel == level ? Color.webPrimary : Color.adaptivePillBackground)
                        .foregroundStyle(selectedLevel == level ? .white : .webForeground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedLevel == level ? Color.clear : Color.adaptivePillBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Word Type Selector

struct WordTypeSelector: View {
    @Binding var selectedType: String?
    let availableTypes: [String]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" pill
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedType = nil }
                }) {
                    Text("All")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(selectedType == nil ? Color.webPrimary : Color.adaptivePillBackground)
                        .foregroundStyle(selectedType == nil ? .white : .webForeground)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(selectedType == nil ? Color.clear : Color.adaptivePillBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                ForEach(availableTypes, id: \.self) { type in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedType = type }
                    }) {
                        Text(type.capitalized)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedType == type ? Color.webPrimary : Color.adaptivePillBackground)
                            .foregroundStyle(selectedType == type ? .white : .webForeground)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(selectedType == type ? Color.clear : Color.adaptivePillBorder, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
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
    var phoneticsMode: PhoneticsMode
    var onPlay: () -> Void
    var onPlayExample: (String) -> Void
    var onBookmark: () -> Void
    var onToggleLearned: () -> Void
    
    @State private var isFlipped = false
    @State private var currentExampleIndex = 0
    
    private let cardHeight: CGFloat = 420
    
    var body: some View {
        ZStack {
            if !isFlipped {
                // ── FRONT FACE ──────────────────────────────
                CardFrontFace(
                    word: word,
                    isBookmarked: isBookmarked,
                    isLearned: isLearned,
                    phoneticsMode: phoneticsMode,
                    cardHeight: cardHeight,
                    onPlay: onPlay,
                    onPlayExample: onPlayExample,
                    onBookmark: onBookmark,
                    onToggleLearned: onToggleLearned
                )
                .transition(.coverFlip())
            } else {
                // ── BACK FACE ───────────────────────────────
                CardBackFace(
                    word: word,
                    cardHeight: cardHeight
                )
                .transition(.coverFlip())
            }
        }
        .animation(.easeInOut(duration: 0.5), value: isFlipped)
        .frame(height: cardHeight)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isFlipped ? "Word card showing definition. Tap to flip back." : "Word card for \(word.word). Tap to see definition.")
        .onTapGesture {
            isFlipped.toggle()
        }
        .onChange(of: word.id) {
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
    var phoneticsMode: PhoneticsMode
    let cardHeight: CGFloat
    var onPlay: () -> Void
    var onPlayExample: (String) -> Void
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
                        .foregroundStyle(Color.oxfordNavy)
                    
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
                                        .foregroundStyle(.white)
                                    : nil
                            )
                    }
                }
                
                // ── Phonetics ───────────────────────────────
                HStack(spacing: 8) {
                    let phonetic = phoneticsMode == .uk
                        ? (word.phonetics.uk ?? word.phonetics.us ?? "/.../")
                        : (word.phonetics.us ?? word.phonetics.uk ?? "/.../")
                    
                    Text(phoneticsMode == .uk ? "UK" : "US")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.webPrimary.opacity(0.8))
                        .clipShape(.rect(cornerRadius: 4))
                    
                    Text(phonetic)
                        .font(.system(size: 17, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.webPrimary)
                    
                    Button(action: onPlay) {
                        Image(systemName: "speaker.wave.3.fill")
                            .font(.callout)
                            .foregroundStyle(Color.webPrimary)
                    }
                }
                
                // ── Part of Speech Pill ─────────────────────
                Text(word.type.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 6))
                
                // ── Usage Examples ──────────────────────────
                if let examples = word.examples, !examples.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("USAGE EXAMPLES")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.webPrimary)
                                .tracking(1)
                            
                            Spacer()
                            
                            Text("\(currentExampleIndex + 1) of \(examples.count)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\"" + examples[currentExampleIndex] + "\"")
                                .font(.oxfordBody(size: 16))
                                .foregroundStyle(Color.webForeground)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                                .id("front-ex-\(word.id)-\(currentExampleIndex)")
                            
                            HStack(spacing: 6) {
                                Button(action: { onPlayExample(examples[currentExampleIndex]) }) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.webPrimary)
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
                                .fill(Color.adaptiveCardBackgroundSecondary)
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
                
                // ── Hint ──────────────────────────────
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 13))
                            Text("Tap to see definition")
                                .font(.system(size: 13, weight: .medium))
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "hand.draw.fill")
                                .font(.system(size: 13))
                            Text("Swipe to navigate")
                                .font(.system(size: 13, weight: .medium))
                        }
                    }
                    .foregroundStyle(.secondary.opacity(0.5))
                    Spacer()
                }
                .padding(.bottom, 24)
            }
            .padding(22)
            
            // ── Bookmark Button (pinned bottom-left) ────
            Button(action: onBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.title3)
                    .foregroundStyle(isBookmarked ? Color.webPrimary : Color.secondary.opacity(0.4))
            }
            .padding(.leading, 22)
            .padding(.bottom, 22)
        }
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.adaptiveCardBackground)
                .shadow(color: Color.adaptiveCardShadow, radius: 16, x: 0, y: 8)
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
                    .foregroundStyle(Color.oxfordNavy)
                
                Spacer()
                
                // Part of Speech Pill
                Text(word.type.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.webPrimary)
                    .clipShape(.rect(cornerRadius: 6))
            }
            
            Divider()
                .background(Color.webPrimary.opacity(0.2))
            
            // ── Definition ──────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("DEFINITION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.webPrimary)
                    .tracking(1)
                
                Text(word.definition ?? "No definition available.")
                    .font(.oxfordBody(size: 17))
                    .foregroundStyle(Color.webForeground)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                
                // ── Example ──────────────────────────────────
                if let example = word.example, !example.isEmpty {
                    Text("“\(example)”")
                        .font(.oxfordBody(size: 16))
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // ── Synonyms ─────────────────────────────────
                if let synonyms = word.synonyms, !synonyms.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Synonyms:")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(synonyms, id: \.self) { syn in
                                    Text(syn)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Color.webForeground)
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
                .foregroundStyle(.secondary.opacity(0.5))
                Spacer()
            }
        }
        .padding(22)
        .frame(height: cardHeight, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [Color.adaptiveCardBackground, Color.adaptiveCardBackEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.adaptiveCardShadow, radius: 16, x: 0, y: 8)
        )
    }
}

// MARK: - Learn Progress View

struct LearnProgressView: View {
    let currentIndex: Int
    let totalWords: Int
    
    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.webPrimary.opacity(0.15))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(Color.webPrimary)
                        .frame(width: max(0, geo.size.width * CGFloat(currentIndex + 1) / CGFloat(max(totalWords, 1))), height: 6)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("STUDY PROGRESS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
                
                Spacer()
                
                Text("\(currentIndex + 1) / \(totalWords) WORDS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.8)
            }
        }
    }
}

// MARK: - Play Pronunciation View

struct PlayPronunciationView: View {
    let isPlayAnimating: Bool
    let onPlayPause: () -> Void
    let lightHaptic: UIImpactFeedbackGenerator
    
    var body: some View {
        Button {
            lightHaptic.impactOccurred()
            onPlayPause()
        } label: {
            HStack(spacing: 12) {
                // Animated speaker icon
                Image(systemName: isPlayAnimating ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolEffect(.variableColor.iterative, isActive: isPlayAnimating)
                    .contentTransition(.symbolEffect(.replace))
                
                Text(isPlayAnimating ? "Playing…" : "Play Pronunciation")
                    .font(.system(size: 16, weight: .semibold))
                    .contentTransition(.numericText())
                
                Image(systemName: isPlayAnimating ? "pause.fill" : "play.fill")
                    .font(.system(size: 14))
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(.white)
            .frame(height: 22)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isPlayAnimating
                                ? [Color.webPrimary.opacity(0.9), Color.webPrimary.opacity(0.6)]
                                : [Color.webPrimary, Color.webPrimary.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: .webPrimary.opacity(isPlayAnimating ? 0.5 : 0.35),
                        radius: isPlayAnimating ? 20 : 16,
                        y: 8
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.3), value: isPlayAnimating)
        }
        .buttonStyle(PlayButtonStyle())
    }
}

// MARK: - Learn Header View

struct LearnHeaderView: View {
    let selectedLevel: String
    @Binding var selectedWordType: String?
    let availableWordTypes: [String]
    let onAccountTapped: () -> Void
    let lightHaptic: UIImpactFeedbackGenerator
    
    var body: some View {
        HStack {
            Text(selectedLevel)
                .font(.title2.bold())
                .foregroundStyle(Color.webPrimary)
            
            if let type = selectedWordType {
                Text(type.capitalized)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.webPrimary)
                    .padding(.horizontal, Spacing.sm + 2)
                    .padding(.vertical, Spacing.xs + 1)
                    .background(Color.webPrimary.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            // ── Options Menu (Word Type Filter) ─────
            Menu {
                Button {
                    selectedWordType = nil
                } label: {
                    Label("All Types", systemImage: selectedWordType == nil ? "checkmark" : "")
                }
                
                Divider()
                
                ForEach(availableWordTypes, id: \.self) { type in
                    Button {
                        selectedWordType = type
                    } label: {
                        Label(type.capitalized, systemImage: selectedWordType == type ? "checkmark" : "")
                    }
                }
            } label: {
                Image(systemName: selectedWordType == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.webPrimary)
            }
            
            Button {
                lightHaptic.impactOccurred()
                onAccountTapped()
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 28))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.webPrimary)
            }
            .accessibilityLabel("Account")
            .accessibilityHint("Opens your account panel")
        }
    }
}

// MARK: - Cover Flip Transition

struct CoverFlipTransition: AnimatableModifier {
    var progress: Double
    var isInsertion: Bool
    var blurStrength: CGFloat = 3.5
    
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let angle = isInsertion ? (180 - 180 * progress) : (0 - 180 * progress)

        let blurAmount = blurForAngle(angle)

        return content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.7
            )
            .blur(radius: blurAmount)
            .opacity(abs(angle) > 90 ? 0 : 1)
    }

    private func blurForAngle(_ angle: Double) -> CGFloat {
        let normalized = min(abs(angle) / 90, 1)
        return CGFloat(normalized * blurStrength)
    }
}

extension AnyTransition {
    static func coverFlip(blurStrength: CGFloat = 3.5) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: CoverFlipTransition(progress: 0, isInsertion: true, blurStrength: blurStrength),
                identity: CoverFlipTransition(progress: 1, isInsertion: true, blurStrength: blurStrength)
            ),
            removal: .modifier(
                active: CoverFlipTransition(progress: 1, isInsertion: false, blurStrength: blurStrength),
                identity: CoverFlipTransition(progress: 0, isInsertion: false, blurStrength: blurStrength)
            )
        )
    }
}

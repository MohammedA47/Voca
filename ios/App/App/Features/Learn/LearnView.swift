import SwiftUI

struct LearnView: View {
    @State private var viewModel = LearnViewModel()
    @Environment(ProgressService.self) private var progressService
    @State private var showAccountSheet = false
    @State private var audioService = AudioService.shared

    // Reusable haptic generator for non-deck interactions
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

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

            ZStack(alignment: .top) {
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

                // ── Error State ──────────────────────────────
                if let errorMessage = viewModel.loadError {
                    VStack(spacing: 20) {
                        Spacer()

                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.red.opacity(0.7))

                        VStack(spacing: 12) {
                            Text("Couldn't Load Words")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.primary)

                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, Spacing.md)
                        }

                        Button(action: { viewModel.retryLoadWords() }) {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(height: 44)
                                .frame(maxWidth: .infinity)
                                .background(Color.webPrimary)
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, Spacing.md)

                        Spacer()
                    }
                }
                // ── Stacked Card Deck ───────────────────────
                else if viewModel.totalWords > 0 {
                    StackedCardDeck(
                        itemCount: viewModel.totalWords,
                        currentIndex: $viewModel.currentIndex,
                        isLooping: viewModel.isLooping,
                        itemId: { index in viewModel.wordId(at: index) }
                    ) { index in
                        WordCardView(
                            word: viewModel.word(at: index),
                            index: index,
                            total: viewModel.totalWords,
                            isBookmarked: viewModel.isBookmarked(for: index),
                            isLearned: viewModel.isLearned(for: index),
                            phoneticsMode: viewModel.phoneticsMode,
                            onPlay: { viewModel.playAudio() },
                            onPlayExample: { text in viewModel.playAudio(text: text) },
                            onBookmark: { viewModel.toggleBookmark(for: index) },
                            onToggleLearned: { viewModel.toggleLearned(for: index) }
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)
                        .padding(.bottom, Spacing.sm)
                    }
                } else {
                    Spacer()
                    ContentUnavailableView("No words found", systemImage: "text.book.closed")
                    Spacer()
                }

                Spacer(minLength: 8)

                // ── Progress Bar ────────────────────────────
                if viewModel.loadError == nil {
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

                // ── Audio Error Toast Overlay ──────────────
                if let audioError = audioService.lastError {
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(Color.orange)

                            Text(audioError)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white)

                            Spacer()
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.orange.opacity(0.9))

                        Spacer()
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            withAnimation {
                                audioService.lastError = nil
                            }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .onAppear {
            viewModel.setProgressService(progressService)
        }
        .onChange(of: audioService.isSpeaking) { oldValue, newValue in
            viewModel.isSpeaking = newValue
            if viewModel.isLooping {
                // When audio finishes in loop mode, replay after gap (only if still in play state)
                if oldValue && !newValue && viewModel.isPlayAnimating {
                    Task {
                        try? await Task.sleep(for: .seconds(viewModel.loopGapSeconds))
                        if viewModel.isPlayAnimating {
                            viewModel.playAudio()
                        }
                    }
                }
            } else {
                // Non-loop mode: button follows audio state directly
                viewModel.isPlayAnimating = newValue
            }
        }
        .sheet(isPresented: $showAccountSheet) {
            AccountSheetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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

@Observable
@MainActor
final class LearnViewModel {
    var selectedLevel: String = "A1" {
        didSet {
            selectedWordType = nil
            loadWordsForLevel()
        }
    }
    var selectedWordType: String? = nil {
        didSet {
            loadWordsForLevel()
        }
    }

    // Settings — synced via @AppStorage (excluded from @Observable tracking)
    @ObservationIgnored @AppStorage("isLooping") var isLooping: Bool = false
    @ObservationIgnored @AppStorage("phoneticsMode") private var phoneticsModeRaw: String = "us"
    @ObservationIgnored @AppStorage("playbackSpeed") var playbackSpeed: Double = 1.0
    @ObservationIgnored @AppStorage("randomSpeedEnabled") var randomSpeedEnabled: Bool = false
    @ObservationIgnored @AppStorage("loopGapSeconds") var loopGapSeconds: Double = 1.0

    var phoneticsMode: PhoneticsMode {
        PhoneticsMode(rawValue: phoneticsModeRaw) ?? .us
    }

    var isSpeaking: Bool = false
    var isPlayAnimating: Bool = false

    private var words: [Word] = []
    var currentIndex: Int = 0
    private let vocabularyService = VocabularyService.shared
    private var progressService: ProgressService?

    init(progressService: ProgressService? = nil) {
        self.progressService = progressService

        // If vocabulary is already loaded, populate immediately
        if vocabularyService.isLoaded {
            loadWordsForLevel()
        } else {
            // Wait for vocabulary to load using async/await continuation
            Task { [weak self] in
                await self?.vocabularyService.waitUntilLoaded()
                self?.loadWordsForLevel()
            }
        }
    }

    func setProgressService(_ service: ProgressService) {
        self.progressService = service
    }

    var loadError: String? {
        vocabularyService.loadError
    }

    func retryLoadWords() {
        // Reset the error and reload
        vocabularyService.loadError = nil
        // Trigger the vocabulary service to reload
        Task {
            await vocabularyService.reloadWords()
        }
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
        // Clamp currentIndex to valid bounds after filtering
        self.currentIndex = words.isEmpty ? 0 : min(currentIndex, words.count - 1)
    }

    // MARK: - Current Word (computed, boundary-safe)

    var currentWord: Word? {
        guard !words.isEmpty else { return nil }
        let safeIndex = min(max(currentIndex, 0), words.count - 1)
        return words[safeIndex]
    }

    // MARK: - Index-Based Access (boundary-safe)

    /// Returns the word at the given index, with bounds clamping.
    func word(at index: Int) -> Word {
        guard !words.isEmpty else { return Word.preview }
        let safeIndex = min(max(index, 0), words.count - 1)
        return words[safeIndex]
    }

    /// Returns a stable identity (word.id) for the given index.
    func wordId(at index: Int) -> String {
        word(at: index).id
    }

    func isBookmarked(for index: Int) -> Bool {
        let w = word(at: index)
        return progressService?.isBookmarked(w.id) ?? false
    }

    func isLearned(for index: Int) -> Bool {
        let w = word(at: index)
        return progressService?.isLearned(w.id) ?? false
    }

    func toggleBookmark(for index: Int) {
        let w = word(at: index)
        progressService?.toggleBookmark(w.id)
    }

    func toggleLearned(for index: Int) {
        let w = word(at: index)
        guard let service = progressService else { return }
        if service.isLearned(w.id) { service.unmarkLearned(w.id) }
        else { service.markAsLearned(w.id) }
    }

    // MARK: - Legacy single-card accessors (used by non-deck UI)

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
    }

    func toggleLearned() {
        guard let id = currentWord?.id, let service = progressService else { return }
        if service.isLearned(id) { service.unmarkLearned(id) }
        else { service.markAsLearned(id) }
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
            withAnimation(.easeOut(duration: 0.2)) {
                isPlayAnimating = false
            }
        } else if isLooping {
            // Loop mode: lock button to "Playing…" until user pauses
            withAnimation(.easeInOut(duration: 0.25)) {
                isPlayAnimating = true
            }
            playAudio()
        } else {
            // Non-loop mode: button follows audio state via onChange
            playAudio()
        }
    }

    func nextWord() {
        guard !words.isEmpty else { return }
        if isLooping {
            currentIndex = (currentIndex + 1) % words.count
        } else {
            currentIndex = min(currentIndex + 1, words.count - 1)
        }
    }

    func previousWord() {
        guard !words.isEmpty else { return }
        if isLooping {
            currentIndex = (currentIndex - 1 + words.count) % words.count
        } else {
            currentIndex = max(currentIndex - 1, 0)
        }
    }
}

// MARK: - Level Selector

struct LevelSelector: View {
    @Binding var selectedLevel: String
    let levels = ["A1", "A2", "B1", "B2", "C1"/*, "C2"*/]

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
        .frame(maxWidth: .infinity, alignment: .leading)
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

import SwiftUI

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

    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 420

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
        .onTapGesture {
            isFlipped.toggle()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(isFlipped ? "Word card showing definition. Tap to flip back." : "Word card for \(word.word). Tap to see definition.")
        .onChange(of: word.id) { _ in
            // Reset to front when word changes
            isFlipped = false
        }
    }
}

// MARK: - Card Front Face

struct CardFrontFace: View {
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
                    .accessibilityLabel("Play pronunciation")
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
                            let safeIndex = examples.indices.contains(currentExampleIndex) ? currentExampleIndex : 0
                            Text("\"" + examples[safeIndex] + "\"")
                                .font(.oxfordBody(size: 16))
                                .foregroundStyle(Color.webForeground)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                                .id("front-ex-\(word.id)-\(safeIndex)")

                            HStack(spacing: 6) {
                                Button(action: { onPlayExample(examples[safeIndex]) }) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Color.webPrimary)
                                }
                                .accessibilityLabel("Play example")

                                Spacer()

                                ForEach(0..<min(examples.count, 5), id: \.self) { i in
                                    Circle()
                                        .fill(i == safeIndex ? Color.webPrimary : Color.secondary.opacity(0.25))
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Tap to see definition, swipe to navigate")
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
            .accessibilityLabel(isBookmarked ? "Remove bookmark" : "Add bookmark")
        }
        .frame(height: cardHeight)
        .cardBackground()
        .onChange(of: word.id) { _ in
            currentExampleIndex = 0
        }
    }
}

// MARK: - Card Back Face

struct CardBackFace: View {
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
                    Text("\u{201C}\(example)\u{201D}")
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
        .cardBackground(style: .gradient)
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

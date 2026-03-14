import SwiftUI

// MARK: - Deck Configuration

/// All tunable parameters for the stacked card deck.
/// Adjust these values to fine-tune the premium stack appearance.
struct DeckConfiguration {
    // ── Visible window ──────────────────────────────────────────
    /// Number of cards rendered behind the active card.
    var maxVisibleBehind: Int = 3
    /// Number of previous cards kept in the view tree for backward transitions.
    var maxVisibleBefore: Int = 1

    // ── Stack appearance (restrained for readability) ───────────
    /// Scale reduction per layer behind the active card (e.g. 0.03 → 0.97, 0.94, 0.91).
    var scaleStep: CGFloat = 0.03
    /// Vertical offset per layer — creates visible card edges below.
    var verticalOffsetStep: CGFloat = 8
    /// Horizontal offset per layer — default 0 for a centered pile.
    var horizontalOffsetStep: CGFloat = 0
    /// Opacity reduction per layer (e.g. 0.12 → 0.88, 0.76, 0.64).
    var opacityStep: CGFloat = 0.12

    // ── Gesture ─────────────────────────────────────────────────
    /// Fraction of screen width the drag must exceed to commit a swipe.
    var swipeThresholdFraction: CGFloat = 0.2
    /// Predicted velocity threshold to commit a swipe.
    var swipeVelocityThreshold: CGFloat = 250
    /// Maximum rotation during drag in degrees (subtle, not dating-app).
    var dragRotationDegrees: Double = 5.0
    /// Minimum drag distance to begin recognizing the gesture.
    /// Set higher than nested carousel gestures (30pt) to avoid conflicts.
    var dragMinimumDistance: CGFloat = 40

    // ── Animation ───────────────────────────────────────────────
    /// Duration for the fly-off exit animation.
    var flyOffDuration: Double = 0.28
    /// Spring response for the re-stack animation.
    var springResponse: Double = 0.5
    /// Spring damping for the re-stack animation.
    var springDamping: Double = 0.72
}

// MARK: - Card State

/// Deterministic named state for each card in the visible window.
/// The layout engine maps each state to exact (scale, offset, opacity, zIndex) values.
enum CardState: Equatable {
    /// Front card — full size, full opacity, receives all interaction.
    case active
    /// First card behind the active card.
    case behind1
    /// Second card behind.
    case behind2
    /// Third card behind.
    case behind3
    /// Previous card in a deliberate pre-entry position (kept in tree for backward transitions).
    case preEntry
    /// Previous card animating into the active position during a backward swipe.
    case incomingPrevious
    /// Active card animating off-screen during a forward swipe.
    case outgoingActive
    /// Card is not rendered at all.
    case hidden
}

// MARK: - Deck Phase

/// Explicit transition phase model for deterministic animation logic.
enum DeckPhase: Equatable {
    /// No transition in progress. Cards are in their resting positions.
    case idle
    /// User is actively dragging the front card.
    case dragging
    /// Front card is flying off-screen forward; deck is re-stacking.
    case animatingForward
    /// Front card is flying off-screen backward; deck is re-stacking.
    case animatingBackward
}

// MARK: - Card Layout

/// Resolved visual properties for a single card in the stack.
struct CardLayout {
    var scale: CGFloat
    var xOffset: CGFloat
    var yOffset: CGFloat
    var opacity: Double
    var zIndex: Double
}

/// Pure function: maps a `CardState` to its visual layout using the given configuration.
func cardLayout(for state: CardState, config: DeckConfiguration) -> CardLayout {
    switch state {
    case .active:
        return CardLayout(scale: 1.0, xOffset: 0, yOffset: 0, opacity: 1.0, zIndex: 1000)

    case .behind1:
        return CardLayout(
            scale: 1.0 - config.scaleStep,
            xOffset: config.horizontalOffsetStep,
            yOffset: config.verticalOffsetStep,
            opacity: 1.0 - config.opacityStep,
            zIndex: 999
        )

    case .behind2:
        return CardLayout(
            scale: 1.0 - config.scaleStep * 2,
            xOffset: config.horizontalOffsetStep * 2,
            yOffset: config.verticalOffsetStep * 2,
            opacity: 1.0 - config.opacityStep * 2,
            zIndex: 998
        )

    case .behind3:
        return CardLayout(
            scale: 1.0 - config.scaleStep * 3,
            xOffset: config.horizontalOffsetStep * 3,
            yOffset: config.verticalOffsetStep * 3,
            opacity: 1.0 - config.opacityStep * 3,
            zIndex: 997
        )

    case .preEntry:
        // Held off-screen to the right, ready to animate in during backward swipe.
        return CardLayout(scale: 1.0, xOffset: 0, yOffset: 0, opacity: 0, zIndex: 996)

    case .incomingPrevious:
        // Animates into the active position from the right side.
        return CardLayout(scale: 1.0, xOffset: 0, yOffset: 0, opacity: 1.0, zIndex: 1001)

    case .outgoingActive:
        // Stays at active layout until the fly-off offset is applied separately.
        return CardLayout(scale: 1.0, xOffset: 0, yOffset: 0, opacity: 1.0, zIndex: 1001)

    case .hidden:
        return CardLayout(scale: 0.88, xOffset: 0, yOffset: 32, opacity: 0, zIndex: 0)
    }
}

// MARK: - Stacked Card Deck

/// A generic, reusable stacked card deck that renders a visible window around `currentIndex`.
///
/// Only a small number of cards are in the view tree at any time (typically 5),
/// regardless of the total `itemCount`. Each card's visual position is driven by
/// a deterministic `CardState` mapped through `cardLayout(for:config:)`.
///
/// - Parameters:
///   - itemCount: Total number of items in the data source.
///   - currentIndex: Binding to the active card index.
///   - isLooping: Whether the deck wraps around at boundaries.
///   - config: Visual and gesture tuning parameters.
///   - itemId: Closure returning a stable identity for each item index.
///   - cardContent: Builder closure that produces a card view for a given index.
///   - onNavigate: Optional callback fired after the index changes.
struct StackedCardDeck<ID: Hashable, Content: View>: View {
    let itemCount: Int
    @Binding var currentIndex: Int
    var isLooping: Bool = false
    var config: DeckConfiguration = DeckConfiguration()
    let itemId: (Int) -> ID
    @ViewBuilder let cardContent: (Int) -> Content
    var onNavigate: ((Int) -> Void)?

    // ── Internal state ──────────────────────────────────────────
    @State private var phase: DeckPhase = .idle
    @State private var dragOffset: CGFloat = 0

    // Haptic generators (pre-created per Apple guidance)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            ZStack {
                ForEach(visibleEntries, id: \.id) { entry in
                    let layout = cardLayout(for: entry.state, config: config)
                    let isActive = entry.state == .active

                    cardContent(entry.index)
                        .scaleEffect(layout.scale)
                        .offset(
                            x: layout.xOffset + (isActive ? dragOffset : 0),
                            y: layout.yOffset
                        )
                        .rotationEffect(
                            isActive
                                ? .degrees(Double(dragOffset / screenWidth) * config.dragRotationDegrees)
                                : .zero,
                            anchor: .bottom
                        )
                        .opacity(layout.opacity)
                        .zIndex(layout.zIndex)
                        .allowsHitTesting(isActive && phase == .idle)
                        .accessibilityHidden(!isActive)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: config.dragMinimumDistance)
                    .onChanged { value in
                        guard phase == .idle || phase == .dragging else { return }
                        // Horizontal-dominance check to avoid conflicts with vertical scrolling
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                        phase = .dragging
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        guard phase == .dragging else { return }
                        let threshold = screenWidth * config.swipeThresholdFraction
                        let velocity = value.predictedEndTranslation.width

                        if (value.translation.width < -threshold || velocity < -config.swipeVelocityThreshold)
                            && canNavigateForward {
                            commitForwardSwipe(screenWidth: screenWidth)
                        } else if (value.translation.width > threshold || velocity > config.swipeVelocityThreshold)
                            && canNavigateBackward {
                            commitBackwardSwipe(screenWidth: screenWidth)
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                                dragOffset = 0
                                phase = .idle
                            }
                        }
                    }
            )
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Next card") {
                if canNavigateForward { commitForwardSwipe(screenWidth: screenWidth) }
            }
            .accessibilityAction(named: "Previous card") {
                if canNavigateBackward { commitBackwardSwipe(screenWidth: screenWidth) }
            }
        }
    }

    // MARK: - Boundary Rules

    private var canNavigateForward: Bool {
        if isLooping { return itemCount > 1 }
        return currentIndex < itemCount - 1
    }

    private var canNavigateBackward: Bool {
        if isLooping { return itemCount > 1 }
        return currentIndex > 0
    }

    // MARK: - Visible Window

    /// Entry for each card in the visible window, carrying its data index, stable identity, and assigned state.
    private struct VisibleEntry: Identifiable {
        let index: Int
        let id: ID
        let state: CardState
    }

    private var visibleEntries: [VisibleEntry] {
        guard itemCount > 0 else { return [] }

        var entries: [VisibleEntry] = []

        // Previous card (for backward transitions)
        if config.maxVisibleBefore > 0 {
            let prevIndex = wrappedIndex(currentIndex - 1)
            if prevIndex != currentIndex { // avoid duplicate when itemCount == 1
                let state: CardState = (phase == .animatingBackward) ? .incomingPrevious : .preEntry
                entries.append(VisibleEntry(index: prevIndex, id: itemId(prevIndex), state: state))
            }
        }

        // Active card
        let safeCurrentIndex = clampedIndex(currentIndex)
        entries.append(VisibleEntry(
            index: safeCurrentIndex,
            id: itemId(safeCurrentIndex),
            state: (phase == .animatingForward) ? .outgoingActive : .active
        ))

        // Behind cards
        let behindStates: [CardState] = [.behind1, .behind2, .behind3]
        for offset in 1...config.maxVisibleBehind {
            let idx = wrappedIndex(currentIndex + offset)
            // Avoid duplicate entries (can happen when itemCount is small)
            if !entries.contains(where: { $0.index == idx }) {
                let state = offset <= behindStates.count ? behindStates[offset - 1] : .hidden
                entries.append(VisibleEntry(index: idx, id: itemId(idx), state: state))
            }
        }

        return entries
    }

    // MARK: - Index Helpers

    /// Wraps an index for looping, or clamps for non-looping.
    private func wrappedIndex(_ index: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        if isLooping {
            return ((index % itemCount) + itemCount) % itemCount
        }
        return min(max(index, 0), itemCount - 1)
    }

    /// Clamps `currentIndex` to valid bounds.
    private func clampedIndex(_ index: Int) -> Int {
        guard itemCount > 0 else { return 0 }
        return min(max(index, 0), itemCount - 1)
    }

    // MARK: - Swipe Commit

    private func commitForwardSwipe(screenWidth: CGFloat) {
        phase = .animatingForward
        mediumHaptic.impactOccurred()

        // Phase 1: Fly the active card off-screen to the left
        withAnimation(.easeIn(duration: config.flyOffDuration)) {
            dragOffset = -screenWidth * 1.4
        }

        // Phase 2: After fly-off, advance index and re-stack
        DispatchQueue.main.asyncAfter(deadline: .now() + config.flyOffDuration) {
            dragOffset = 0

            withAnimation(.spring(response: config.springResponse, dampingFraction: config.springDamping)) {
                let nextIndex = isLooping
                    ? ((currentIndex + 1) % itemCount)
                    : min(currentIndex + 1, itemCount - 1)
                currentIndex = nextIndex
                phase = .idle
            }

            onNavigate?(currentIndex)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                softHaptic.impactOccurred()
            }
        }
    }

    private func commitBackwardSwipe(screenWidth: CGFloat) {
        phase = .animatingBackward
        mediumHaptic.impactOccurred()

        // Phase 1: Fly the active card off-screen to the right
        withAnimation(.easeIn(duration: config.flyOffDuration)) {
            dragOffset = screenWidth * 1.4
        }

        // Phase 2: After fly-off, decrement index and re-stack
        DispatchQueue.main.asyncAfter(deadline: .now() + config.flyOffDuration) {
            dragOffset = 0

            withAnimation(.spring(response: config.springResponse, dampingFraction: config.springDamping)) {
                let prevIndex = isLooping
                    ? (((currentIndex - 1) % itemCount) + itemCount) % itemCount
                    : max(currentIndex - 1, 0)
                currentIndex = prevIndex
                phase = .idle
            }

            onNavigate?(currentIndex)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                softHaptic.impactOccurred()
            }
        }
    }
}

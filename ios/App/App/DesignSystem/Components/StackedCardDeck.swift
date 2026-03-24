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
    /// Opacity reduction per layer (e.g. 0.03 → 0.97, 0.94, 0.91).
    var opacityStep: CGFloat = 0.03

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
    /// Small right-drag distance that swaps the behind slot from next to previous.
    /// Keeping this low makes backward feel like the same "throw to reveal" model as forward.
    var backwardRevealActivationDistance: CGFloat = 14

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
    /// Active card animating off-screen during a forward swipe.
    case outgoingForward
    /// Active card animating off-screen during a backward swipe.
    case outgoingBackward
    /// Card is not rendered at all.
    case hidden
}

// MARK: - Deck Phase

/// Explicit transition phase model for deterministic animation logic.
enum DeckPhase: Equatable {
    /// No transition in progress. Cards are in their resting positions.
    case idle
    /// User is dragging with the normal forward reveal model.
    case draggingForward
    /// User is dragging right and the previous card has replaced behind1.
    case draggingBackwardReveal
    /// Front card is flying off-screen forward; deck is re-stacking.
    case animatingForward
    /// Front card is flying off-screen to the right while the previous card is already revealed below.
    case animatingBackwardThrow
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

    case .outgoingForward:
        // Stays at active layout until the fly-off offset is applied separately.
        return CardLayout(scale: 1.0, xOffset: 0, yOffset: 0, opacity: 1.0, zIndex: 1001)

    case .outgoingBackward:
        // Uses the same active-card language as forward, but exits to the right via a separate overlay.
        return CardLayout(scale: 1.0, xOffset: 0, yOffset: 0, opacity: 1.0, zIndex: 1002)

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
    /// When non-nil, the body uses these entries instead of the computed `visibleEntries`.
    /// Freezes the card set during transitions to prevent identity/state thrash.
    @State private var frozenEntries: [VisibleEntry]? = nil
    /// Separate overlay for the outgoing card during backward throws.
    /// This lets the base deck switch to the previous index immediately, so the revealed card
    /// is already stable underneath while the current card finishes flying away.
    @State private var backwardOutgoingCard: OutgoingCard? = nil
    @State private var backwardOutgoingOffset: CGFloat = 0

    // Haptic generators (pre-created per Apple guidance)
    private let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let softHaptic = UIImpactFeedbackGenerator(style: .soft)

    private var isDraggingPhase: Bool {
        phase == .draggingForward || phase == .draggingBackwardReveal
    }

    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width

            ZStack {
                let entries = frozenEntries ?? visibleEntries
                ForEach(entries, id: \.id) { entry in
                    let layout = cardLayout(for: entry.state, config: config)
                    let receivesDrag = entry.state == .active || entry.state == .outgoingForward

                    cardContent(entry.index)
                        .scaleEffect(layout.scale)
                        .offset(
                            x: layout.xOffset + (receivesDrag ? dragOffset : 0),
                            y: layout.yOffset
                        )
                        .rotationEffect(
                            receivesDrag
                                ? .degrees(Double(dragOffset / screenWidth) * config.dragRotationDegrees)
                                : .zero,
                            anchor: .bottom
                        )
                        .opacity(layout.opacity)
                        .zIndex(layout.zIndex)
                        .allowsHitTesting(entry.state == .active && phase == .idle)
                        .accessibilityHidden(entry.state != .active)
                        .transition(.identity)
                }

                if let backwardOutgoingCard {
                    let layout = cardLayout(for: .outgoingBackward, config: config)

                    cardContent(backwardOutgoingCard.index)
                        .id(backwardOutgoingCard.id)
                        .scaleEffect(layout.scale)
                        .offset(x: layout.xOffset + backwardOutgoingOffset, y: layout.yOffset)
                        .rotationEffect(
                            .degrees(Double(backwardOutgoingOffset / screenWidth) * config.dragRotationDegrees),
                            anchor: .bottom
                        )
                        .opacity(layout.opacity)
                        .zIndex(layout.zIndex)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.identity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: config.dragMinimumDistance)
                    .onChanged { value in
                        guard phase == .idle || isDraggingPhase else { return }
                        // Horizontal-dominance check to avoid conflicts with vertical scrolling
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                        phase = resolvedDragPhase(for: value.translation.width)
                        withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        guard isDraggingPhase else { return }
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

    private struct OutgoingCard {
        let index: Int
        let id: ID
    }

    private var visibleEntries: [VisibleEntry] {
        guard itemCount > 0 else { return [] }

        var entries: [VisibleEntry] = []
        let safeCurrentIndex = clampedIndex(currentIndex)
        let revealPreviousDuringDrag = phase == .draggingBackwardReveal

        if config.maxVisibleBefore > 0 || revealPreviousDuringDrag {
            let previousIndex = wrappedIndex(currentIndex - 1)
            if previousIndex != safeCurrentIndex {
                appendVisibleEntry(
                    &entries,
                    index: previousIndex,
                    state: revealPreviousDuringDrag ? .behind1 : .hidden
                )
            }
        }

        let activeState: CardState = phase == .animatingForward ? .outgoingForward : .active
        appendVisibleEntry(&entries, index: safeCurrentIndex, state: activeState)

        for offset in 1...config.maxVisibleBehind {
            appendVisibleEntry(
                &entries,
                index: wrappedIndex(currentIndex + offset),
                state: stateForNextCard(offset: offset, revealPreviousDuringDrag: revealPreviousDuringDrag)
            )
        }

        return entries
    }

    private func appendVisibleEntry(_ entries: inout [VisibleEntry], index: Int, state: CardState) {
        if let existingIndex = entries.firstIndex(where: { $0.index == index }) {
            guard statePriority(for: state) > statePriority(for: entries[existingIndex].state) else { return }
            entries[existingIndex] = VisibleEntry(index: index, id: itemId(index), state: state)
            return
        }

        entries.append(VisibleEntry(index: index, id: itemId(index), state: state))
    }

    private func stateForNextCard(offset: Int, revealPreviousDuringDrag: Bool) -> CardState {
        if revealPreviousDuringDrag {
            switch offset {
            case 1: return .behind2
            case 2: return .behind3
            default: return .hidden
            }
        }

        switch offset {
        case 1: return .behind1
        case 2: return .behind2
        case 3: return .behind3
        default: return .hidden
        }
    }

    private func statePriority(for state: CardState) -> Int {
        switch state {
        case .active, .outgoingForward, .outgoingBackward:
            return 5
        case .behind1:
            return 4
        case .behind2:
            return 3
        case .behind3:
            return 2
        case .hidden:
            return 1
        }
    }

    private func resolvedDragPhase(for translationWidth: CGFloat) -> DeckPhase {
        if phase == .draggingBackwardReveal && translationWidth >= 0 {
            return .draggingBackwardReveal
        }

        if translationWidth > config.backwardRevealActivationDistance && canNavigateBackward {
            return .draggingBackwardReveal
        }

        return .draggingForward
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
        guard phase == .idle || isDraggingPhase else { return }

        let nextIndex = isLooping
            ? ((currentIndex + 1) % itemCount)
            : min(currentIndex + 1, itemCount - 1)

        phase = .animatingForward
        // Freeze the visible entry set for the entire transition duration.
        frozenEntries = visibleEntries
        mediumHaptic.impactOccurred()

        // Phase 1: Fly the active card off-screen to the left.
        withAnimation(.easeIn(duration: config.flyOffDuration)) {
            dragOffset = -screenWidth * 1.4
        }

        // Phase 2: After fly-off completes, atomically advance index and re-stack.
        // All state changes inside one withAnimation block to prevent flicker.
        DispatchQueue.main.asyncAfter(deadline: .now() + config.flyOffDuration) {
            withAnimation(.spring(response: config.springResponse, dampingFraction: config.springDamping)) {
                dragOffset = 0
                currentIndex = nextIndex
                phase = .idle
                frozenEntries = nil
            }

            onNavigate?(currentIndex)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                softHaptic.impactOccurred()
            }
        }
    }

    private func commitBackwardSwipe(screenWidth: CGFloat) {
        guard phase == .idle || isDraggingPhase else { return }

        let prevIndex = isLooping
            ? (((currentIndex - 1) % itemCount) + itemCount) % itemCount
            : max(currentIndex - 1, 0)

        mediumHaptic.impactOccurred()
        frozenEntries = nil
        backwardOutgoingCard = OutgoingCard(index: currentIndex, id: itemId(currentIndex))
        backwardOutgoingOffset = dragOffset

        // Rebase to the previous index immediately so the revealed card is already stable
        // in the active stack beneath the outgoing overlay. This avoids any slide-in-from-left.
        var baseDeckTransaction = Transaction(animation: nil)
        baseDeckTransaction.disablesAnimations = true
        withTransaction(baseDeckTransaction) {
            currentIndex = prevIndex
            dragOffset = 0
            phase = .animatingBackwardThrow
        }

        withAnimation(.easeIn(duration: config.flyOffDuration)) {
            backwardOutgoingOffset = screenWidth * 1.4
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + config.flyOffDuration) {
            var cleanupTransaction = Transaction(animation: nil)
            cleanupTransaction.disablesAnimations = true
            withTransaction(cleanupTransaction) {
                self.backwardOutgoingCard = nil
                self.backwardOutgoingOffset = 0
                self.phase = .idle
            }

            self.onNavigate?(self.currentIndex)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.softHaptic.impactOccurred()
            }
        }
    }
}

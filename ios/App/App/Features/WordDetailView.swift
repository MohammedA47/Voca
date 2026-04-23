import SwiftUI

struct WordDetailView: View {
    let word: Word
    @Environment(ProgressService.self) private var progressService

    var body: some View {
        wordContent
            .background(
                LinearGradient(
                    colors: [
                        Color.adaptiveBackground,
                        Color.adaptiveBackgroundEnd
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle(word.word.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { wordToolbar }
            .userActivity("com.voca.viewWord") { activity in
                activity.title = word.word.capitalized
                activity.isEligibleForSearch = true
                activity.isEligibleForPrediction = true
                activity.userInfo = ["wordId": word.id]
            }
    }
    
    private var wordContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // ── Word Title ──────────────────────────────
                Text(word.word.capitalized)
                    .font(.brandDisplay(size: 40))
                    .foregroundStyle(Color.brandInk)

                // ── Phonetics ───────────────────────────────
                HStack(spacing: Spacing.md) {
                    if let uk = word.phonetics.uk {
                        PhoneticChip(label: "UK", phonetic: uk) {
                            AudioService.shared.speak(text: word.word, accent: "uk")
                        }
                    }
                    if let us = word.phonetics.us {
                        PhoneticChip(label: "US", phonetic: us) {
                            AudioService.shared.speak(text: word.word, accent: "us")
                        }
                    }
                }

                // ── Part of Speech ──────────────────────────
                Text(word.type.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Spacing.sm + Spacing.xs)
                    .padding(.vertical, Spacing.xs + 2)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 8))

                // ── Level Badge ─────────────────────────────
                HStack(spacing: 6) {
                    Text("Level")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(word.level)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm + 2)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.accentPrimary)
                        .clipShape(Capsule())
                }

                // ── Usage Examples ──────────────────────────
                if let examples = word.examples, !examples.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm + Spacing.xs) {
                        Text("USAGE EXAMPLES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.accentPrimary)
                            .tracking(1)

                        ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                            HStack(alignment: .top, spacing: Spacing.sm + 2) {
                                Text("\(index + 1).")
                                    .font(.brandBody(size: 15))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24, alignment: .trailing)

                                Text("\"\(example)\"")
                                    .font(.brandBody(size: 16))
                                    .foregroundStyle(Color.appForeground)
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(Spacing.md + 2)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.adaptiveCardBackgroundSecondary)
                    )
                }

                Spacer(minLength: Spacing.xxl)
            }
            .padding(Spacing.lg)
        }
    }
    
    @ToolbarContentBuilder
    private var wordToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                AudioService.shared.speak(text: word.word)
            } label: {
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundStyle(Color.accentPrimary)
            }
            .accessibilityLabel("Play pronunciation")

            Button {
                progressService.toggleBookmark(word.id)
            } label: {
                Image(systemName: progressService.isBookmarked(word.id) ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(progressService.isBookmarked(word.id) ? Color.accentPrimary : Color.secondary)
            }
            .accessibilityLabel(progressService.isBookmarked(word.id) ? "Remove bookmark" : "Add bookmark")

            Button {
                if progressService.isLearned(word.id) {
                    progressService.unmarkLearned(word.id)
                } else {
                    progressService.markAsLearned(word.id)
                }
            } label: {
                Image(systemName: progressService.isLearned(word.id) ? "checkmark.circle.fill" : "checkmark.circle")
                    .foregroundStyle(progressService.isLearned(word.id) ? Color.green : Color.secondary)
            }
            .accessibilityLabel(progressService.isLearned(word.id) ? "Mark as not learned" : "Mark as learned")
        }
    }
}

// MARK: - Phonetic Chip

private struct PhoneticChip: View {
    let label: String
    let phonetic: String
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentPrimary.opacity(0.8))
                .clipShape(.rect(cornerRadius: 4))

            Text(phonetic)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.accentPrimary)

            Button(action: onPlay) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.accentPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.accentPrimary.opacity(0.06))
        .clipShape(.rect(cornerRadius: 10))
    }
}

#Preview("Word Detail") {
    NavigationStack {
        WordDetailView(word: .preview)
            .environment(ProgressService())
    }
}

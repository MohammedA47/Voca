import SwiftUI

struct WordDetailView: View {
    let word: Word
    @EnvironmentObject var progressService: ProgressService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // ── Word Title ──────────────────────────────
                Text(word.word.capitalized)
                    .font(.oxfordDisplay(size: 40))
                    .foregroundColor(.oxfordNavy)

                // ── Phonetics ───────────────────────────────
                HStack(spacing: Spacing.md) {
                    if let uk = word.phonetics.uk {
                        PhoneticChip(label: "UK", phonetic: uk) {
                            AudioService.shared.speak(text: word.word)
                        }
                    }
                    if let us = word.phonetics.us {
                        PhoneticChip(label: "US", phonetic: us) {
                            AudioService.shared.speak(text: word.word)
                        }
                    }
                }

                // ── Part of Speech ──────────────────────────
                Text(word.type.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, Spacing.sm + Spacing.xs)
                    .padding(.vertical, Spacing.xs + 2)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(8)

                // ── Level Badge ─────────────────────────────
                HStack(spacing: 6) {
                    Text("Level")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(word.level)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.sm + 2)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.webPrimary)
                        .clipShape(Capsule())
                }

                // ── Usage Examples ──────────────────────────
                if let examples = word.examples, !examples.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm + Spacing.xs) {
                        Text("USAGE EXAMPLES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.webPrimary)
                            .tracking(1)

                        ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                            HStack(alignment: .top, spacing: Spacing.sm + 2) {
                                Text("\(index + 1).")
                                    .font(.oxfordBody(size: 15))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24, alignment: .trailing)

                                Text("\"\(example)\"")
                                    .font(.oxfordBody(size: 16))
                                    .foregroundColor(.webForeground)
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
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    AudioService.shared.speak(text: word.word)
                } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundColor(.webPrimary)
                }

                Button {
                    progressService.toggleBookmark(word.id)
                } label: {
                    Image(systemName: progressService.isBookmarked(word.id) ? "bookmark.fill" : "bookmark")
                        .foregroundColor(progressService.isBookmarked(word.id) ? .webPrimary : .secondary)
                }

                Button {
                    if progressService.isLearned(word.id) {
                        progressService.unmarkLearned(word.id)
                    } else {
                        progressService.markAsLearned(word.id)
                    }
                } label: {
                    Image(systemName: progressService.isLearned(word.id) ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(progressService.isLearned(word.id) ? .green : .secondary)
                }
            }
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
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.webPrimary.opacity(0.8))
                .cornerRadius(4)

            Text(phonetic)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.webPrimary)

            Button(action: onPlay) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundColor(.webPrimary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.webPrimary.opacity(0.06))
        .cornerRadius(10)
    }
}

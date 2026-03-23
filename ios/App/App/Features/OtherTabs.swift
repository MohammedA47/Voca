import SwiftUI

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Word Type Filter ────────────────────────
                WordTypeSelector(
                    selectedType: $viewModel.selectedWordType,
                    availableTypes: viewModel.allWordTypes
                )
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm + 2)
                
                if viewModel.searchText.isEmpty && viewModel.selectedWordType == nil {
                    ContentUnavailableView(
                        "Search Words",
                        systemImage: "magnifyingglass",
                        description: Text("Type to search through vocabulary")
                    )
                } else {
                    List(viewModel.filteredWords) { word in
                        NavigationLink(value: AppRoute.wordDetail(word)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(word.word)
                                        .font(.headline)
                                    Text(word.type)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(word.level)
                                    .font(.caption)
                                    .padding(4)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
            .withAppRoutes()
        }
    }
}

struct BookmarksView: View {
    @Environment(ProgressService.self) private var progressService
    private let vocabService = VocabularyService.shared
    
    var bookmarkedWords: [Word] {
        progressService.bookmarkedWords.compactMap { vocabService.wordsById[$0] }.sorted { $0.word < $1.word }
    }
    
    var body: some View {
        NavigationStack {
            if bookmarkedWords.isEmpty {
                 ContentUnavailableView("No Bookmarks", systemImage: "bookmark.slash", description: Text("Save words you want to review later."))
                    .navigationTitle("Bookmarks")
            } else {
                List(bookmarkedWords) { word in
                    NavigationLink(value: AppRoute.wordDetail(word)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(word.word).font(.headline)
                                Text(word.type).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(action: {
                                progressService.toggleBookmark(word.id)
                            }) {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(.tint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .navigationTitle("Bookmarks")
                .withAppRoutes()
            }
        }
    }
}

struct ProfileView: View {
    @Environment(ProgressService.self) private var progressService
    private let vocabService = VocabularyService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive background
                LinearGradient(
                    gradient: Gradient(colors: [Color.adaptiveBackground, Color.adaptiveBackgroundEnd]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // MARK: - Header Section
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Your Progress")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.oxfordNavy)

                            Text("Keep learning to master pronunciation")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.lg)

                        // MARK: - Stats Cards Row
                        StatsCardsRow(
                            wordsLearned: progressService.learnedWords.count,
                            totalWords: vocabService.words.count,
                            bookmarked: progressService.bookmarkedWords.count
                        )
                        .padding(.horizontal, Spacing.md)

                        // MARK: - Progress by CEFR Level
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Progress by Level")
                                .font(.headline)
                                .foregroundStyle(Color.oxfordNavy)
                                .padding(.horizontal, Spacing.md)

                            VStack(spacing: Spacing.sm) {
                                ForEach(["A1", "A2", "B1", "B2", "C1"/*, "C2"*/], id: \.self) { levelStr in
                                    CEFRLevelProgressRow(
                                        level: levelStr,
                                        learnedWords: progressService.learnedWords,
                                        vocabService: vocabService
                                    )
                                }
                            }
                            .padding(Spacing.md)
                            .background(Color.adaptiveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, Spacing.md)
                        }

                        // MARK: - Words by Type
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Words by Type")
                                .font(.headline)
                                .foregroundStyle(Color.oxfordNavy)
                                .padding(.horizontal, Spacing.md)

                            WordsTypeChart(vocabService: vocabService)
                                .padding(Spacing.md)
                                .background(Color.adaptiveCardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, Spacing.md)
                        }

                        // MARK: - Learning Streaks
                        VStack(spacing: Spacing.sm) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "flame.fill")
                                    .font(.title2)
                                    .foregroundStyle(progressService.calculateStreak() > 0 ? Color.orange : Color.secondary.opacity(0.3))

                                VStack(alignment: .leading, spacing: 2) {
                                    let streak = progressService.calculateStreak()
                                    Text(streak > 0 ? "\(streak) Day Streak!" : "Start your streak!")
                                        .font(.body)
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.oxfordNavy)
                                    
                                    Text(streak > 0 ? "You're on fire! Keep it up." : "Learn at least one word today.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                        }
                        .padding(Spacing.md)
                        .background(Color.adaptiveCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, Spacing.md)

                        // MARK: - Settings Section
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("About")
                                .font(.headline)
                                .foregroundStyle(Color.oxfordNavy)
                                .padding(.horizontal, Spacing.md)

                            HStack {
                                Text("Version")
                                Spacer()
                                Text("1.0.0")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(Spacing.md)
                            .background(Color.adaptiveCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, Spacing.md)
                        }

                        Spacer()
                            .frame(height: Spacing.lg)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

// MARK: - Stats Cards Component
struct StatsCardsRow: View {
    let wordsLearned: Int
    let totalWords: Int
    let bookmarked: Int

    var learnedPercentage: Int {
        guard totalWords > 0 else { return 0 }
        return Int(Double(wordsLearned) / Double(totalWords) * 100)
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Words Learned Card
            StatCard(
                title: "Words Learned",
                value: "\(wordsLearned)",
                subtitle: "\(learnedPercentage)% of \(totalWords)",
                color: Color.webPrimary
            )

            // Bookmarked Card
            StatCard(
                title: "Bookmarked",
                value: "\(bookmarked)",
                subtitle: "for review",
                color: Color.oxfordGold
            )

            // Total Available Card
            StatCard(
                title: "Total Available",
                value: "\(totalWords)",
                subtitle: "words",
                color: Color.webSecondary
            )
        }
    }
}

// MARK: - Individual Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.oxfordNavy)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.adaptiveCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - CEFR Level Progress Row
struct CEFRLevelProgressRow: View {
    let level: String
    let learnedWords: [String: Date]
    let vocabService: VocabularyService

    var levelWords: [Word] {
        vocabService.wordsByLevel[level] ?? []
    }

    var learnedCount: Int {
        levelWords.filter { learnedWords.keys.contains($0.id) }.count
    }

    var totalCount: Int {
        levelWords.count
    }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(learnedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                Text(level)
                    .font(.headline)
                    .foregroundStyle(Color.oxfordNavy)

                Spacer()

                Text("\(learnedCount)/\(totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Progress bar using shapes
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.adaptiveCardBackgroundSecondary)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.webPrimary)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Words by Type Chart
struct WordsTypeChart: View {
    let vocabService: VocabularyService

    var typeData: [(type: String, count: Int)] {
        vocabService.wordsByType
            .map { (type: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var maxCount: Int {
        typeData.map { $0.count }.max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(typeData, id: \.type) { item in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(item.type.capitalized)
                            .font(.subheadline)
                            .foregroundStyle(Color.oxfordNavy)

                        Spacer()

                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Horizontal bar chart using shapes
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background bar
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.adaptiveCardBackgroundSecondary)

                            // Progress fill
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.webPrimary, Color.oxfordGold]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(item.count) / CGFloat(maxCount))
                        }
                    }
                    .frame(height: 12)
                }
            }
        }
    }
}

#Preview("Bookmarks") {
    BookmarksView()
        .environment(ProgressService())
}

#Preview("Profile") {
    ProfileView()
        .environment(ProgressService())
}

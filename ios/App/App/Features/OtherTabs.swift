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
    
    var body: some View {
        NavigationStack {
            List {
                Section("Progress") {
                    HStack {
                        Text("Words Learned")
                        Spacer()
                        Text("\(progressService.learnedWords.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Bookmarks")
                        Spacer()
                        Text("\(progressService.bookmarkedWords.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Settings") {
                    // Placeholder for future settings
                    Text("Version 1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Profile")
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

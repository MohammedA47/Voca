import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(GlassStyle.inactiveTint)

                    TextField("Search words...", text: $viewModel.searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(GlassStyle.inactiveTint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassSurface(
                    in: RoundedRectangle(cornerRadius: GlassStyle.searchFieldCornerRadius, style: .continuous),
                    material: .thinMaterial,
                    borderOpacity: 0.32,
                    shadowOpacity: 0.07,
                    shadowRadius: 12,
                    shadowYOffset: 4
                )

                List(viewModel.filteredWords) { word in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(word.word)
                                .font(.headline)
                            Text(word.type)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(word.level)
                            .font(.caption)
                            .padding(4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .listStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .navigationTitle("Search")
        }
    }
}

struct BookmarksView: View {
    @EnvironmentObject var progressService: ProgressService
    // We need access to VocabularyService to resolve IDs to Words.
    // In a real app, use Dependency Injection or Singleton for VocabService.
    // For now, instantiate locally as it's cheap (mock data).
    @StateObject private var vocabService = VocabularyService()

    var bookmarkedWords: [Word] {
        vocabService.words.filter { progressService.isBookmarked($0.id) }
    }

    var body: some View {
        NavigationStack {
            if bookmarkedWords.isEmpty {
                 ContentUnavailableView("No Bookmarks", systemImage: "bookmark.slash", description: Text("Save words you want to review later."))
                    .navigationTitle("Bookmarks")
            } else {
                List(bookmarkedWords) { word in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(word.word).font(.headline)
                            Text(word.type).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            progressService.toggleBookmark(word.id)
                        }) {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .navigationTitle("Bookmarks")
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var progressService: ProgressService

    var body: some View {
        NavigationStack {
            List {
                Section("Progress") {
                    HStack {
                        Text("Words Learned")
                        Spacer()
                        Text("\(progressService.learnedWords.count)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Bookmarks")
                        Spacer()
                        Text("\(progressService.bookmarkedWords.count)")
                            .foregroundColor(.secondary)
                    }
                }
                Section("Settings") {
                    // Placeholder for future settings
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Profile")
        }
    }
}

import SwiftUI
enum Tabs {
    case home, saved, stats, search
}
struct ContentView: View {
    @State private var selectedTab: Tabs = .home
    @State private var searchViewModel = SearchViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                LearnView()
            }

            Tab("Saved", systemImage: "bookmark.fill", value: .saved) {
                BookmarksView()
            }

            Tab("Stats", systemImage: "chart.bar.fill", value: .stats) {
                ProfileView() // Reusing as Stats placeholder
            }

            Tab(value: .search, role: .search) {
                SearchView(viewModel: searchViewModel)
            }
        }
        .tint(.accentPrimary)
    }
}

#Preview("Content View") {
    ContentView()
        .environment(ProgressService())
}

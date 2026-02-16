import SwiftUI
enum Tabs {
    case home, saved, stats, search
}
struct ContentView: View {
    @State private var selectedTab: Tabs = .home

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

            Tab(value : .search, role: .search) {
                NavigationStack {
                    List {
                        Text("Search Screen")
                    }
                    .navigationTitle("Search")
                    .searchable(text: .constant(""))
                }
            }
        }
        .tint(.webPrimary)
    }
}

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            currentTabView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingTabBar(selectedTab: $selectedTab) {
                // TODO: Present search sheet
            }
            .padding(.bottom, 8)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private var currentTabView: some View {
        switch selectedTab {
        case 0:
            LearnView()
        case 1:
            BookmarksView()
        case 2:
            ProfileView() // Reusing as Stats placeholder
        case 3:
            ProfileView()
        default:
            LearnView()
        }
    }
}

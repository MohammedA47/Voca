import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    var onSearch: () -> Void = {}

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(icon: "house.fill", text: "Home", isSelected: selectedTab == 0) {
                selectedTab = 0
            }

            TabBarButton(icon: "bookmark.fill", text: "Saved", isSelected: selectedTab == 1) {
                selectedTab = 1
            }

            TabBarButton(icon: "chart.bar.fill", text: "Stats", isSelected: selectedTab == 2) {
                selectedTab = 2
            }

            Spacer()

            // Search button — separate glass circle
            Button(action: {
                selectedTab = 3
                onSearch()
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(selectedTab == 3 ? GlassStyle.activeTint : GlassStyle.inactiveTint)
                    .frame(width: 48, height: 48)
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("Search")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .glassEffect(in: .capsule)
        .padding(.horizontal, 24)
    }
}

struct TabBarButton: View {
    let icon: String
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(text)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? GlassStyle.activeTint : GlassStyle.inactiveTint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
    }
}

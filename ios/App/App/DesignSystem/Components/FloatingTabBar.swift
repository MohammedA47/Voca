import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    var onSearchTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
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

                TabBarButton(icon: "person.fill", text: "Profile", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
            }

            Button(action: onSearchTap) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.webForeground)
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            }
            .accessibilityLabel("Search")
        }
        .padding(.vertical, 10)
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.9))
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
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
            .foregroundColor(isSelected ? .webPrimary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
    }
}

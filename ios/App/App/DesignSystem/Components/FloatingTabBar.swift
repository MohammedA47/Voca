import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: Int

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

            Button(action: {
                selectedTab = 3
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundStyle(selectedTab == 3 ? GlassStyle.activeTint : GlassStyle.inactiveTint)
                    .frame(width: 48, height: 48)
                    .glassTreatment(
                        shape: Circle(),
                        material: .thinMaterial,
                        shadowOpacity: 0.12,
                        shadowRadius: 10,
                        shadowYOffset: 4
                    )
            }
            .padding(.trailing, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .glassTreatment(
            shape: Capsule(style: .continuous),
            material: .ultraThinMaterial,
            borderOpacity: 0.38,
            shadowOpacity: 0.08,
            shadowRadius: 18,
            shadowYOffset: 8
        )
        .clipShape(Capsule(style: .continuous))
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
                    .font(.system(size: 20))
                Text(text)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? GlassStyle.activeTint : GlassStyle.inactiveTint)
            .frame(maxWidth: .infinity)
        }
    }
}

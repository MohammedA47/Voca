import SwiftUI

enum GlassStyle {
    static let barCornerRadius: CGFloat = 28
    static let cardCornerRadius: CGFloat = 16
    static let searchFieldCornerRadius: CGFloat = 18

    static let borderOpacity: Double = 0.35
    static let borderLineWidth: CGFloat = 1

    static let shadowOpacity: Double = 0.10
    static let shadowRadius: CGFloat = 16
    static let shadowYOffset: CGFloat = 6

    static let activeTint = Color.webPrimary
    static let inactiveTint = Color.webForeground.opacity(0.58)
}

extension View {
    func glassSurface<S: InsettableShape>(
        in shape: S,
        material: Material = .ultraThinMaterial,
        borderOpacity: Double = GlassStyle.borderOpacity,
        shadowOpacity: Double = GlassStyle.shadowOpacity,
        shadowRadius: CGFloat = GlassStyle.shadowRadius,
        shadowYOffset: CGFloat = GlassStyle.shadowYOffset
    ) -> some View {
        background(material, in: shape)
            .overlay(
                shape
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: GlassStyle.borderLineWidth)
            )
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: shadowYOffset)
    }
}

struct GlassCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .glassSurface(
                in: RoundedRectangle(cornerRadius: GlassStyle.cardCornerRadius, style: .continuous),
                material: .ultraThinMaterial,
                shadowOpacity: 0.08,
                shadowRadius: 20,
                shadowYOffset: 4
            )
    }
}

struct GlassCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.blue.ignoresSafeArea()
            GlassCard {
                Text("Hello World")
                    .font(.title)
                    .padding()
            }
            .padding()
        }
    }
}

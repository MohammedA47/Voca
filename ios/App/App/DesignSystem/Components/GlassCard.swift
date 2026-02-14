import SwiftUI

struct GlassCard<Content: View>: View {
    var content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.oxfordNavy.opacity(0.08), radius: 20, x: 0, y: 4)
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

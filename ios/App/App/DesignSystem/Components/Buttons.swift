import SwiftUI

struct PIDefaultButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(isPrimary ? Color.blue : Color.secondary.opacity(0.2)) // Use native Blue/Gray fallback
            .foregroundColor(isPrimary ? .white : .primary)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PIDefaultButtonStyle {
    static var primary: PIDefaultButtonStyle { PIDefaultButtonStyle(isPrimary: true) }
    static var secondary: PIDefaultButtonStyle { PIDefaultButtonStyle(isPrimary: false) }
}

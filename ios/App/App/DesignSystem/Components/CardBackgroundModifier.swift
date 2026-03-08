import SwiftUI

// MARK: - Card Background Modifier

/// Reusable view modifier for the standard vocabulary card appearance.
///
/// Provides the rounded rectangle background with fill, shadow, and corner radius
/// used across `CardFrontFace`, `CardBackFace`, and potentially other card-like UI.
///
/// Usage:
/// ```swift
/// content.cardBackground()                     // Flat fill (default)
/// content.cardBackground(style: .gradient)     // Gradient fill
/// ```
struct CardBackgroundModifier: ViewModifier {
    enum Style {
        case flat
        case gradient
    }

    var style: Style
    var cornerRadius: CGFloat
    var shadowRadius: CGFloat
    var shadowY: CGFloat

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundFill)
                .shadow(color: Color.adaptiveCardShadow, radius: shadowRadius, x: 0, y: shadowY)
        )
    }

    private var backgroundFill: AnyShapeStyle {
        switch style {
        case .flat:
            AnyShapeStyle(Color.adaptiveCardBackground)
        case .gradient:
            AnyShapeStyle(LinearGradient(
                colors: [Color.adaptiveCardBackground, Color.adaptiveCardBackEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        }
    }
}

extension View {
    /// Applies the standard card background used throughout the app.
    ///
    /// - Parameters:
    ///   - style: `.flat` for solid color or `.gradient` for a subtle gradient.
    ///   - cornerRadius: The corner radius of the card (default: 28).
    ///   - shadowRadius: The blur radius of the card shadow (default: 16).
    ///   - shadowY: The vertical offset of the shadow (default: 8).
    func cardBackground(
        style: CardBackgroundModifier.Style = .flat,
        cornerRadius: CGFloat = 28,
        shadowRadius: CGFloat = 16,
        shadowY: CGFloat = 8
    ) -> some View {
        modifier(CardBackgroundModifier(
            style: style,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            shadowY: shadowY
        ))
    }
}

import SwiftUI

struct Typography {
    // Font Strategy:
    // Custom fonts (PlayfairDisplay and Inter) are not bundled in the app.
    // Using system fonts as primary (intentional, not fallback).
    // - Display: system serif (matches Playfair Display style and elegance)
    // - Body: system default (San Francisco, matches Inter's modern readability)

    // Display font: serif system font with bold weight for visual hierarchy
    static func display(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .serif)
    }

    // Body font: default system font for standard body text
    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .default)
    }

    // Use this for Headers
    static func header(size: CGFloat) -> Font {
        return .system(size: size, weight: .bold, design: .serif)
    }

    // Use this for Body
    static func standard(size: CGFloat) -> Font {
        return .system(size: size, weight: .regular, design: .default)
    }
}

// Extension for easier usage
extension Font {
    static func brandDisplay(size: CGFloat) -> Font {
        // Serif system font with bold weight (matches Playfair style)
        return .system(size: size, weight: .bold, design: .serif)
    }

    static func brandBody(size: CGFloat) -> Font {
        // System default font (San Francisco - matches Inter style)
        return .system(size: size, design: .default)
    }
}

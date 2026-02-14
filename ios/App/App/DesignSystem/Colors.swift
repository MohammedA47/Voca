import SwiftUI

extension Color {
    // Brand colors
    static let brandPrimary = Color("BrandPrimary")
    static let brandSecondary = Color("BrandSecondary")
    
    // Semantic colors
    static let surface = Color("Surface")
    static let background = Color("Background")
}

// Fallback if assets are missing
extension Color {
    static var fallbackPrimary: Color { Color.blue }
    static var fallbackSurface: Color { Color(uiColor: .secondarySystemBackground) }
}

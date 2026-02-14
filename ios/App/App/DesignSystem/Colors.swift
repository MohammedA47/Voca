import SwiftUI

extension Color {
    // MARK: - Web Theme Colors
    // Converted from HSL in index.css
    
    // --background: 40 33% 97%
    static let webBackground = Color(hue: 40, saturation: 0.33, lightness: 0.97)
    
    // --foreground: 220 40% 13%
    static let webForeground = Color(hue: 220, saturation: 0.40, lightness: 0.13)
    
    // --primary: 330 65% 50%
    static let webPrimary = Color(hue: 330, saturation: 0.65, lightness: 0.50)
    
    // --secondary: 330 45% 70%
    static let webSecondary = Color(hue: 330, saturation: 0.45, lightness: 0.70)
    
    // --oxford-navy: 220 40% 18%
    static let oxfordNavy = Color(hue: 220, saturation: 0.40, lightness: 0.18)
    
    // --oxford-gold: 330 65% 55% (Note: Source CSS has 330 hue which is pinkish, keeping faithful to source)
    static let oxfordGold = Color(hue: 330, saturation: 0.65, lightness: 0.55)
    
    // --muted: 40 20% 92%
    static let webMuted = Color(hue: 40, saturation: 0.20, lightness: 0.92)
    
    // MARK: - Semantic Aliases
    static let brandPrimary = webPrimary
    static let brandSecondary = webSecondary
    static let background = webBackground
    static let surface = webMuted
}

// Dark Mode Overrides (Simplistic approach for now)
// In a real app, we'd use Asset Catalog named colors for automatic light/dark switching.
// For this generated code, we'll keep it simple or user can use .colorScheme environment.

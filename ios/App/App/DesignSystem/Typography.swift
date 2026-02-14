import SwiftUI

struct Typography {
    static let displayFontName = "PlayfairDisplay-Regular" // Assuming font will be added later
    static let bodyFontName = "Inter-Regular"
    
    // Fallbacks
    static func display(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        // Try custom font, fallback to system serif (New York) to match "Playfair" style
        return Font.custom(displayFontName, size: size).weight(weight)
        // Fallback behavior is automatic in SwiftUI if font not found? 
        // Actually, if not found it falls back to system san-serif usually. 
        // We explicitely want Serif if custom missing.
    }
    
    static func body(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return Font.custom(bodyFontName, size: size).weight(weight)
    }
    
    // Use this for Headers
    static func header(size: CGFloat) -> Font {
        return .system(size: size, weight: .bold, design: .serif)
    }
    
    // Use this for Body
    static func standard(size: CGFloat) -> Font {
        return .system(size: size, weight: .regular, design: .default) // Inter is Neo-Grotesque, system is close enough
    }
}

// Extension for easier usage
extension Font {
    static func oxfordDisplay(size: CGFloat) -> Font {
        // Fallback to Serif to match Playfair vibe if font file missing
        return .system(size: size, weight: .bold, design: .serif)
    }
    
    static func oxfordBody(size: CGFloat) -> Font {
         // Fallback to Default (San Francisco) to match Inter vibe
        return .system(size: size, design: .default)
    }
}

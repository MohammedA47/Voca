import SwiftUI
import UIKit

extension Color {
    // MARK: - HSL Initialiser
    
    /// Convenience init matching CSS `hsl(h, s%, l%)`.
    init(hue h: Double, saturation s: Double, lightness l: Double) {
        let h360 = h / 360.0
        let t = s * min(l, 1 - l)
        let sHSV = (l > 0 && l < 1) ? 2 * t / (l + t) : 0
        let bHSV = l + t
        self.init(hue: h360, saturation: sHSV, brightness: bHSV)
    }
    
    // MARK: - Web Theme Colors (driven by the user-selected AccentTheme)
    // These resolve against `ThemeManager.shared.accent` so switching the
    // accent in Settings swaps every brand surface in one place. Views that
    // must react to changes should depend on `ThemeManager.shared.accent`
    // (directly or via an `.id(...)` on a parent) to trigger a rebuild.

    static var webPrimary: Color { ThemeManager.shared.accent.primary }

    static var webSecondary: Color { ThemeManager.shared.accent.secondary }

    static var oxfordGold: Color { ThemeManager.shared.accent.gold }
    
    // MARK: - Adaptive Semantic Colors
    // These switch automatically between light and dark mode.
    
    /// Main page background gradient start
    static let adaptiveBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
            : UIColor(red: 0.98, green: 0.96, blue: 0.97, alpha: 1)
    })
    
    /// Main page background gradient end
    static let adaptiveBackgroundEnd = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 1)
            : UIColor(red: 0.95, green: 0.93, blue: 0.96, alpha: 1)
    })
    
    /// Card / elevated surface fill
    static let adaptiveCardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.16, blue: 0.19, alpha: 1)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    })
    
    /// Secondary card surface (back face, examples area)
    static let adaptiveCardBackgroundSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.19, green: 0.18, blue: 0.22, alpha: 1)
            : UIColor(red: 0.97, green: 0.96, blue: 0.98, alpha: 1)
    })
    
    /// Card back face gradient end
    static let adaptiveCardBackEnd = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.13, blue: 0.18, alpha: 1)
            : UIColor(red: 0.97, green: 0.96, blue: 0.99, alpha: 1)
    })
    
    /// Unselected pill / chip background
    static let adaptivePillBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.22, blue: 0.26, alpha: 1)
            : UIColor.white.withAlphaComponent(0.7)
    })
    
    /// Pill border in light, subtle border in dark
    static let adaptivePillBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.08)
            : UIColor.black.withAlphaComponent(0.06)
    })
    
    /// Card shadow color
    static let adaptiveCardShadow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.30)
            : UIColor.black.withAlphaComponent(0.06)
    })
    
    /// Primary text (titles, headings)  — oxford navy adapts
    static let oxfordNavy = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.85, green: 0.85, blue: 0.92, alpha: 1)
            : UIColor(red: 0.16, green: 0.18, blue: 0.25, alpha: 1)
    })
    
    /// Body / foreground text
    static let webForeground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.88, green: 0.87, blue: 0.90, alpha: 1)
            : UIColor(red: 0.14, green: 0.15, blue: 0.19, alpha: 1)
    })
    
    // Legacy aliases kept for compatibility
    static let webBackground = Color(hue: 40, saturation: 0.33, lightness: 0.97)
    static let webMuted = Color(hue: 40, saturation: 0.20, lightness: 0.92)
    static let webBorder = Color(hue: 220, saturation: 0.20, lightness: 0.88)
    
    // MARK: - Semantic Aliases
    static var brandPrimary: Color { webPrimary }
    static var brandSecondary: Color { webSecondary }
    static let background = webBackground
    static let surface = webMuted
}

// MARK: - Spacing Grid
// 4pt-base grid. Use these tokens for all padding and VStack/HStack spacing
// throughout the app to maintain a consistent visual rhythm.

enum Spacing {
    /// 4pt — icon-to-label gaps, tight chip padding
    static let xs: CGFloat = 4
    /// 8pt — inner content gaps, small badges, button vertical padding
    static let sm: CGFloat = 8
    /// 16pt — standard horizontal screen margins, card inner padding
    static let md: CGFloat = 16
    /// 24pt — section separation, card top/bottom insets
    static let lg: CGFloat = 24
    /// 32pt — large section gaps, play button bottom clearance
    static let xl: CGFloat = 32
    /// 48pt — hero spacing, large empty states
    static let xxl: CGFloat = 48
}

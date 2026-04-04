import SwiftUI

// MARK: - Accent Theme
// Defines the palette options the user can pick from in Settings.
// Add new cases here to expose additional accent choices.

enum AccentTheme: String, CaseIterable, Identifiable {
    case purple
    case blue

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .purple: return "Purple"
        case .blue:   return "Blue"
        }
    }

    /// Primary hue driving webPrimary / webSecondary / oxfordGold.
    /// Saturation and lightness are kept consistent with the original
    /// design tokens so contrast and hierarchy stay balanced.
    private var hue: Double {
        switch self {
        case .purple: return 330
        case .blue:   return 215
        }
    }

    var primary: Color {
        Color(hue: hue, saturation: 0.65, lightness: 0.50)
    }

    var secondary: Color {
        Color(hue: hue, saturation: 0.45, lightness: 0.70)
    }

    var gold: Color {
        Color(hue: hue, saturation: 0.65, lightness: 0.55)
    }

    /// Swatch used inside the settings picker.
    var swatch: Color { primary }
}

// MARK: - Theme Manager
// Persists the user's accent choice in UserDefaults and publishes
// changes so the view tree can rebuild with the new palette.

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private static let storageKey = "accentTheme"

    var accent: AccentTheme {
        didSet {
            UserDefaults.standard.set(accent.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey)
        self.accent = raw.flatMap(AccentTheme.init(rawValue:)) ?? .purple
    }
}

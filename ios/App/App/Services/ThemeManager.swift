import SwiftUI

// MARK: - Accent Theme
// Defines the palette options the user can pick from in Settings.
// Add new cases here to expose additional accent choices.

enum AccentTheme: String, CaseIterable, Identifiable {
    case purple
    case blue
    case violet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .purple: return "Purple"
        case .blue:   return "Blue"
        case .violet: return "Violet"
        }
    }

    /// Primary hue driving accentPrimary / accentSecondary / brandGold.
    /// Saturation and lightness are kept consistent with the original
    /// design tokens so contrast and hierarchy stay balanced.
    private var hue: Double {
        switch self {
        case .purple: return 330
        case .blue:   return 215
        case .violet: return 269
        }
    }

    var primary: Color {
        switch self {
        case .violet:
            // Exact brand hex #985DD7
            return Color(red: 152.0 / 255.0, green: 93.0 / 255.0, blue: 215.0 / 255.0)
        default:
            return Color(hue: hue, saturation: 0.65, lightness: 0.50)
        }
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

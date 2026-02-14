import SwiftUI

extension Color {
    init(hue: Double, saturation: Double, lightness: Double, opacity: Double = 1) {
        let chroma = (1 - abs(2 * lightness - 1)) * saturation
        let x = chroma * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = lightness - chroma / 2

        var r, g, b: Double
        if 0 <= hue && hue < 60 {
            r = chroma; g = x; b = 0
        } else if 60 <= hue && hue < 120 {
            r = x; g = chroma; b = 0
        } else if 120 <= hue && hue < 180 {
            r = 0; g = chroma; b = x
        } else if 180 <= hue && hue < 240 {
            r = 0; g = x; b = chroma
        } else if 240 <= hue && hue < 300 {
            r = x; g = 0; b = chroma
        } else {
            r = chroma; g = 0; b = x
        }

        self.init(red: r + m, green: g + m, blue: b + m, opacity: opacity)
    }
}

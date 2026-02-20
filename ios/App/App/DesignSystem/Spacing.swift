import CoreFoundation

// MARK: - Spacing Grid
// 4pt-base grid system. All padding and spacing values in the app
// should use these tokens to maintain a consistent visual rhythm.

enum Spacing {
    /// 4pt — icon-to-label gaps, tight chip padding
    static let xs: CGFloat = 4
    /// 8pt — inner content gaps, small badges, button vertical padding
    static let sm: CGFloat = 8
    /// 16pt — standard horizontal screen margins, card inner padding, section bottom gaps
    static let md: CGFloat = 16
    /// 24pt — section separation, card top/bottom insets
    static let lg: CGFloat = 24
    /// 32pt — large section gaps, play button bottom clearance
    static let xl: CGFloat = 32
    /// 48pt — hero spacing, large empty states
    static let xxl: CGFloat = 48
}

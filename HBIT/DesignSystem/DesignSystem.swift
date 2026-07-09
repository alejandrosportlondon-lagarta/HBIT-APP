import SwiftUI

/// HBIT design tokens. All UI reads colors, type and spacing from here —
/// never hardcode values in feature views.
enum DesignSystem {
    // MARK: - Colors

    enum Colors {
        /// #0F1115 — app background.
        static let background = Color(hex: 0x0F1115)
        /// #181B22 — cards, sheets, elevated surfaces.
        static let surface = Color(hex: 0x181B22)
        /// #4ADE80 — primary brand green (CTAs, active states).
        static let primary = Color(hex: 0x4ADE80)
        /// #FF6B35 — accent orange (streak flame, urgency, emergency exit).
        static let accent = Color(hex: 0xFF6B35)
        /// #22C55E — success green (WIN states, completed missions).
        static let success = Color(hex: 0x22C55E)
        /// #F8FAFC — primary text.
        static let textPrimary = Color(hex: 0xF8FAFC)
        /// #94A3B8 — secondary text.
        static let textSecondary = Color(hex: 0x94A3B8)
    }

    // MARK: - Type scale

    enum Typography {
        /// Giant numerals: alarm time on dismiss screen, today's score.
        static let display = Font.system(size: 56, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold)
        static let headline = Font.system(size: 20, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let caption = Font.system(size: 13, weight: .medium)
        /// Numeric emphasis: streak count, score, countdowns.
        static let numeric = Font.system(size: 34, weight: .heavy, design: .rounded)
    }

    // MARK: - Spacing scale (pt)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Radii

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 12
        static let pill: CGFloat = 999
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

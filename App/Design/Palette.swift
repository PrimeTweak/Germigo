import SwiftUI

/// Resolved colors for the active theme and color scheme.
struct Palette {
    let background: Color
    let surface: Color
    let surfaceAlt: Color
    let sign: Color
    let ink: Color
    let inkSecondary: Color
    let inkTertiary: Color
    let hairline: Color
    let accent: Color
    let isDark: Bool

    let lime = Color(hex: 0xB6F34A)
    let limeDeep = Color(hex: 0x8FD929)
    let coral = Color(hex: 0xFF5B4D)
    let coralDeep = Color(hex: 0xFF4F42)
    let lilac = Color(hex: 0xB48CFF)
    let sky = Color(hex: 0x7CC4F5)
    let hazard = Color(hex: 0xFFC93C)
    let night = Color(hex: 0x1E1A26)

    static func make(theme: Theme, scheme: ColorScheme) -> Palette {
        let dark = theme == .nightShift || scheme == .dark
        if dark {
            let ink = Color(hex: 0xF6F1E7)
            return Palette(background: Color(hex: 0x16131C), surface: Color(hex: 0x231F2C),
                           surfaceAlt: Color(hex: 0x2E2939), sign: Color(hex: 0x231F2C),
                           ink: ink, inkSecondary: ink.opacity(0.66), inkTertiary: ink.opacity(0.42),
                           hairline: ink.opacity(0.12),
                           accent: theme == .mint ? Color(hex: 0x2EC4B6) : Color(hex: 0xB6F34A), isDark: true)
        }
        let ink = Color(hex: 0x1E1A26)
        if theme == .mint {
            return Palette(background: Color(hex: 0xE8F6F1), surface: .white, surfaceAlt: Color(hex: 0xD5ECE3),
                           sign: Color(hex: 0xF7FFFC), ink: ink, inkSecondary: ink.opacity(0.62),
                           inkTertiary: ink.opacity(0.4), hairline: ink.opacity(0.1),
                           accent: Color(hex: 0x2EC4B6), isDark: false)
        }
        return Palette(background: Color(hex: 0xF6F1E7), surface: .white, surfaceAlt: Color(hex: 0xEFE8DA),
                       sign: Color(hex: 0xFFFBF2), ink: ink, inkSecondary: ink.opacity(0.62),
                       inkTertiary: ink.opacity(0.4), hairline: ink.opacity(0.1),
                       accent: Color(hex: 0xB6F34A), isDark: false)
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.make(theme: .agar, scheme: .light)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Rarity {
    var color: Color {
        switch self {
        case .common: return Color(hex: 0x8A93A6)
        case .uncommon: return Color(hex: 0x2CB868)
        case .rare: return Color(hex: 0x3D7BFA)
        case .epic: return Color(hex: 0x9B5CFF)
        case .legendary: return Color(hex: 0xF2A21B)
        }
    }
}

extension Germ {
    var lightTint: Color { Color(hexString: tintLight) }
    var deepTint: Color { Color(hexString: tintDeep) }
}

/// Avatar gradients, assigned in the order people are added.
enum AvatarColors {
    private static let pairs: [(UInt32, UInt32)] = [
        (0x9FD6FF, 0x4C9FF0), (0xFFB3D2, 0xF26AA8), (0xFFE08A, 0xF7B52B),
        (0x8FE8DC, 0x21B3A4), (0xD9C4FF, 0x9B6CF2), (0xFFC2A8, 0xFF7A5C)
    ]

    static func gradient(_ index: Int) -> LinearGradient {
        let pair = pairs[abs(index) % pairs.count]
        return LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let you = LinearGradient(colors: [Color(hex: 0xD5FA86), Color(hex: 0x93D92F)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
}

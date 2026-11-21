import SwiftUI

/// Resolved colors for the active theme, color scheme and contrast setting.
/// The interface stays neutral; the characters bring the color.
struct Palette {
    let background: Color
    let surface: Color
    let surfaceAlt: Color
    let ink: Color
    let inkSecondary: Color
    let inkTertiary: Color
    let hairline: Color
    /// The one color of the interface: links, toggles and progress.
    let accent: Color
    /// Text and icons on an accent fill.
    let onAccent: Color
    let isDark: Bool

    static func make(theme: Theme, scheme: ColorScheme, contrast: ColorSchemeContrast = .standard) -> Palette {
        let dark = theme == .nightShift || scheme == .dark
        let strong = contrast == .increased
        if dark {
            let ink = Color(hex: Swatch.frost)
            return Palette(background: Color(hex: Swatch.navy), surface: Color(hex: Swatch.navySurface),
                           surfaceAlt: Color(hex: Swatch.navyRaised), ink: ink,
                           inkSecondary: ink.opacity(strong ? 0.88 : 0.72), inkTertiary: ink.opacity(strong ? 0.78 : 0.6),
                           hairline: ink.opacity(strong ? 0.24 : 0.1),
                           accent: Color(hex: theme == .mint ? Swatch.mint : Swatch.irisSoft),
                           onAccent: Color(hex: Swatch.navy), isDark: true)
        }
        let ink = Color(hex: Swatch.ink)
        let secondary = ink.opacity(strong ? 0.84 : 0.72)
        let tertiary = ink.opacity(strong ? 0.78 : 0.64)
        let hairline = ink.opacity(strong ? 0.22 : 0.1)
        if theme == .mint {
            return Palette(background: Color(hex: Swatch.mintBase), surface: .white, surfaceAlt: Color(hex: Swatch.mintAlt),
                           ink: ink, inkSecondary: secondary, inkTertiary: tertiary, hairline: hairline,
                           accent: Color(hex: Swatch.mintInk), onAccent: .white, isDark: false)
        }
        return Palette(background: .white, surface: Color(hex: Swatch.mist), surfaceAlt: Color(hex: Swatch.mistDeep),
                       ink: ink, inkSecondary: secondary, inkTertiary: tertiary, hairline: hairline,
                       accent: Color(hex: Swatch.iris), onAccent: .white, isDark: false)
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
    /// Bright fill for gauges on dark surfaces and decorative marks.
    var color: Color {
        switch self {
        case .common: return Color(hex: Swatch.slate)
        case .uncommon: return Color(hex: Swatch.green)
        case .rare: return Color(hex: Swatch.azure)
        case .epic: return Color(hex: Swatch.violet)
        case .legendary: return Color(hex: Swatch.gold)
        }
    }

    /// Readable shade for text and gauges on light backgrounds.
    var inkColor: Color {
        switch self {
        case .common: return Color(hex: Swatch.slateInk)
        case .uncommon: return Color(hex: Swatch.greenInk)
        case .rare: return Color(hex: Swatch.azureInk)
        case .epic: return Color(hex: Swatch.violetInk)
        case .legendary: return Color(hex: Swatch.goldInk)
        }
    }

    var pillBackground: Color {
        switch self {
        case .rare, .epic: return inkColor
        case .common, .uncommon, .legendary: return color
        }
    }

    var pillForeground: Color {
        switch self {
        case .rare, .epic: return .white
        case .common, .uncommon, .legendary: return Color(hex: Swatch.night)
        }
    }
}

extension Germ {
    var lightTint: Color { Color(hexString: tintLight) }
    var deepTint: Color { Color(hexString: tintDeep) }
}

/// Avatar gradients for the share cards and the crew, by index.
enum AvatarColors {
    private static let pairs: [(UInt32, UInt32)] = [
        (Swatch.skyLight, Swatch.blue), (Swatch.pinkLight, Swatch.pink), (Swatch.butter, Swatch.amber),
        (Swatch.aqua, Swatch.teal), (Swatch.lavender, Swatch.violetSoft), (Swatch.peach, Swatch.peachDeep)
    ]

    static func gradient(_ index: Int) -> LinearGradient {
        let pair = pairs[abs(index) % pairs.count]
        return LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)],
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let you = LinearGradient(colors: [Color(hex: Swatch.limePale), Color(hex: Swatch.limeLeaf)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
}

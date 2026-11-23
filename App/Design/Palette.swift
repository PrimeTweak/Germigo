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
    /// The theme's soft color, washed behind the character on Today.
    let wash: Color
    let isDark: Bool

    static func make(theme: Theme, scheme: ColorScheme, contrast: ColorSchemeContrast = .standard) -> Palette {
        let strong = contrast == .increased
        let tone = Tone.of(theme)
        if scheme == .dark {
            let ink = Color(hex: Swatch.frost)
            return Palette(background: Color(hex: Swatch.navy), surface: Color(hex: Swatch.navySurface),
                           surfaceAlt: Color(hex: Swatch.navyRaised), ink: ink,
                           inkSecondary: ink.opacity(strong ? 0.88 : 0.72), inkTertiary: ink.opacity(strong ? 0.78 : 0.6),
                           hairline: ink.opacity(strong ? 0.24 : 0.1),
                           accent: Color(hex: tone.nightAccent), onAccent: Color(hex: Swatch.navy),
                           wash: Color(hex: tone.nightAccent), isDark: true)
        }
        let ink = Color(hex: Swatch.ink)
        return Palette(background: tone.ground, surface: tone.surface, surfaceAlt: tone.surfaceAlt, ink: ink,
                       inkSecondary: ink.opacity(strong ? 0.84 : 0.72), inkTertiary: ink.opacity(strong ? 0.78 : 0.64),
                       hairline: ink.opacity(strong ? 0.22 : 0.1),
                       accent: Color(hex: tone.accent), onAccent: .white, wash: Color(hex: tone.nightAccent), isDark: false)
    }
}

/// What a theme sets: its accent by day and by night, and its daytime grounds. The night grounds are shared.
private struct Tone {
    let accent: UInt32
    let nightAccent: UInt32
    let ground: Color
    let surface: Color
    let surfaceAlt: Color

    static func of(_ theme: Theme) -> Tone {
        switch theme {
        case .agar:
            return Tone(accent: Swatch.iris, nightAccent: Swatch.irisSoft, ground: .white,
                        surface: Color(hex: Swatch.mist), surfaceAlt: Color(hex: Swatch.mistDeep))
        case .coral:
            return Tone(accent: Swatch.coralInk, nightAccent: Swatch.coralSoft, ground: Color(hex: Swatch.coralWash),
                        surface: .white, surfaceAlt: Color(hex: Swatch.coralMist))
        case .sky:
            return Tone(accent: Swatch.azureInk, nightAccent: Swatch.skyLight, ground: Color(hex: Swatch.skyWash),
                        surface: .white, surfaceAlt: Color(hex: Swatch.skyMist))
        case .mint:
            return Tone(accent: Swatch.mintInk, nightAccent: Swatch.mint, ground: Color(hex: Swatch.mintBase),
                        surface: .white, surfaceAlt: Color(hex: Swatch.mintAlt))
        case .bubblegum:
            return Tone(accent: Swatch.pinkInk, nightAccent: Swatch.pinkLight, ground: Color(hex: Swatch.pinkWash),
                        surface: .white, surfaceAlt: Color(hex: Swatch.pinkMist))
        }
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

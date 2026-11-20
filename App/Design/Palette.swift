import SwiftUI

/// Resolved colors for the active theme, color scheme and contrast setting.
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
    /// Coral for text; the bright corals are for fills and icons.
    let coralInk: Color
    /// Text and icons that confirm something went right.
    let successInk: Color
    /// Fill of progress gauges.
    let progress: Color
    /// The leader's crown.
    let crown: Color
    let isDark: Bool

    let lime = Color(hex: Swatch.lime)
    let limeDeep = Color(hex: Swatch.limeDeep)
    let coral = Color(hex: Swatch.coral)
    let coralDeep = Color(hex: Swatch.coralDeep)
    let lilac = Color(hex: Swatch.lilac)
    let sky = Color(hex: Swatch.sky)
    let hazard = Color(hex: Swatch.hazard)
    let night = Color(hex: Swatch.night)

    static func make(theme: Theme, scheme: ColorScheme, contrast: ColorSchemeContrast = .standard) -> Palette {
        let dark = theme == .nightShift || scheme == .dark
        let strong = contrast == .increased
        if dark {
            let ink = Color(hex: Swatch.chalk)
            return Palette(background: Color(hex: Swatch.nightBase), surface: Color(hex: Swatch.nightSurface),
                           surfaceAlt: Color(hex: Swatch.nightRaised), sign: Color(hex: Swatch.nightSurface),
                           ink: ink, inkSecondary: ink.opacity(strong ? 0.88 : 0.78), inkTertiary: ink.opacity(strong ? 0.78 : 0.62),
                           hairline: ink.opacity(strong ? 0.24 : 0.12),
                           accent: theme == .mint ? Color(hex: Swatch.mint) : Color(hex: Swatch.lime),
                           coralInk: Color(hex: Swatch.coralSoft), successInk: Color(hex: Swatch.green),
                           progress: Color(hex: Swatch.limeDeep), crown: Color(hex: Swatch.gold), isDark: true)
        }
        let ink = Color(hex: Swatch.night)
        let secondary = ink.opacity(strong ? 0.84 : 0.72)
        let tertiary = ink.opacity(strong ? 0.78 : 0.64)
        let hairline = ink.opacity(strong ? 0.22 : 0.1)
        if theme == .mint {
            return Palette(background: Color(hex: Swatch.mintBase), surface: .white, surfaceAlt: Color(hex: Swatch.mintAlt),
                           sign: Color(hex: Swatch.mintSign), ink: ink, inkSecondary: secondary, inkTertiary: tertiary,
                           hairline: hairline, accent: Color(hex: Swatch.mint), coralInk: Color(hex: Swatch.coralInk),
                           successInk: Color(hex: Swatch.forest), progress: Color(hex: Swatch.limeInk),
                           crown: Color(hex: Swatch.crown), isDark: false)
        }
        return Palette(background: Color(hex: Swatch.chalk), surface: .white, surfaceAlt: Color(hex: Swatch.agarAlt),
                       sign: Color(hex: Swatch.agarSign), ink: ink, inkSecondary: secondary, inkTertiary: tertiary,
                       hairline: hairline, accent: Color(hex: Swatch.lime), coralInk: Color(hex: Swatch.coralInk),
                       successInk: Color(hex: Swatch.forest), progress: Color(hex: Swatch.limeInk),
                       crown: Color(hex: Swatch.crown), isDark: false)
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

/// Avatar gradients, assigned in the order people are added.
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

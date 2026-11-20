import Foundation

/// Every color value used by Petri, shared by the app and the widgets.
/// Roles that follow the theme, the color scheme and Increase Contrast live in `Palette`.
enum Swatch {
    // Ink and surfaces
    static let night: UInt32 = 0x1E1A26
    static let nightBase: UInt32 = 0x16131C
    static let nightSurface: UInt32 = 0x231F2C
    static let nightRaised: UInt32 = 0x2E2939
    static let tileTop: UInt32 = 0x34303D
    static let tileBottom: UInt32 = 0x1F1C26
    static let plum: UInt32 = 0x2A2140
    static let plumDeep: UInt32 = 0x120F17
    static let chalk: UInt32 = 0xF6F1E7
    static let agarAlt: UInt32 = 0xEFE8DA
    static let agarSign: UInt32 = 0xFFFBF2
    static let cream: UInt32 = 0xFFF6E2
    static let linen: UInt32 = 0xF3EEE6
    static let mintBase: UInt32 = 0xE8F6F1
    static let mintAlt: UInt32 = 0xD5ECE3
    static let mintSign: UInt32 = 0xF7FFFC
    static let slate: UInt32 = 0x8A93A6
    static let slateInk: UInt32 = 0x5D6577

    // Greens
    static let lime: UInt32 = 0xB6F34A
    static let limeDeep: UInt32 = 0x8FD929
    static let limeInk: UInt32 = 0x4F9A0F
    static let limeLight: UInt32 = 0xC9FA6E
    static let limeMid: UInt32 = 0xA6EB3A
    static let limePale: UInt32 = 0xD5FA86
    static let limeGlow: UInt32 = 0xE0FF9C
    static let limeLeaf: UInt32 = 0x93D92F
    static let grass: UInt32 = 0x9EDC48
    static let moss: UInt32 = 0x73B52B
    static let green: UInt32 = 0x2CB868
    static let greenInk: UInt32 = 0x1B8048
    static let forest: UInt32 = 0x17773F

    // Teals and blues
    static let mint: UInt32 = 0x2EC4B6
    static let aqua: UInt32 = 0x8FE8DC
    static let teal: UInt32 = 0x21B3A4
    static let sky: UInt32 = 0x7CC4F5
    static let skyLight: UInt32 = 0x9FD6FF
    static let skyPale: UInt32 = 0xB9E2FF
    static let skyMid: UInt32 = 0x6FB5F2
    static let blue: UInt32 = 0x4C9FF0
    static let azure: UInt32 = 0x3D7BFA
    static let azureInk: UInt32 = 0x2C62E0
    static let holoBlue: UInt32 = 0x78DCFF

    // Purples and pinks
    static let lilac: UInt32 = 0xB48CFF
    static let lilacPale: UInt32 = 0xE4D6FF
    static let lilacMist: UInt32 = 0xEDE4FF
    static let lavender: UInt32 = 0xD9C4FF
    static let wisteria: UInt32 = 0xC9B0FF
    static let violet: UInt32 = 0x9B5CFF
    static let violetSoft: UInt32 = 0x9B6CF2
    static let violetInk: UInt32 = 0x7B3FE4
    static let grape: UInt32 = 0x6A3FD0
    static let pink: UInt32 = 0xF26AA8
    static let pinkLight: UInt32 = 0xFFB3D2
    static let pinkPale: UInt32 = 0xFFC9DF
    static let holoPink: UInt32 = 0xFF78C8

    // Corals and reds
    static let coral: UInt32 = 0xFF5B4D
    static let coralDeep: UInt32 = 0xFF4F42
    static let coralLight: UInt32 = 0xFF7A63
    static let coralSoft: UInt32 = 0xFF8A78
    static let coralPale: UInt32 = 0xFF9C86
    static let coralHot: UInt32 = 0xFF6A5A
    static let coralInk: UInt32 = 0xBF2D1C
    static let ember: UInt32 = 0x96140A
    static let blushFaint: UInt32 = 0xFFE1DC
    static let blushLight: UInt32 = 0xFFD3CC
    static let blush: UInt32 = 0xFFC1B8
    static let blushDeep: UInt32 = 0xFFB0A5
    static let peach: UInt32 = 0xFFC2A8
    static let peachDeep: UInt32 = 0xFF7A5C

    // Yellows and oranges
    static let hazard: UInt32 = 0xFFC93C
    static let gold: UInt32 = 0xF2A21B
    static let goldInk: UInt32 = 0x9A5800
    static let crown: UInt32 = 0xA86400
    static let goldFoil: UInt32 = 0xFFD978
    static let amber: UInt32 = 0xF7B52B
    static let butter: UInt32 = 0xFFE08A
    static let tangerine: UInt32 = 0xFFA33A
    static let holoYellow: UInt32 = 0xFFE678
    static let holoGreen: UInt32 = 0xC8FF78
}

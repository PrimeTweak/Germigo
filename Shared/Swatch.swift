import Foundation

/// Every color value used by Germily, shared by the app and the widgets.
/// Roles that follow the theme, the color scheme and Increase Contrast live in `Palette`.
enum Swatch {
    // Ink and surfaces
    static let ink: UInt32 = 0x15182E
    static let mist: UInt32 = 0xF4F3F9
    static let mistDeep: UInt32 = 0xE8E7F1
    static let silver: UInt32 = 0xC9C8D8
    static let navy: UInt32 = 0x0E1022
    static let navySurface: UInt32 = 0x1A1D36
    static let navyRaised: UInt32 = 0x262A4A
    static let frost: UInt32 = 0xF3F2FA
    static let night: UInt32 = 0x1E1A26
    static let tileTop: UInt32 = 0x34303D
    static let tileBottom: UInt32 = 0x1F1C26
    static let plum: UInt32 = 0x2A2140
    static let plumDeep: UInt32 = 0x120F17
    static let chalk: UInt32 = 0xF6F1E7
    static let agarSign: UInt32 = 0xFFFBF2
    static let cream: UInt32 = 0xFFF6E2
    static let mintBase: UInt32 = 0xE8F6F1
    static let mintAlt: UInt32 = 0xD5ECE3
    static let slate: UInt32 = 0x8A93A6
    static let slateInk: UInt32 = 0x5D6577

    // Greens
    static let lime: UInt32 = 0xB6F34A
    static let limeInk: UInt32 = 0x4F9A0F
    static let limeLight: UInt32 = 0xC9FA6E
    static let limePale: UInt32 = 0xD5FA86
    static let grass: UInt32 = 0x9EDC48
    static let green: UInt32 = 0x2CB868
    static let greenInk: UInt32 = 0x1B8048

    // Teals and blues
    static let mint: UInt32 = 0x2EC4B6
    static let mintInk: UInt32 = 0x0E7468
    static let aqua: UInt32 = 0x8FE8DC
    static let sky: UInt32 = 0x7CC4F5
    static let skyLight: UInt32 = 0x9FD6FF
    static let skyPale: UInt32 = 0xB9E2FF
    static let skyMid: UInt32 = 0x6FB5F2
    static let azure: UInt32 = 0x3D7BFA
    static let azureInk: UInt32 = 0x2C62E0
    static let skyWash: UInt32 = 0xEEF5FF
    static let skyMist: UInt32 = 0xDCEBFF
    static let holoBlue: UInt32 = 0x78DCFF
    static let periwinkle: UInt32 = 0xA9B6FF

    // Purples and pinks
    static let iris: UInt32 = 0x6240E0
    static let irisSoft: UInt32 = 0xB19CFF
    static let irisDeep: UInt32 = 0x4B33B8
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
    static let pinkInk: UInt32 = 0xC22E78
    static let pinkWash: UInt32 = 0xFFF0F7
    static let pinkMist: UInt32 = 0xFFE0EE

    // Corals and reds
    static let coral: UInt32 = 0xFF5B4D
    static let coralDeep: UInt32 = 0xFF4F42
    static let coralLight: UInt32 = 0xFF7A63
    static let coralSoft: UInt32 = 0xFF8A78
    static let coralPale: UInt32 = 0xFF9C86
    static let coralHot: UInt32 = 0xFF6A5A
    static let coralInk: UInt32 = 0xCC3A2A
    static let coralWash: UInt32 = 0xFFF3EF
    static let coralMist: UInt32 = 0xFFE4DC
    static let peach: UInt32 = 0xFFC2A8
    static let bronze: UInt32 = 0xE9A47F

    // Yellows and oranges
    static let hazard: UInt32 = 0xFFC93C
    static let gold: UInt32 = 0xF2A21B
    static let goldInk: UInt32 = 0x9A5800
    static let goldFoil: UInt32 = 0xFFD978
    static let amber: UInt32 = 0xF7B52B
    static let butter: UInt32 = 0xFFE08A
    static let tangerine: UInt32 = 0xFFA33A
    static let holoYellow: UInt32 = 0xFFE678
    static let holoGreen: UInt32 = 0xC8FF78

    // Household characters added with the Season Pass
    static let seafoam: UInt32 = 0xA8EBC0
    static let orchid: UInt32 = 0xE7C3FF
    static let blush: UInt32 = 0xFFD3EA
    static let apricot: UInt32 = 0xFFC891
    static let tan: UInt32 = 0xE3BC97
    static let custard: UInt32 = 0xFFE2B0
    static let cocoa: UInt32 = 0xC79A78
    static let caramel: UInt32 = 0xE8C391
    static let heather: UInt32 = 0xD8D0EE
    static let papaya: UInt32 = 0xFFB892
    static let rosehip: UInt32 = 0xFFADAD
    static let kiwi: UInt32 = 0xB9F29A
}

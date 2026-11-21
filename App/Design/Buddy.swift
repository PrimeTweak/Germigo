import SwiftUI

/// The household's characters: eight looks, each drawn healthy and sick.
enum Buddy {
    private static let tints: [UInt32] = [
        Swatch.skyLight, Swatch.pinkLight, Swatch.aqua, Swatch.butter,
        Swatch.peach, Swatch.lavender, Swatch.periwinkle, Swatch.limePale
    ]

    /// How each look moves while sick, in the order of the looks.
    private static let sickMoods: [Liveliness] = [
        .feverish, .wobbly, .sniffly, .dizzy, .sneezy, .weary, .weary, .shivering
    ]

    static func index(_ look: Int) -> Int {
        abs(look) % Looks.count
    }

    static func tint(_ look: Int) -> Color {
        Color(hex: tints[index(look)])
    }

    static func mood(_ look: Int, sick: Bool) -> Liveliness {
        sick ? sickMoods[index(look)] : .idle
    }
}

/// One household character. The art is larger than its frame so hats and props can stick out.
struct BuddyView: View {
    let look: Int
    var sick = false
    var size: CGFloat = 62
    /// Breathing, and the look's own routine while sick. Leave it off in long lists.
    var lively = false
    /// A tap makes it hop. Leave it off inside a button or a link.
    var pokes = false

    var body: some View {
        Group {
            if lively {
                LivelyCharacter(mood: Buddy.mood(look, sick: sick), phase: Double(Buddy.index(look)) * 0.7, pokes: pokes) {
                    art
                }
            } else {
                art
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var art: some View {
        Image("buddy-" + String(Buddy.index(look)) + (sick ? "-sick" : "-well"))
            .resizable()
            .scaledToFit()
            .frame(width: size * 1.5, height: size * 1.5)
            .frame(width: size, height: size)
    }
}

/// A character on a soft disc of its own color, for rows and small avatars.
struct BuddyBadge: View {
    let look: Int
    var sick = false
    var size: CGFloat = 40
    @Environment(\.palette) private var palette

    var body: some View {
        BuddyView(look: look, sick: sick, size: size * 0.74)
            .frame(width: size, height: size)
            .background(Buddy.tint(look).opacity(palette.isDark ? 0.3 : 0.45), in: Circle())
    }
}

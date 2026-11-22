import SwiftUI

/// The household's characters: eight looks, each drawn healthy and sick.
enum Buddy {
    private static let tints: [UInt32] = [
        Swatch.skyLight, Swatch.pinkLight, Swatch.aqua, Swatch.butter,
        Swatch.peach, Swatch.lavender, Swatch.periwinkle, Swatch.limePale
    ]

    static func index(_ look: Int) -> Int {
        abs(look) % Looks.count
    }

    static func tint(_ look: Int) -> Color {
        Color(hex: tints[index(look)])
    }

    static func mood(_ look: Int, sick: Bool, leads: Bool) -> Liveliness {
        .household(index(look), sick: sick, leads: leads)
    }
}

/// One household character. The art is larger than its frame so hats and props can stick out.
struct BuddyView: View {
    let look: Int
    var sick = false
    var size: CGFloat = 62
    /// Breathing, and the look's own routine while sick. Leave it off in lists.
    var lively = false
    /// The look's accent while healthy, for the one character that leads a screen or a group.
    var leads = false
    /// A tap makes it react. Leave it off inside a button or a link.
    var pokes = false
    /// When its accent comes in the seven-second cycle; by default each look has its own turn.
    var phase: Double?
    @State private var change: TimedReaction?
    @State private var joys = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if lively || leads {
                LivelyCharacter(mood: Buddy.mood(look, sick: sick, leads: leads),
                                phase: phase ?? Double(Buddy.index(look)) * CharacterPose.accentCycle / 8,
                                touch: pokes ? (sick ? Reaction.ouch : Reaction.giggle) : nil, event: change) {
                    art
                }
                .overlay(alignment: .top) {
                    if !reduceMotion {
                        JoySparkles(trigger: joys, size: size)
                    }
                }
                .onChange(of: sick) { _, nowSick in
                    change = TimedReaction(reaction: nowSick ? .shake : .joy, start: Date())
                    if !nowSick { joys += 1 }
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

/// The sparkles over a character who just got better: they pop, rise and fade.
private struct JoySparkles: View {
    let trigger: Int
    let size: CGFloat

    private struct Frame {
        var opacity = 0.0
        var scale = 0.4
        var rise = 0.0
    }

    var body: some View {
        Image(systemName: "sparkles")
            .font(.system(size: size * 0.32, weight: .semibold))
            .foregroundStyle(Color(hex: Swatch.gold))
            .keyframeAnimator(initialValue: Frame(), trigger: trigger) { content, frame in
                content
                    .opacity(frame.opacity)
                    .scaleEffect(frame.scale)
                    .offset(y: frame.rise - size * 0.12)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.15)
                    LinearKeyframe(1, duration: 0.45)
                    LinearKeyframe(0, duration: 0.3)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.15, duration: 0.2)
                    CubicKeyframe(1, duration: 0.15)
                    LinearKeyframe(0.8, duration: 0.55)
                }
                KeyframeTrack(\.rise) {
                    LinearKeyframe(-size * 0.25, duration: 0.9)
                }
            }
            .allowsHitTesting(false)
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

import SwiftUI

/// How a character moves while it sits on Today.
enum Liveliness {
    case asleep
    case stalking
    case sick
}

/// Where a character is at one instant: its squash, its tilt and its offset.
struct CharacterPose {
    var stretchX = 1.0
    var stretchY = 1.0
    var tilt = 0.0
    var shiftX = 0.0
    var lift = 0.0

    /// Breathing for everyone, a sway while stalking, a shiver and a sneeze while sick, a hop when poked.
    static func at(_ now: Date, mood: Liveliness, pokedAt: Date) -> CharacterPose {
        let time = now.timeIntervalSinceReferenceDate
        var pose = CharacterPose()
        let breath = sin(time * 2 * .pi / 3.2)
        pose.stretchX += 0.03 * breath
        pose.stretchY -= 0.03 * breath
        switch mood {
        case .asleep:
            break
        case .stalking:
            pose.tilt = 3 * sin(time * 2 * .pi / 2.4)
        case .sick:
            pose.shiftX = 1.5 * sin(time * 2 * .pi / 0.5)
            let cycle = time.truncatingRemainder(dividingBy: 3.4) / 3.4
            pose.hop(progress: (cycle - 0.6) / 0.25, height: 20)
        }
        pose.hop(progress: now.timeIntervalSince(pokedAt) / 0.7, height: 26)
        return pose
    }

    /// One jump, from take-off at 0 to landing at 1; nothing outside that range.
    private mutating func hop(progress: Double, height: Double) {
        guard progress > 0, progress < 1 else { return }
        let arc = sin(progress * .pi)
        lift -= height * arc
        stretchX -= 0.06 * arc
        stretchY += 0.08 * arc
    }
}

/// A character that breathes and hops when touched. It stays still when Reduce Motion is on.
struct LivelyCharacter<Art: View>: View {
    let mood: Liveliness
    let art: Art
    @State private var pokedAt = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(mood: Liveliness, @ViewBuilder art: () -> Art) {
        self.mood = mood
        self.art = art()
    }

    var body: some View {
        if reduceMotion {
            art
        } else {
            TimelineView(.animation) { timeline in
                let pose = CharacterPose.at(timeline.date, mood: mood, pokedAt: pokedAt)
                art
                    .scaleEffect(x: pose.stretchX, y: pose.stretchY, anchor: .bottom)
                    .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                    .offset(x: pose.shiftX, y: pose.lift)
            }
            .onTapGesture {
                pokedAt = Date()
                Haptics.tap()
            }
        }
    }
}

/// The sleeping mascot's snore: three letters that rise and fade in turn.
struct SnoreView: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                letters(time: 1.2)
            } else {
                TimelineView(.animation) { timeline in
                    letters(time: timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func letters(time: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let phase = (time / 3 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                let fade = min(1, min(phase, 1 - phase) * 4)
                Text(verbatim: "z")
                    .font(.system(size: 15 + 6 * Double(index), weight: .semibold))
                    .foregroundStyle(palette.ink.opacity(0.68 * fade))
                    .offset(x: Double(index) * 13 + 3 * phase, y: 14 - Double(index) * 10 - 30 * phase)
            }
        }
        .frame(width: 60, height: 60)
    }
}

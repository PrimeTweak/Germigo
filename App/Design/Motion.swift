import SwiftUI

/// How a character moves while it is on screen. The germs use the first four; the household's
/// characters each have their own way of being sick.
enum Liveliness {
    case asleep
    case idle
    case stalking
    case sick
    case feverish
    case wobbly
    case sniffly
    case dizzy
    case sneezy
    case weary
    case shivering
}

/// Where a character is at one instant: its squash, its tilt and its offset.
struct CharacterPose {
    var stretchX = 1.0
    var stretchY = 1.0
    var tilt = 0.0
    var shiftX = 0.0
    var lift = 0.0

    /// Breathing for everyone, then the mood's own routine, and a hop when poked.
    /// The phase shifts the routine in time so neighbors do not move together.
    static func at(_ now: Date, mood: Liveliness, pokedAt: Date, phase: Double = 0) -> CharacterPose {
        let time = now.timeIntervalSinceReferenceDate + phase
        var pose = CharacterPose()
        let breath = sin(time * 2 * .pi / 3.2)
        pose.stretchX += 0.03 * breath
        pose.stretchY -= 0.03 * breath
        switch mood {
        case .asleep:
            break
        case .idle:
            pose.hop(progress: beat(time, every: 5.2) / 0.09, height: 7)
        case .stalking:
            pose.tilt = 3 * sin(time * 2 * .pi / 2.4)
        case .sick:
            pose.shiftX = 1.5 * sin(time * 2 * .pi / 0.5)
            pose.hop(progress: (beat(time, every: 3.4) - 0.6) / 0.25, height: 20)
        case .feverish:
            pose.tilt = 2.5 * sin(time * 2 * .pi / 3.6)
            pose.stretchY -= 0.02 * breath
        case .wobbly:
            pose.tilt = 4 * sin(time * 2 * .pi / 1.8)
        case .sniffly:
            let sniff = beat(time, every: 2.8)
            pose.hop(progress: (sniff - 0.5) / 0.1, height: 5)
            pose.hop(progress: (sniff - 0.64) / 0.1, height: 5)
        case .dizzy:
            pose.tilt = 7 * sin(time * 2 * .pi / 2.8)
            pose.shiftX = 3 * cos(time * 2 * .pi / 2.8)
        case .sneezy:
            let sneeze = beat(time, every: 3.2)
            if sneeze >= 0.5, sneeze < 0.72 {
                pose.tilt = -9 * (sneeze - 0.5) / 0.22
            } else if sneeze >= 0.72, sneeze < 0.8 {
                pose.tilt = -9 + 19 * (sneeze - 0.72) / 0.08
            } else if sneeze >= 0.8, sneeze < 0.95 {
                pose.tilt = 10 * (1 - (sneeze - 0.8) / 0.15)
            }
            pose.hop(progress: (sneeze - 0.72) / 0.16, height: 10)
        case .weary:
            pose.stretchY -= 0.035 * (1 + sin(time * 2 * .pi / 5)) / 2
            pose.tilt = 1.5 * sin(time * 2 * .pi / 5)
        case .shivering:
            pose.shiftX = 1.6 * sin(time * 2 * .pi / 0.11)
        }
        pose.hop(progress: now.timeIntervalSince(pokedAt) / 0.7, height: 26)
        return pose
    }

    /// Where the time stands in a routine that repeats, from 0 to 1.
    private static func beat(_ time: Double, every period: Double) -> Double {
        time.truncatingRemainder(dividingBy: period) / period
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
    let phase: Double
    /// False inside a button or a link, where a tap belongs to the control.
    let pokes: Bool
    let art: Art
    @State private var pokedAt = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(mood: Liveliness, phase: Double = 0, pokes: Bool = true, @ViewBuilder art: () -> Art) {
        self.mood = mood
        self.phase = phase
        self.pokes = pokes
        self.art = art()
    }

    var body: some View {
        if reduceMotion {
            art
        } else if pokes {
            moving
                .onTapGesture {
                    pokedAt = Date()
                    Haptics.tap()
                }
        } else {
            moving
        }
    }

    private var moving: some View {
        TimelineView(.animation) { timeline in
            let pose = CharacterPose.at(timeline.date, mood: mood, pokedAt: pokedAt, phase: phase)
            art
                .scaleEffect(x: pose.stretchX, y: pose.stretchY, anchor: .bottom)
                .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                .offset(x: pose.shiftX, y: pose.lift)
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

/// Slides and fades a row in, a beat after the one before it. Instant when Reduce Motion is on.
private struct CascadeIn: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let visible = shown || reduceMotion
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
            .scaleEffect(visible ? 1 : 0.96)
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.74).delay(Double(index) * 0.06)) {
                    shown = true
                }
            }
    }
}

extension View {
    /// The entrance of the rows of a list: each one a beat after the one before.
    func cascadeIn(_ index: Int) -> some View {
        modifier(CascadeIn(index: index))
    }
}

/// A ring that fills to its fraction when it appears.
struct ProgressRing: View {
    let fraction: Double
    var lineWidth: CGFloat = 7
    @State private var shown = false
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.ink.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown || reduceMotion ? min(1, max(0, fraction)) : 0)
                .stroke(palette.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
                shown = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// A number that rolls up to its value when it appears.
struct RollingNumber: View {
    let value: Int
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: String(reduceMotion ? value : shown))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(shown)))
            .onAppear {
                roll()
            }
            .onChange(of: value) { _, _ in
                roll()
            }
    }

    private func roll() {
        withAnimation(.easeOut(duration: 0.7)) {
            shown = value
        }
    }
}

import SwiftUI

/// The six curves of the interface. Each one has its use in docs/MOTION.md.
enum Tempo {
    /// The press of a button.
    static let press = Animation.easeOut(duration: 0.15)
    /// Toggles, chips, a selection, small layout changes.
    static let quick = Animation.snappy
    /// Cards moving, lists reordering, entrances.
    static let settle = Animation.spring(response: 0.42, dampingFraction: 0.74)
    /// Something arriving: a chip, a photo, a badge.
    static let pop = Animation.spring(response: 0.38, dampingFraction: 0.55)
    /// Rings, bars and numbers that count up.
    static let reveal = Animation.easeOut(duration: 0.8)
    /// Content that swaps in place.
    static let scene = Animation.spring(response: 0.6, dampingFraction: 0.85)
}

/// A character that breathes, moves as its mood says and reacts to touch.
/// It stands still with Reduce Motion, under 40 points, and stops drawing off screen.
struct LivelyCharacter<Art: View>: View {
    let mood: Liveliness
    let phase: Double
    /// What a tap does; nil inside a button or a link, where a tap belongs to the control.
    let touch: Reaction?
    /// A reaction started from outside, such as getting sick or better.
    let event: TimedReaction?
    let art: Art
    @State private var touched: TimedReaction?
    @State private var streak = TapStreak()
    @State private var height: CGFloat = 70
    @State private var appeared = false
    @State private var scrolledIn = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(mood: Liveliness, phase: Double = 0, touch: Reaction? = .squish, event: TimedReaction? = nil,
         @ViewBuilder art: () -> Art) {
        self.mood = mood
        self.phase = phase
        self.touch = touch
        self.event = event
        self.art = art()
    }

    var body: some View {
        Group {
            if reduceMotion || height < 40 {
                art
            } else {
                moving
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .onScrollVisibilityChange(threshold: 0.05) { scrolledIn = $0 }
        .modifier(TouchReaction(touch: touch) { reaction in
            let now = Date()
            let earned = streak.tap(at: now, usual: reaction)
            touched = TimedReaction(reaction: earned, start: now)
            if earned == .dizzy { Haptics.thud() } else { Haptics.tap() }
        })
    }

    private var moving: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !(appeared && scrolledIn))) { timeline in
            let latest = [touched, event].compactMap { $0 }.max { $0.start < $1.start }
            let pose = CharacterPose.at(timeline.date.timeIntervalSinceReferenceDate, mood: mood, phase: phase,
                                        reaction: latest?.reaction,
                                        elapsed: latest.map { timeline.date.timeIntervalSince($0.start) } ?? .infinity)
            let unit = min(1.5, height / 70)
            art
                .scaleEffect(x: pose.stretchX, y: pose.stretchY, anchor: .bottom)
                .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
                .offset(x: pose.shiftX * unit, y: pose.lift * unit)
        }
    }
}

/// The tap of a character, left out when it has no reaction so the tap reaches the control around it.
private struct TouchReaction: ViewModifier {
    let touch: Reaction?
    let action: (Reaction) -> Void

    @ViewBuilder
    func body(content: Content) -> some View {
        if let touch {
            content.onTapGesture { action(touch) }
        } else {
            content
        }
    }
}

/// The sleeping mascot's snore: three letters that rise and fade in turn.
/// A popped letter bursts and stays away until its next rise.
struct SnoreView: View {
    /// When each letter was popped, in seconds since the reference date, by letter.
    var popped: [Int: Double] = [:]
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let side: CGFloat = 60

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 30)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            letters(time: reduceMotion ? 1.2 : now, now: now)
        }
        .accessibilityHidden(true)
    }

    /// Where a letter is, from the center of the view, and how visible it is.
    static func spot(_ index: Int, time: Double) -> (offset: CGSize, fade: Double) {
        let phase = (time / 3 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
        let fade = min(1, min(phase, 1 - phase) * 4)
        return (CGSize(width: Double(index) * 13 + 3 * phase, height: 14 - Double(index) * 10 - 30 * phase), fade)
    }

    /// Which rise of a letter a moment belongs to.
    static func rise(_ index: Int, time: Double) -> Int {
        Int((time / 3 + Double(index) / 3).rounded(.down))
    }

    private func letters(time: Double, now: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                let spot = Self.spot(index, time: time)
                let gone = popped[index].map { Self.rise(index, time: now) == Self.rise(index, time: $0) } ?? false
                Text(verbatim: "z")
                    .font(.system(size: 15 + 6 * Double(index), weight: .semibold))
                    .foregroundStyle(palette.ink.opacity(gone ? 0 : 0.68 * spot.fade))
                    .offset(spot.offset)
                if let at = popped[index], !reduceMotion, now - at >= 0, now - at < 0.3 {
                    burst(progress: (now - at) / 0.3)
                        .offset(Self.spot(index, time: at).offset)
                }
            }
        }
        .frame(width: Self.side, height: Self.side)
    }

    private func burst(progress: Double) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { ray in
                Capsule()
                    .fill(palette.ink.opacity(0.55 * (1 - progress)))
                    .frame(width: 3, height: 8)
                    .offset(y: -8 - 10 * progress)
                    .rotationEffect(.degrees(Double(ray) * 45))
            }
        }
    }
}

/// The mascot asleep and snoring; a tap wakes it for a moment.
struct NappingMascot: View {
    let side: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var awakeUntil = Date.distantPast

    var body: some View {
        LivelyCharacter(mood: .resting, touch: nil) {
            TimelineView(.periodic(from: Date(), by: 0.5)) { timeline in
                Image(timeline.date < awakeUntil ? "mascot-awake" : "mascot-asleep")
                    .resizable()
                    .scaledToFit()
                    .overlay(alignment: .topTrailing) {
                        if timeline.date >= awakeUntil {
                            SnoreView()
                                .offset(x: 34, y: -6)
                        }
                    }
            }
        }
        .frame(width: side, height: side)
        .simultaneousGesture(TapGesture().onEnded { _ in
            awakeUntil = Date().addingTimeInterval(reduceMotion ? 4 : 2.4)
        })
        .accessibilityLabel(tr("The germs are napping."))
        .accessibilityAddTraits(.isImage)
    }
}

/// Slides and fades a row in, a beat after the one before it, eight beats at most. Instant when Reduce Motion is on.
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
                withAnimation(Tempo.settle.delay(Double(min(index, 7)) * 0.06)) {
                    shown = true
                }
            }
    }
}

/// A transition that becomes a fade when Reduce Motion is on.
private struct ReducibleTransition: ViewModifier {
    let transition: AnyTransition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : transition)
    }
}

extension View {
    /// The entrance of the rows of a list: each one a beat after the one before.
    func cascadeIn(_ index: Int) -> some View {
        modifier(CascadeIn(index: index))
    }

    /// The transition of a view that comes and goes, a plain fade with Reduce Motion.
    func motionTransition(_ transition: AnyTransition) -> some View {
        modifier(ReducibleTransition(transition: transition))
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
            withAnimation(Tempo.reveal.delay(0.15)) {
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
        withAnimation(Tempo.reveal) {
            shown = value
        }
    }
}

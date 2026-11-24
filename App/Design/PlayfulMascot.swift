import SwiftUI

/// The mascot napping on Today, with tricks to find: pop its z's, wake it, squish it, make it dizzy,
/// tickle it until its pacifier flies, pull it, rub it until it sneezes, tilt the phone, or try it at night.
/// The rules and timings are in docs/MOTION.md.
struct PlayfulMascot: View {
    let side: CGFloat
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var mind = MascotMind()
    @State private var reaction: TimedReaction?
    @State private var streak = TapStreak()
    @State private var press: Press?
    @State private var pull = CGSize.zero
    @State private var popped: [Int: Double] = [:]
    @State private var tickling: Task<Void, Never>?

    /// Where the pacifier sits in the mascot's square, and its size, from the drawing.
    private static let pacifierCenter = UnitPoint(x: 0.5, y: 0.781)
    private static let pacifierSize = CGSize(width: 0.441, height: 0.355)
    /// Where it lands: on the counter, just under the mascot.
    private static let pacifierLanding = UnitPoint(x: 0.62, y: 1.12)
    private static let pacifierLandingTurn = 70.0

    /// The touch under way.
    private struct Press {
        var moved = false
        var tickled = false
        var rubbed = false
        var ignored = false
        var rub = RubDetector()
    }

    /// What decides whether the tilt sensor runs.
    private struct TiltWatch: Equatable {
        let wokeAt: Double?
        let active: Bool
    }

    private var now: Double { Date().timeIntervalSinceReferenceDate }
    private var sensor: TiltSensor { TiltSensor.shared }
    private var lean: Double { reduceMotion ? 0 : sensor.lean }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 0.1)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let awake = mind.isAwake(at: time)
            let shape = MascotMind.stretch(dx: pull.width, dy: pull.height, side: side)
            LivelyCharacter(mood: awake ? .stalking : .resting, touch: nil, event: reaction) {
                Image("mascot-" + mind.face(at: time, lean: lean).rawValue)
                    .resizable()
                    .scaledToFit()
            }
            .scaleEffect(x: shape.scaleX, y: shape.scaleY, anchor: .bottom)
            .rotationEffect(.degrees(shape.tilt + (awake ? lean * MascotMind.leanDegrees : 0)), anchor: .bottom)
            .overlay(alignment: .topTrailing) {
                if !awake {
                    SnoreView(popped: popped)
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { location in
                            popLetter(near: location)
                        }
                        .offset(x: 34, y: -6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if mind.isShushing(at: time) {
                    shush
                        .offset(x: 30, y: -26)
                }
            }
            .overlay {
                effects(at: time)
            }
        }
        .frame(width: side, height: side)
        .overlay(alignment: .top) {
            if model.data.mascotTricks.isEmpty {
                WhisperBubble(text: tr("Psst… poke me."))
                    .offset(y: -side * 0.3)
                    .transition(.opacity)
            }
        }
        .animation(Tempo.quick, value: model.data.mascotTricks.isEmpty)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { changed($0) }
            .onEnded { ended($0) })
        .accessibilityElement()
        .accessibilityLabel(mind.isAwake(at: now) ? tr("The germ is awake.") : tr("The germs are napping."))
        .accessibilityAddTraits(.isImage)
        .accessibilityActions {
            if !mind.isAwake(at: now) {
                Button(tr("Wake up")) {
                    _ = engage(at: now)
                }
            }
            Button(tr("Tickle")) {
                tickleOnce()
            }
            Button(tr("Make it sneeze")) {
                if engage(at: now) { sneeze(at: now) }
            }
            if mind.pacifierIsOut(at: now) {
                Button(tr("Give back the pacifier")) {
                    givePacifierBack()
                }
            }
        }
        .task(id: TiltWatch(wokeAt: mind.wokeAt, active: scenePhase == .active)) {
            await followTilt()
        }
        .onDisappear {
            tickling?.cancel()
            press = nil
            pull = .zero
        }
    }

    // MARK: - Touch

    private func changed(_ value: DragGesture.Value) {
        let time = now
        guard var current = press else {
            press = Press()
            tickling = Task { await waitForTickle() }
            return
        }
        guard !current.ignored, !current.tickled else { return }
        mind.hold(at: time)
        if !current.moved, hypot(value.translation.width, value.translation.height) > 10 {
            current.moved = true
            tickling?.cancel()
            if !engage(at: time) {
                current.ignored = true
                press = current
                return
            }
        }
        guard current.moved else { return }
        if !current.rubbed, current.rub.track(x: value.location.x, at: time) {
            current.rubbed = true
            sneeze(at: time)
        }
        press = current
        if !current.rubbed, !reduceMotion {
            pull = value.translation
        }
    }

    private func ended(_ value: DragGesture.Value) {
        let time = now
        tickling?.cancel()
        defer { press = nil }
        guard let current = press, !current.ignored else { return }
        if current.tickled {
            mind.endTickle(at: time)
        } else if !current.moved {
            tap(at: time)
        } else if !current.rubbed {
            let reach = hypot(pull.width, pull.height) / side
            withAnimation(Tempo.pop) {
                pull = .zero
            }
            Haptics.tap()
            if reach > 0.3 { model.discoverTrick(.pull) }
        }
    }

    /// Wakes the mascot for a touch; false when the night shush keeps it asleep.
    private func engage(at time: Double) -> Bool {
        switch mind.touch(at: time, night: QuietHours.contains(Date())) {
        case .awake:
            return true
        case .woke:
            Haptics.tap()
            model.discoverTrick(.wake)
            return true
        case .shushed:
            Haptics.tick()
            model.discoverTrick(.shush)
            return false
        }
    }

    /// Asleep, a tap wakes it; awake, it squishes, and the fourth quick tap makes it dizzy.
    private func tap(at time: Double) {
        guard mind.isAwake(at: time) else {
            _ = engage(at: time)
            return
        }
        let earned = streak.tap(at: Date(), usual: .squish)
        reaction = TimedReaction(reaction: earned, start: Date())
        if earned == .dizzy {
            mind.dizzy(at: time)
            Haptics.thud()
            model.discoverTrick(.dizzy)
        } else {
            mind.giggle(at: time)
            Haptics.tap()
            model.discoverTrick(.squish)
        }
    }

    /// A finger that stays still becomes a tickle; held long enough, the pacifier flies.
    private func waitForTickle() async {
        try? await Task.sleep(for: .seconds(0.35))
        guard !Task.isCancelled, var current = press, !current.moved, !current.ignored else { return }
        guard engage(at: now) else {
            current.ignored = true
            press = current
            return
        }
        current.tickled = true
        press = current
        mind.startTickle(at: now)
        model.discoverTrick(.tickle)
        var beat = 0
        while !Task.isCancelled, press?.tickled == true {
            Haptics.tick()
            if beat % 3 == 0 {
                reaction = TimedReaction(reaction: .giggle, start: Date())
            }
            if mind.popsPacifier(at: now) {
                mind.popPacifier(at: now)
                Haptics.thud()
            }
            beat += 1
            try? await Task.sleep(for: .seconds(0.18))
        }
    }

    /// The tickle from VoiceOver: two seconds of giggles, then the pacifier flies.
    private func tickleOnce() {
        guard engage(at: now) else { return }
        mind.startTickle(at: now)
        model.discoverTrick(.tickle)
        reaction = TimedReaction(reaction: .giggle, start: Date())
        Task {
            try? await Task.sleep(for: .seconds(MascotMind.laughToPop))
            if mind.popsPacifier(at: now) {
                mind.popPacifier(at: now)
                Haptics.thud()
            }
            mind.endTickle(at: now)
        }
    }

    private func sneeze(at time: Double) {
        mind.sneeze(at: time)
        reaction = TimedReaction(reaction: .sneeze, start: Date())
        withAnimation(Tempo.pop) {
            pull = .zero
        }
        model.discoverTrick(.sneeze)
        Task {
            try? await Task.sleep(for: .seconds(MascotMind.sneezeWindUp))
            Haptics.thud()
        }
    }

    private func givePacifierBack() {
        guard mind.pacifierIsOut(at: now) else { return }
        mind.returnPacifier(at: now)
        Haptics.tick()
        model.discoverTrick(.pacifier)
    }

    /// Pops the letter of the snore closest to the finger; the mascot sleeps on.
    private func popLetter(near location: CGPoint) {
        let time = now
        let middle = SnoreView.side / 2
        let target = (0..<3)
            .filter { index in
                popped[index].map { SnoreView.rise(index, time: time) != SnoreView.rise(index, time: $0) } ?? true
            }
            .map { index -> (index: Int, distance: Double) in
                let spot = SnoreView.spot(index, time: reduceMotion ? 1.2 : time)
                let dx = Double(middle + spot.offset.width - location.x)
                let dy = Double(middle + spot.offset.height - location.y)
                let distance = (dx * dx + dy * dy).squareRoot()
                return (index, spot.fade > 0.2 ? distance : .infinity)
            }
            .min { $0.distance < $1.distance }
        guard let target, target.distance < 30 else { return }
        popped[target.index] = time
        Haptics.tick()
        model.discoverTrick(.popZ)
    }

    /// Runs the tilt sensor while the mascot is awake and the app is in front.
    private func followTilt() async {
        guard !reduceMotion, scenePhase == .active, mind.wokeAt != nil else { return }
        sensor.start()
        while !Task.isCancelled, mind.isAwake(at: now) {
            if abs(sensor.lean) > MascotMind.leanToLook {
                model.discoverTrick(.tilt)
            }
            try? await Task.sleep(for: .seconds(0.25))
        }
        sensor.stop()
    }

    // MARK: - Drawing

    private var shush: some View {
        Text(tr("Shh… it's late."))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.ink)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(palette.surface, in: Capsule())
            .liftShadow()
            .accessibilityHidden(true)
    }

    /// The pacifier out of the mouth and the sneeze cloud, drawn only while one of them is under way.
    @ViewBuilder
    private func effects(at time: Double) -> some View {
        let cloud = !reduceMotion && mind.sneezeCloud(at: time) != nil
        if cloud || mind.pacifierIsOut(at: time) || mind.pacifierReturn(at: time) != nil {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
                let frame = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    if !reduceMotion, let progress = mind.sneezeCloud(at: frame) {
                        SneezeCloud(progress: progress, side: side)
                            .offset(y: side * (Self.pacifierCenter.y - 0.5))
                    }
                    if let spot = pacifierSpot(at: frame) {
                        Image("mascot-pacifier")
                            .resizable()
                            .frame(width: side * Self.pacifierSize.width, height: side * Self.pacifierSize.height)
                            .rotationEffect(.degrees(spot.turn))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                givePacifierBack()
                            }
                            .position(spot.center)
                    }
                }
                .frame(width: side, height: side)
            }
        }
    }

    /// Where the pacifier is and how far it has turned: flying out in an arc, lying on the counter, or going back.
    private func pacifierSpot(at time: Double) -> (center: CGPoint, turn: Double)? {
        let mouth = CGPoint(x: side * Self.pacifierCenter.x, y: side * Self.pacifierCenter.y)
        let land = CGPoint(x: side * Self.pacifierLanding.x, y: side * Self.pacifierLanding.y)
        if let progress = mind.pacifierReturn(at: time) {
            guard !reduceMotion else { return nil }
            let back = CGFloat(progress)
            let x: CGFloat = land.x + (mouth.x - land.x) * back
            let y: CGFloat = land.y + (mouth.y - land.y) * back
            return (CGPoint(x: x, y: y), Self.pacifierLandingTurn * (1 - progress))
        }
        guard mind.pacifierIsOut(at: time) else { return nil }
        guard !reduceMotion, let flight = mind.pacifierFlight(at: time) else { return (land, Self.pacifierLandingTurn) }
        let peak = CGPoint(x: side * 1.05, y: -side * 0.2)
        let t = CGFloat(flight)
        let u: CGFloat = 1 - t
        let x: CGFloat = u * u * mouth.x + 2 * u * t * peak.x + t * t * land.x
        let y: CGFloat = u * u * mouth.y + 2 * u * t * peak.y + t * t * land.y
        return (CGPoint(x: x, y: y), (360 + Self.pacifierLandingTurn) * flight)
    }
}

/// The sneeze: puffs that burst out on both sides and three small germs that fly off, then fade.
private struct SneezeCloud: View {
    let progress: Double
    let side: CGFloat

    private static let puffs: [(dx: Double, dy: Double, size: Double)] = [
        (-0.42, 0.02, 0.2), (-0.3, -0.12, 0.14), (0.42, 0, 0.18), (0.32, -0.14, 0.12)
    ]
    private static let germs: [(id: String, dx: Double, dy: Double, turn: Double)] = [
        ("rhino", -0.55, -0.45, -40), ("flu", 0.58, -0.4, 35), ("noro", -0.62, 0.05, -20)
    ]

    var body: some View {
        let out = CGFloat(1 - pow(1 - progress, 3))
        ZStack {
            ForEach(Array(Self.puffs.enumerated()), id: \.offset) { item in
                Circle()
                    .fill(Color(hex: Swatch.limePale))
                    .overlay(Circle().stroke(Color(hex: Swatch.ink).opacity(0.15), lineWidth: 1.5))
                    .frame(width: side * CGFloat(item.element.size), height: side * CGFloat(item.element.size))
                    .scaleEffect(0.4 + 0.6 * out)
                    .offset(x: side * CGFloat(item.element.dx) * out, y: side * CGFloat(item.element.dy) * out)
            }
            ForEach(Array(Self.germs.enumerated()), id: \.offset) { item in
                Image("germ-" + item.element.id)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side * 0.16)
                    .rotationEffect(.degrees(item.element.turn * progress))
                    .offset(x: side * CGFloat(item.element.dx) * out, y: side * CGFloat(item.element.dy) * out)
            }
        }
        .opacity(1 - max(0, progress - 0.4) / 0.6)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

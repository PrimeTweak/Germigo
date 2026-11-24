import Foundation

/// The faces of the Today mascot; each one is the image named mascot-<raw value>.
enum MascotFace: String, CaseIterable {
    case asleep, awake, grumpy, giggle, laugh, gasp, dizzy, sneeze, drowsy
    case lookLeft = "look-left"
    case lookRight = "look-right"
}

/// The tricks of the Today mascot. Finding them all earns the Ticklish badge.
enum MascotTrick: String, CaseIterable {
    case popZ = "pop_z"
    case wake, squish, dizzy, tickle, pacifier, pull, sneeze, tilt, shush

    /// The trick's name in the notebook.
    var title: String {
        switch self {
        case .popZ: return tr("Pop a z")
        case .wake: return tr("Grumpy wake-up")
        case .squish: return tr("Squish")
        case .dizzy: return tr("Dizzy")
        case .tickle: return tr("Tickle")
        case .pacifier: return tr("Pacifier")
        case .pull: return tr("Stretch")
        case .sneeze: return tr("Sneeze")
        case .tilt: return tr("Lean")
        case .shush: return tr("Shh")
        }
    }

    /// How to do it again, once found.
    var how: String {
        switch self {
        case .popZ: return tr("Tap a letter of its snore.")
        case .wake: return tr("Tap it while it naps.")
        case .squish: return tr("Tap it once it's awake.")
        case .dizzy: return tr("Four quick taps.")
        case .tickle: return tr("Keep a finger still on it.")
        case .pacifier: return tr("Tap the pacifier to give it back.")
        case .pull: return tr("Drag it around.")
        case .sneeze: return tr("Rub it back and forth.")
        case .tilt: return tr("Lean your phone while it's awake.")
        case .shush: return tr("Touch it after 10 PM.")
        }
    }

    /// The clue shown while it is still to find.
    var clue: String {
        switch self {
        case .popZ: return tr("Its snores look poppable.")
        case .wake: return tr("It hates being woken up.")
        case .squish: return tr("Awake, it's squishy.")
        case .dizzy: return tr("One tap too many…")
        case .tickle: return tr("Hold still. Wait for it.")
        case .pacifier: return tr("What flies out when it laughs?")
        case .pull: return tr("It stretches more than you think.")
        case .sneeze: return tr("Rub it the wrong way.")
        case .tilt: return tr("Lean in. It's curious.")
        case .shush: return tr("Try it late at night.")
        }
    }

    /// The mascot drawing that stands for the trick.
    var face: String {
        switch self {
        case .popZ: return "mascot-asleep"
        case .wake: return "mascot-grumpy"
        case .squish: return "mascot-giggle"
        case .dizzy: return "mascot-dizzy"
        case .tickle: return "mascot-laugh"
        case .pacifier: return "mascot-pacifier"
        case .pull: return "mascot-gasp"
        case .sneeze: return "mascot-sneeze"
        case .tilt: return "mascot-look-right"
        case .shush: return "mascot-drowsy"
        }
    }
}

/// What the Today mascot shows over time, from the touches it got. Times are in seconds.
/// The rules and timings are in docs/MOTION.md.
struct MascotMind {
    static let grumpyFor = 0.7
    static let awakeFor = 6.0
    static let drowsyFor = 0.8
    static let shushFor = 2.5
    static let giggleFor = 0.5
    static let laughToPop = 2.0
    static let laughAfterPop = 0.8
    static let pacifierBackAfter = 20.0
    static let pacifierFlight = 0.8
    static let pacifierReturn = 0.3
    static let sneezeWindUp = 0.55
    static let cloudFor = 1.2
    /// How far the phone must lean, from -1 to 1, before the mascot looks that way.
    static let leanToLook = 0.3
    static let leanDegrees = 14.0

    enum Wake {
        case awake, woke, shushed
    }

    private(set) var wokeAt: Double?
    private(set) var tickleStart: Double?
    private(set) var pacifierOutAt: Double?
    private(set) var pacifierBackAt: Double?
    private var lastTouch = -Double.infinity
    private var shushAt: Double?
    private var giggleAt: Double?
    private var dizzyAt: Double?
    private var sneezeAt: Double?

    /// The mascot dozes off a while after the last touch, never during a tickle or with its pacifier out.
    private var awakeUntil: Double {
        if tickleStart != nil { return .infinity }
        return max(lastTouch, pacifierBackAt ?? -.infinity) + Self.awakeFor + Self.drowsyFor
    }

    func isAwake(at now: Double) -> Bool {
        guard let wokeAt, now >= wokeAt else { return false }
        return now < awakeUntil
    }

    func isShushing(at now: Double) -> Bool {
        guard let shushAt else { return false }
        return now >= shushAt && now - shushAt < Self.shushFor
    }

    /// Any touch. Asleep, it wakes up; at night the first touch only gets a shush, and a second one during it wakes it.
    mutating func touch(at now: Double, night: Bool) -> Wake {
        if isAwake(at: now) {
            lastTouch = now
            return .awake
        }
        if night && !isShushing(at: now) {
            shushAt = now
            return .shushed
        }
        shushAt = nil
        wokeAt = now
        lastTouch = now
        return .woke
    }

    /// Keeps it awake while a finger stays on it.
    mutating func hold(at now: Double) {
        if isAwake(at: now) { lastTouch = now }
    }

    mutating func giggle(at now: Double) {
        giggleAt = now
        lastTouch = now
    }

    mutating func dizzy(at now: Double) {
        dizzyAt = now
        lastTouch = now
    }

    mutating func startTickle(at now: Double) {
        tickleStart = now
        lastTouch = now
    }

    mutating func endTickle(at now: Double) {
        tickleStart = nil
        lastTouch = now
    }

    mutating func sneeze(at now: Double) {
        sneezeAt = now
        lastTouch = now
    }

    /// True when a tickle has lasted long enough to send the pacifier flying.
    func popsPacifier(at now: Double) -> Bool {
        guard let tickleStart, !pacifierIsOut(at: now), pacifierReturn(at: now) == nil else { return false }
        return now - tickleStart >= Self.laughToPop
    }

    mutating func popPacifier(at now: Double) {
        pacifierOutAt = now
        pacifierBackAt = now + Self.pacifierBackAfter
        lastTouch = now
    }

    mutating func returnPacifier(at now: Double) {
        guard pacifierIsOut(at: now) else { return }
        pacifierBackAt = now
        giggleAt = now + Self.pacifierReturn
        lastTouch = now
    }

    func pacifierIsOut(at now: Double) -> Bool {
        guard let out = pacifierOutAt, let back = pacifierBackAt else { return false }
        return now >= out && now < back
    }

    /// From 0 as the pacifier leaves the mouth to 1 as it lands on the counter; nil once it has landed.
    func pacifierFlight(at now: Double) -> Double? {
        guard let out = pacifierOutAt, pacifierIsOut(at: now), now - out < Self.pacifierFlight else { return nil }
        return (now - out) / Self.pacifierFlight
    }

    /// From 0 as the pacifier leaves the counter to 1 as it is back in the mouth.
    func pacifierReturn(at now: Double) -> Double? {
        guard pacifierOutAt != nil, let back = pacifierBackAt, now >= back, now - back < Self.pacifierReturn else { return nil }
        return (now - back) / Self.pacifierReturn
    }

    /// Seconds since the sneeze started, while it lasts.
    func sneezeElapsed(at now: Double) -> Double? {
        guard let sneezeAt, now >= sneezeAt, now - sneezeAt < Reaction.sneeze.duration else { return nil }
        return now - sneezeAt
    }

    /// From 0 as the sneeze bursts out to 1 once its cloud has faded.
    func sneezeCloud(at now: Double) -> Double? {
        guard let sneezeAt else { return nil }
        let elapsed = now - sneezeAt - Self.sneezeWindUp
        guard elapsed >= 0, elapsed < Self.cloudFor else { return nil }
        return elapsed / Self.cloudFor
    }

    func face(at now: Double, lean: Double) -> MascotFace {
        guard isAwake(at: now) else { return isShushing(at: now) ? .grumpy : .asleep }
        if pacifierIsOut(at: now) || pacifierReturn(at: now) != nil {
            let fresh = pacifierOutAt.map { now - $0 < Self.laughAfterPop } ?? false
            return tickleStart != nil || fresh ? .laugh : .gasp
        }
        if let wokeAt, now - wokeAt < Self.grumpyFor { return .grumpy }
        if let elapsed = sneezeElapsed(at: now) { return elapsed < Self.sneezeWindUp ? .drowsy : .sneeze }
        if let dizzyAt, now - dizzyAt < Reaction.dizzy.duration { return .dizzy }
        if tickleStart != nil { return .giggle }
        if let giggleAt, now >= giggleAt, now - giggleAt < Self.giggleFor { return .giggle }
        if now >= awakeUntil - Self.drowsyFor { return .drowsy }
        if lean > Self.leanToLook { return .lookRight }
        if lean < -Self.leanToLook { return .lookLeft }
        return .awake
    }

    /// How a pull shapes the mascot: taller and leaning toward a finger above it, squashed by a finger below it.
    static func stretch(dx: Double, dy: Double, side: Double) -> (scaleX: Double, scaleY: Double, tilt: Double) {
        let up = -dy
        if up >= 0 {
            let reach = min(1, (dx * dx + dy * dy).squareRoot() / (side * 0.9))
            let angle = atan2(dx, max(up, 1)) * 180 / .pi
            return (1 - 0.18 * reach, 1 + 0.4 * reach, max(-30, min(30, angle)) * reach)
        }
        let press = min(1, -up / (side * 0.6))
        return (1 + 0.15 * press, 1 - 0.25 * press, max(-20, min(20, dx / side * 30)))
    }
}

/// Spots a rub: the finger going back and forth three times within 1.2 seconds, 14 points or more each way.
struct RubDetector {
    static let reach = 14.0
    static let turnBack = 8.0
    static let turns = 3
    static let within = 1.2

    private var direction = 0.0
    private var strokeStart: Double?
    private var extreme = 0.0
    private var turnTimes: [Double] = []

    /// Follows the finger; true once the rub is complete, then starts over.
    mutating func track(x: Double, at time: Double) -> Bool {
        guard let start = strokeStart else {
            strokeStart = x
            extreme = x
            return false
        }
        if direction == 0 {
            if abs(x - start) >= 4 {
                direction = x > start ? 1 : -1
                extreme = x
            }
            return false
        }
        if (x - extreme) * direction > 0 {
            extreme = x
            return false
        }
        guard abs(x - extreme) >= Self.turnBack else { return false }
        if abs(extreme - start) >= Self.reach {
            turnTimes = turnTimes.filter { time - $0 <= Self.within } + [time]
        }
        strokeStart = extreme
        extreme = x
        direction = -direction
        guard turnTimes.count >= Self.turns else { return false }
        self = RubDetector()
        return true
    }
}

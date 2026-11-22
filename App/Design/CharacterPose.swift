import Foundation

/// How a character moves while it is on screen. The rules and amplitudes are in docs/MOTION.md.
enum Liveliness: Equatable {
    /// Breath only.
    case resting
    /// The household, healthy: one accent per look, once every seven seconds.
    case bouncing, wiggling, nodding, puffing, swaying, tilting, lookingAround, hopping
    /// The germs at rest, by shelf.
    case floating, creeping, jiggling
    /// A germ watching the household.
    case stalking
    /// The germ on Today while someone is sick.
    case sick
    /// The household while sick, one routine per look. Dizzy is also the defeated germ.
    case feverish, wobbly, sniffly, dizzy, sneezy, weary, coughing, shivering

    private static let accents: [Liveliness] = [
        .bouncing, .wiggling, .nodding, .puffing, .swaying, .tilting, .lookingAround, .hopping
    ]
    private static let sickRoutines: [Liveliness] = [
        .feverish, .wobbly, .sniffly, .dizzy, .sneezy, .weary, .coughing, .shivering
    ]

    /// A household look: its sick routine, its accent when it leads, otherwise breath.
    static func household(_ index: Int, sick: Bool, leads: Bool) -> Liveliness {
        let slot = abs(index) % accents.count
        if sick { return sickRoutines[slot] }
        return leads ? accents[slot] : .resting
    }

    /// A germ at rest moves as its shelf in the Guide.
    static func germ(_ family: GermFamily) -> Liveliness {
        switch family {
        case .airways: .floating
        case .skin: .creeping
        case .gut, .other: .jiggling
        }
    }

    /// How long the accent lasts in its cycle; nil for routines that never stop.
    var accentLength: Double? {
        switch self {
        case .bouncing, .wiggling: 0.7
        case .nodding: 1.0
        case .puffing: 1.3
        case .swaying: 1.6
        case .tilting: 1.4
        case .lookingAround: 1.8
        case .hopping: 0.5
        default: nil
        }
    }
}

extension Germ {
    var restMood: Liveliness { .germ(family) }
}

/// What a character does once, on a touch or when its state changes.
enum Reaction: Equatable {
    case giggle
    case ouch
    case squish
    case dizzy
    /// The person just got sick.
    case shake
    /// The person just got better.
    case joy

    var duration: Double {
        switch self {
        case .giggle: 0.5
        case .ouch: 0.3
        case .squish: 0.6
        case .dizzy: 1.6
        case .shake: 0.4
        case .joy: 0.6
        }
    }
}

/// A reaction and the moment it started.
struct TimedReaction: Equatable {
    let reaction: Reaction
    let start: Date
}

/// Touches in a row: the fourth within three seconds makes the character dizzy.
struct TapStreak {
    private var taps: [Date] = []

    /// Records a tap and returns what it earns.
    mutating func tap(at now: Date, usual: Reaction) -> Reaction {
        taps = taps.filter { now.timeIntervalSince($0) <= 3 } + [now]
        guard taps.count >= 4 else { return usual }
        taps.removeAll()
        return .dizzy
    }
}

/// Where a character is at one instant: its squash, its tilt and its offset, in points for 70 points of height.
struct CharacterPose: Equatable {
    var stretchX = 1.0
    var stretchY = 1.0
    var tilt = 0.0
    var shiftX = 0.0
    var lift = 0.0

    /// The household's accents come back every seven seconds.
    static let accentCycle = 7.0

    /// Breath, then the accent or the routine, then the reaction under way.
    /// The phase, in seconds, shifts everything in time so neighbors take turns.
    static func at(_ time: Double, mood: Liveliness, phase: Double = 0, reaction: Reaction? = nil,
                   elapsed: Double = .infinity) -> CharacterPose {
        let time = time + phase
        var pose = CharacterPose()
        let breath = sin(time * 2 * .pi / 3.2)
        pose.stretchX += 0.03 * breath
        pose.stretchY -= 0.03 * breath
        if let length = mood.accentLength {
            let local = time.truncatingRemainder(dividingBy: accentCycle)
            if local < length {
                pose.accent(mood, progress: local / length)
            }
        } else {
            pose.routine(mood, time: time, breath: breath)
        }
        if let reaction, elapsed >= 0, elapsed < reaction.duration {
            pose.react(reaction, elapsed: elapsed)
        }
        return pose
    }

    private mutating func accent(_ mood: Liveliness, progress p: Double) {
        switch mood {
        case .bouncing:
            let beat = sin(2 * .pi * 2 * p) * (1 - p)
            stretchY -= 0.08 * beat
            stretchX += 0.06 * beat
        case .wiggling:
            tilt += 6 * sin(2 * .pi * 3 * p) * (1 - p)
        case .nodding:
            let dip = (1 - cos(2 * .pi * 2 * p)) / 2
            lift += 4 * dip
            tilt += 4 * dip
            stretchY -= 0.02 * dip
        case .puffing:
            let puff = Self.keyframes(p, [(0, 0), (0.3, 1), (0.65, 1), (1, 0)])
            stretchY += 0.09 * puff
            stretchX -= 0.03 * puff
            if p > 0.86 {
                let squash = sin(.pi * (p - 0.86) / 0.14)
                stretchY -= 0.03 * squash
                stretchX += 0.02 * squash
            }
        case .swaying:
            tilt -= 5 * sin(2 * .pi * p)
        case .tilting:
            tilt += 9 * Self.keyframes(p, [(0, 0), (0.25, 1), (0.7, 1), (1, 0)])
        case .lookingAround:
            let glance = Self.keyframes(p, [(0, 0), (0.2, -6), (0.4, -6), (0.6, 6), (0.8, 6), (1, 0)])
            shiftX += glance
            tilt += 0.4 * glance
        case .hopping:
            hop(progress: p, height: 10)
        default:
            break
        }
    }

    private mutating func routine(_ mood: Liveliness, time: Double, breath: Double) {
        switch mood {
        case .floating:
            lift -= 4 * sin(time * 2 * .pi / 3.6)
            tilt += 2 * cos(time * 2 * .pi / 3.6)
        case .creeping:
            let reach = Self.keyframes(Self.beat(time, every: 3), [(0, 0), (0.4, 1), (0.55, 1), (0.85, 0), (1, 0)])
            stretchX += 0.07 * reach
            stretchY -= 0.035 * reach
            shiftX += 2.45 * reach
        case .jiggling:
            let wobble = Self.beat(time, every: 2.4) / 0.375
            if wobble < 1 {
                let beat = sin(2 * .pi * 3 * wobble) * (1 - wobble) * (1 - wobble)
                stretchX += 0.06 * beat
                stretchY -= 0.06 * beat
            }
        case .stalking:
            tilt = 3 * sin(time * 2 * .pi / 2.4)
        case .sick:
            shiftX = 1.5 * sin(time * 2 * .pi / 0.5)
            hop(progress: (Self.beat(time, every: 3.4) - 0.6) / 0.25, height: 20)
        case .feverish:
            tilt = 2.5 * sin(time * 2 * .pi / 3.6)
            stretchY -= 0.02 * breath
        case .wobbly:
            tilt = 4 * sin(time * 2 * .pi / 1.8)
        case .sniffly:
            let sniff = Self.beat(time, every: 2.8)
            hop(progress: (sniff - 0.5) / 0.1, height: 5)
            hop(progress: (sniff - 0.64) / 0.1, height: 5)
        case .dizzy:
            tilt = 7 * sin(time * 2 * .pi / 2.8)
            shiftX = 3 * cos(time * 2 * .pi / 2.8)
        case .sneezy:
            let sneeze = Self.beat(time, every: 3.2)
            if sneeze >= 0.5, sneeze < 0.72 {
                tilt = -9 * (sneeze - 0.5) / 0.22
            } else if sneeze >= 0.72, sneeze < 0.8 {
                tilt = -9 + 19 * (sneeze - 0.72) / 0.08
            } else if sneeze >= 0.8, sneeze < 0.95 {
                tilt = 10 * (1 - (sneeze - 0.8) / 0.15)
            }
            hop(progress: (sneeze - 0.72) / 0.16, height: 10)
        case .weary:
            stretchY -= 0.035 * (1 + sin(time * 2 * .pi / 5)) / 2
            tilt = 1.5 * sin(time * 2 * .pi / 5)
        case .coughing:
            let cough = Self.beat(time, every: 3)
            for start in [0.5, 0.66] where cough >= start && cough < start + 0.08 {
                let jolt = sin(.pi * (cough - start) / 0.08)
                tilt += 4 * jolt
                stretchY -= 0.04 * jolt
                lift += 1.5 * jolt
            }
        case .shivering:
            shiftX = 1.6 * sin(time * 2 * .pi / 0.11)
        default:
            break
        }
    }

    private mutating func react(_ reaction: Reaction, elapsed: Double) {
        let p = elapsed / reaction.duration
        switch reaction {
        case .giggle:
            let beat = sin(2 * .pi * 2 * p) * (1 - p)
            stretchY -= 0.1 * beat
            stretchX += 0.08 * beat
        case .ouch:
            shiftX += 2 * sin(2 * .pi * elapsed / 0.06) * (1 - p)
        case .squish:
            let give = Self.keyframes(p, [(0, 0), (0.12, 1), (0.35, -0.3), (0.6, 0.08), (1, 0)])
            stretchY -= 0.2 * give
            stretchX += 0.15 * give
        case .dizzy:
            let strength = min(1, elapsed / 0.15) * (1 - 0.5 * p) * (1 - Self.ease((p - 0.8) / 0.2))
            tilt += 10 * sin(2 * .pi * elapsed / 0.8) * strength
            shiftX += 4 * cos(2 * .pi * elapsed / 0.8) * strength
        case .shake:
            shiftX += 3 * sin(2 * .pi * elapsed / 0.1) * (1 - p)
        case .joy:
            hop(progress: p, height: 16)
        }
    }

    /// Where the time stands in a routine that repeats, from 0 to 1.
    private static func beat(_ time: Double, every period: Double) -> Double {
        time.truncatingRemainder(dividingBy: period) / period
    }

    private static func ease(_ x: Double) -> Double {
        let x = min(1, max(0, x))
        return x * x * (3 - 2 * x)
    }

    /// A value eased between (progress, value) points.
    private static func keyframes(_ p: Double, _ points: [(Double, Double)]) -> Double {
        for (from, to) in zip(points, points.dropFirst()) where p <= to.0 {
            return from.1 + (to.1 - from.1) * ease((p - from.0) / (to.0 - from.0))
        }
        return points.last?.1 ?? 0
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

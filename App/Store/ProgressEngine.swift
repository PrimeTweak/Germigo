import Foundation

// MARK: - Skill tree

/// The five branches of the skill tree, each fed by one kind of event in the journal.
enum SkillBranch: String, CaseIterable, Identifiable {
    case airways
    case gut
    case skin
    case night
    case dodge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .airways: return tr("Airways")
        case .gut: return tr("Gut")
        case .skin: return tr("Skin")
        case .night: return tr("Night")
        case .dodge: return tr("Dodge")
        }
    }

    /// What the branch counts, as shown next to its progress.
    var unit: String {
        switch self {
        case .airways: return tr("Nose and throat germs")
        case .gut: return tr("Stomach bugs")
        case .skin: return tr("Skin and critter germs")
        case .night: return tr("Night-shift logs")
        case .dodge: return tr("Germs dodged")
        }
    }

    var symbol: String {
        switch self {
        case .airways: return "nose.fill"
        case .gut: return "drop.fill"
        case .skin: return "hand.raised.fill"
        case .night: return "moon.stars.fill"
        case .dodge: return "figure.run"
        }
    }

    var tint: UInt32 {
        switch self {
        case .airways: return Swatch.sky
        case .gut: return Swatch.grass
        case .skin: return Swatch.coralSoft
        case .night: return Swatch.lilac
        case .dodge: return Swatch.hazard
        }
    }

    /// The count each of the three ranks asks for.
    var targets: [Int] {
        switch self {
        case .airways: return [1, 5, 12]
        case .gut, .skin, .night, .dodge: return [1, 3, 6]
        }
    }

    var titles: [String] {
        switch self {
        case .airways: return [tr("Tissue Apprentice"), tr("Master of the Nasal Aspirator"), tr("Chief Mucus Officer")]
        case .gut: return [tr("Bucket Holder"), tr("Electrolyte Sommelier"), tr("Porcelain Diplomat")]
        case .skin: return [tr("Itch Witness"), tr("Lice Comb Ninja"), tr("Rash Cartographer")]
        case .night: return [tr("Night Owl"), tr("Sleepless Night Survivor"), tr("3 AM Philosopher")]
        case .dodge: return [tr("Lucky Dodger"), tr("Hand-Washing Zealot"), tr("The Untouchable")]
        }
    }
}

/// One title in the tree; the capstone has no branch.
struct SkillNode: Identifiable, Hashable {
    let id: String
    let branch: SkillBranch?
    let rank: Int
    let title: String
    let progress: Int
    let target: Int

    var isUnlocked: Bool { progress >= target }
}

/// Titles earned from the journal. Nothing is stored: deleting a log takes its titles back.
enum SkillTree {
    static let capstoneID = "veteran"

    /// Branches that must reach rank 2 for the capstone.
    static let capstoneTarget = 3

    static func counts(data: AppData, catalog: GermCatalog) -> [SkillBranch: Int] {
        var counts: [SkillBranch: Int] = [:]
        for log in data.logs {
            if let family = catalog.germ(log.germID)?.family {
                switch family {
                case .airways: counts[.airways, default: 0] += 1
                case .gut: counts[.gut, default: 0] += 1
                case .skin: counts[.skin, default: 0] += 1
                case .other: break
                }
            }
            if log.bonuses.contains(where: { $0.kind == .nightShift }) {
                counts[.night, default: 0] += 1
            }
        }
        counts[.dodge] = data.kidIllnesses.filter { $0.outcome == .dodged }.count
        return counts
    }

    static func rank(of branch: SkillBranch, count: Int) -> Int {
        branch.targets.filter { count >= $0 }.count
    }

    static func nodes(data: AppData, catalog: GermCatalog) -> [SkillNode] {
        let tally = counts(data: data, catalog: catalog)
        var result: [SkillNode] = []
        for branch in SkillBranch.allCases {
            let count = tally[branch] ?? 0
            for rank in 1...branch.targets.count {
                result.append(SkillNode(id: branch.rawValue + "-" + String(rank), branch: branch, rank: rank,
                                        title: branch.titles[rank - 1], progress: count,
                                        target: branch.targets[rank - 1]))
            }
        }
        let strong = SkillBranch.allCases.filter { rank(of: $0, count: tally[$0] ?? 0) >= 2 }.count
        result.append(SkillNode(id: capstoneID, branch: nil, rank: 4, title: tr("Daycare Biohazard Veteran"),
                                progress: strong, target: capstoneTarget))
        return result
    }

    /// The worn title, if it is still earned.
    static func wornTitle(data: AppData, catalog: GermCatalog) -> String? {
        guard let id = data.settings.wornTitle else { return nil }
        return nodes(data: data, catalog: catalog).first { $0.id == id && $0.isUnlocked }?.title
    }
}

// MARK: - Streak milestones

enum Milestones {
    static let days = [7, 14, 30, 60, 100, 200, 365]

    static func next(after current: Int) -> Int? {
        days.first { $0 > current }
    }

    /// The milestone the current streak just crossed, unless it was already celebrated.
    static func pending(data: AppData, now: Date) -> Int? {
        guard let start = StreakMath.currentStart(data: data),
              let reached = days.last(where: { $0 <= StreakMath.days(from: start, to: now) }) else { return nil }
        if let mark = data.celebratedMilestone, abs(mark.streakStart.timeIntervalSince(start)) < 1, mark.days >= reached {
            return nil
        }
        return reached
    }
}

// MARK: - Next goal

/// The closest thing to unlock, shown under the level.
struct Goal: Hashable {
    let title: String
    let detail: String
    let symbol: String
    let progress: Int
    let target: Int

    var fraction: Double { target == 0 ? 0 : min(1, Double(progress) / Double(target)) }
}

enum GoalEngine {
    static func next(data: AppData, catalog: GermCatalog, now: Date) -> Goal? {
        var candidates: [Goal] = []

        if let start = StreakMath.currentStart(data: data) {
            let current = StreakMath.days(from: start, to: now)
            if let target = Milestones.next(after: current) {
                candidates.append(Goal(title: trCount(target, one: "%lld day without a germ", other: "%lld days without a germ"),
                                       detail: tr("Current streak"), symbol: "calendar", progress: current, target: target))
            }
        }

        let tally = SkillTree.counts(data: data, catalog: catalog)
        for branch in SkillBranch.allCases {
            let count = tally[branch] ?? 0
            let rank = SkillTree.rank(of: branch, count: count)
            guard rank < branch.targets.count else { continue }
            candidates.append(Goal(title: branch.titles[rank], detail: branch.unit, symbol: branch.symbol,
                                   progress: count, target: branch.targets[rank]))
        }

        let distinct = Set(data.logs.map { $0.germID }).count
        let dodged = data.kidIllnesses.filter { $0.outcome == .dodged }.count
        let counted: [(String, Int, Int)] = [
            ("collector", distinct, 5), ("half_album", distinct, 12), ("full_album", distinct, catalog.germs.count),
            ("dodger", dodged, 3), (BadgeCatalog.ironParent, StreakMath.record(data: data, now: now), 30)
        ]
        for (id, progress, target) in counted where data.badges[id] == nil && target > 0 {
            guard let badge = BadgeCatalog.badge(id) else { continue }
            candidates.append(Goal(title: badge.title, detail: badge.detail, symbol: badge.symbol,
                                   progress: progress, target: target))
        }

        let open = candidates.filter { $0.progress < $0.target }
        return open.max { $0.fraction < $1.fraction } ?? open.first
    }
}

// MARK: - Couple duel

struct DuelSide: Hashable {
    let germs: Int
    let daysSick: Int
    let nights: Int
    let points: Int
}

struct DuelStats: Hashable {
    let me: DuelSide
    let partner: DuelSide

    /// Who suffered most this season; nil for a tie.
    var leader: Sufferer? {
        let mine = [me.points, me.germs, me.daysSick]
        let theirs = [partner.points, partner.germs, partner.daysSick]
        for (a, b) in zip(mine, theirs) where a != b {
            return a > b ? .me : .partner
        }
        return nil
    }
}

enum DuelEngine {
    static func stats(data: AppData, season: Season, now: Date) -> DuelStats {
        let logs = data.logs.filter { season.contains($0.startedAt) }
        func side(_ includes: (Sufferer) -> Bool) -> DuelSide {
            let mine = logs.filter { includes($0.sufferer) }
            return DuelSide(germs: mine.count,
                            daysSick: mine.reduce(0) { $0 + $1.dayCount(now: now) },
                            nights: mine.filter { log in log.bonuses.contains { $0.kind == .nightShift } }.count,
                            points: mine.reduce(0) { $0 + $1.points })
        }
        return DuelStats(me: side { $0.includesMe }, partner: side { $0.includesPartner })
    }
}

// MARK: - Season wrapped

/// The one-line identity at the end of the season story.
enum Persona: String, CaseIterable {
    case ironParent
    case nightOwl
    case dodger
    case marathoner
    case boomerang
    case collector
    case survivor

    var title: String {
        switch self {
        case .ironParent: return tr("The Iron Parent")
        case .nightOwl: return tr("The Night Owl")
        case .dodger: return tr("The Dodger")
        case .marathoner: return tr("The Marathoner")
        case .boomerang: return tr("The Boomerang")
        case .collector: return tr("The Collector")
        case .survivor: return tr("The Survivor")
        }
    }

    var blurb: String {
        switch self {
        case .ironParent: return tr("Daycare tried. You barely noticed.")
        case .nightOwl: return tr("Your germs prefer to arrive between 1 and 5 AM.")
        case .dodger: return tr("Kids brought it home. You stepped aside.")
        case .marathoner: return tr("Ten days or more with one germ. Endurance.")
        case .boomerang: return tr("Same germ, again and again. Loyal.")
        case .collector: return tr("A wide and unwanted collection.")
        case .survivor: return tr("You caught it, you lived, you logged it.")
        }
    }
}

struct WrapEntry: Hashable {
    let germ: Germ
    let value: Int
}

struct SeasonWrap {
    let season: Season
    let germsCaught: Int
    let families: [GermFamily: Int]
    let daysSick: Int
    let longest: WrapEntry?
    let nightLogs: Int
    let topGerm: WrapEntry?
    let dodged: Int
    let distinct: Int
    let persona: Persona
    let germs: [Germ]
}

enum WrapEngine {
    static func wrap(data: AppData, catalog: GermCatalog, season: Season, now: Date) -> SeasonWrap {
        let logs = data.logs.filter { season.contains($0.startedAt) }.sorted { $0.startedAt < $1.startedAt }
        var families: [GermFamily: Int] = [:]
        var perGerm: [String: Int] = [:]
        var order: [String] = []
        var longest: WrapEntry?
        for log in logs {
            guard let germ = catalog.germ(log.germID) else { continue }
            families[germ.family, default: 0] += 1
            if perGerm[germ.id] == nil { order.append(germ.id) }
            perGerm[germ.id, default: 0] += 1
            let days = log.dayCount(now: now)
            if days > (longest?.value ?? 0) { longest = WrapEntry(germ: germ, value: days) }
        }
        var topGerm: WrapEntry?
        for id in order {
            guard let germ = catalog.germ(id), let count = perGerm[id], count > (topGerm?.value ?? 0) else { continue }
            topGerm = WrapEntry(germ: germ, value: count)
        }
        let nights = logs.filter { log in log.bonuses.contains { $0.kind == .nightShift } }.count
        let dodged = data.kidIllnesses.filter { $0.outcome == .dodged && season.contains($0.startedAt) }.count
        let type = persona(caught: logs.count, nights: nights, dodged: dodged, longest: longest?.value ?? 0,
                           repeats: topGerm?.value ?? 0, distinct: order.count)
        return SeasonWrap(season: season, germsCaught: logs.count, families: families,
                          daysSick: logs.reduce(0) { $0 + $1.dayCount(now: now) }, longest: longest,
                          nightLogs: nights, topGerm: topGerm, dodged: dodged, distinct: order.count,
                          persona: type, germs: order.compactMap { catalog.germ($0) })
    }

    static func persona(caught: Int, nights: Int, dodged: Int, longest: Int, repeats: Int, distinct: Int) -> Persona {
        if caught <= 1 { return .ironParent }
        if nights >= 2 { return .nightOwl }
        if dodged >= 3 && dodged >= caught { return .dodger }
        if longest >= 10 { return .marathoner }
        if repeats >= 3 { return .boomerang }
        if distinct >= 6 { return .collector }
        return .survivor
    }

    /// When the season story is announced: June 20, as daycare winds down for the summer.
    static func revealDate(for season: Season) -> Date {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: season.end)
        return calendar.date(from: DateComponents(year: year, month: 6, day: 20, hour: 10)) ?? season.end
    }
}

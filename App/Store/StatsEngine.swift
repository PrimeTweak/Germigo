import Foundation

struct MonthEntry: Identifiable {
    let id: String
    let germ: Germ
    let count: Int
}

struct MonthBucket: Identifiable {
    let id: Int
    let label: String
    let isCurrent: Bool
    let entries: [MonthEntry]

    var total: Int { entries.reduce(0) { $0 + $1.count } }
}

struct SupplierStat {
    let kid: Kid
    let count: Int
    let total: Int
    let germs: [Germ]
}

struct ChainStat {
    let kid: Kid
    let germ: Germ
    let sufferer: Sufferer
    let days: Int
    let startedAt: Date

    var includesPartner: Bool { sufferer.includesPartner }
}

/// The germ that keeps coming back, and how many times it did.
struct Nemesis: Hashable {
    let germID: String
    let count: Int
}

struct SeasonStats {
    let germsCaught: Int
    let daysSick: Int
    let dodged: Int
    let months: [MonthBucket]
    let topSupplier: SupplierStat?
    let longestChain: ChainStat?
}

/// Aggregates the season's logs for the Season page and the recap card.
enum StatsEngine {
    /// One entry per week of the season so far: the first germ going on that week, or nil.
    static func sickWeekGerms(data: AppData, season: Season, now: Date) -> [String?] {
        let calendar = Calendar.current
        let count = min(53, season.week(for: now))
        let logs = data.logs.sorted { $0.startedAt < $1.startedAt }
        return (0..<count).map { index in
            guard let start = calendar.date(byAdding: .day, value: index * 7, to: season.start),
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else { return nil }
            return logs.first { $0.startedAt < end && ($0.endedAt ?? now) >= start }?.germID
        }
    }

    /// The germ caught most often this season, once it has come back at least once.
    static func nemesis(data: AppData, season: Season) -> Nemesis? {
        var counts: [String: Int] = [:]
        var last: [String: Date] = [:]
        for log in data.logs where season.contains(log.startedAt) {
            counts[log.germID, default: 0] += 1
            last[log.germID] = max(last[log.germID] ?? log.startedAt, log.startedAt)
        }
        let best = counts.filter { $0.value >= 2 }.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : (last[lhs.key] ?? .distantPast) < (last[rhs.key] ?? .distantPast)
        }
        return best.map { Nemesis(germID: $0.key, count: $0.value) }
    }

    static func stats(data: AppData, catalog: GermCatalog, season: Season, now: Date) -> SeasonStats {
        let calendar = Calendar.current
        let logs = data.logs.filter { season.contains($0.startedAt) }.sorted { $0.startedAt < $1.startedAt }
        let daysSick = logs.reduce(0) { $0 + $1.dayCount(now: now) }
        let dodged = data.kidIllnesses.filter { $0.outcome == .dodged && season.contains($0.startedAt) }.count

        let symbols = calendar.veryShortStandaloneMonthSymbols
        var months: [MonthBucket] = []
        for offset in 0..<12 {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: season.start) else { continue }
            let monthLogs = logs.filter { calendar.isDate($0.startedAt, equalTo: monthStart, toGranularity: .month) }
            var counts: [String: Int] = [:]
            var order: [String] = []
            for log in monthLogs {
                if counts[log.germID] == nil { order.append(log.germID) }
                counts[log.germID, default: 0] += 1
            }
            let entries = order.compactMap { id -> MonthEntry? in
                guard let germ = catalog.germ(id) else { return nil }
                return MonthEntry(id: "\(offset)-\(id)", germ: germ, count: counts[id] ?? 0)
            }
            let monthIndex = calendar.component(.month, from: monthStart) - 1
            let label = monthIndex < symbols.count ? symbols[monthIndex] : ""
            months.append(MonthBucket(id: offset, label: label,
                                      isCurrent: calendar.isDate(now, equalTo: monthStart, toGranularity: .month),
                                      entries: entries))
        }

        var perKid: [UUID: [SickLog]] = [:]
        for log in logs {
            if case .kid(let kidID) = log.source { perKid[kidID, default: []].append(log) }
        }
        var topSupplier: SupplierStat?
        if let best = perKid.max(by: { $0.value.count < $1.value.count }),
           let kid = data.kids.first(where: { $0.id == best.key }) {
            var seen = Set<String>()
            let germs = best.value.compactMap { log -> Germ? in
                guard seen.insert(log.germID).inserted else { return nil }
                return catalog.germ(log.germID)
            }
            topSupplier = SupplierStat(kid: kid, count: best.value.count, total: logs.count, germs: germs)
        }

        var longestChain: ChainStat?
        for log in logs {
            guard case .kid(let kidID) = log.source,
                  let kid = data.kids.first(where: { $0.id == kidID }),
                  let germ = catalog.germ(log.germID) else { continue }
            let illness = data.kidIllnesses.first { $0.id == log.kidIllnessID }
            let start = illness?.startedAt ?? log.startedAt
            let days = StreakMath.days(from: start, to: log.endedAt ?? now) + 1
            let candidate = ChainStat(kid: kid, germ: germ, sufferer: log.sufferer, days: days, startedAt: start)
            if let current = longestChain {
                let better = (candidate.includesPartner && !current.includesPartner)
                    || (candidate.includesPartner == current.includesPartner && candidate.days > current.days)
                if better { longestChain = candidate }
            } else {
                longestChain = candidate
            }
        }

        return SeasonStats(germsCaught: logs.count, daysSick: daysSick, dodged: dodged, months: months,
                           topSupplier: topSupplier, longestChain: longestChain)
    }
}

/// The family league's funny titles; each person wears one at most.
enum LeagueTitle {
    case forceField
    case patientZero
    case frequentFlyer
    case couchChampion

    var text: String {
        switch self {
        case .forceField: return tr("Force field")
        case .patientZero: return tr("Patient zero")
        case .frequentFlyer: return tr("Frequent flyer")
        case .couchChampion: return tr("Couch champion")
        }
    }
}

/// One member of the household in the family league.
struct LeagueEntry: Hashable {
    let person: Person
    let sickDays: Int
    let germs: Int
    var title: LeagueTitle?
}

/// The whole household ranked by fewest sick days this season.
enum LeagueEngine {
    static func standings(data: AppData, catalog: GermCatalog, season: Season, now: Date) -> [LeagueEntry] {
        let calendar = Calendar.current
        let logs = data.logs.filter { season.contains($0.startedAt) }
        func parent(_ person: Person, _ includes: (Sufferer) -> Bool) -> LeagueEntry {
            let mine = logs.filter { includes($0.sufferer) }
            return LeagueEntry(person: person, sickDays: mine.reduce(0) { $0 + $1.dayCount(now: now) }, germs: mine.count)
        }
        var entries = [parent(.me) { $0.includesMe }]
        if data.partnerName != nil {
            entries.append(parent(.partner) { $0.includesPartner })
        }
        for kid in data.kids {
            let illnesses = data.kidIllnesses.filter { $0.kidID == kid.id && season.contains($0.startedAt) && $0.startedAt <= now }
            let days = illnesses.reduce(0) { total, illness in
                let end = DayEngine.kidEnd(illness, catalog: catalog, now: now)
                let span = calendar.dateComponents([.day], from: calendar.startOfDay(for: illness.startedAt),
                                                   to: calendar.startOfDay(for: end)).day ?? 0
                return total + max(1, span + 1)
            }
            entries.append(LeagueEntry(person: .kid(kid.id), sickDays: days, germs: illnesses.count))
        }
        let ranked = entries.enumerated()
            .sorted { ($0.element.sickDays, $0.element.germs, $0.offset) < ($1.element.sickDays, $1.element.germs, $1.offset) }
            .map { $0.element }
        return titled(ranked)
    }

    /// The leader is the force field; then the kid who brought the most germs home, the one who caught the most,
    /// and the one sick the longest. Nobody gets a title while nobody stands apart.
    private static func titled(_ ranked: [LeagueEntry]) -> [LeagueEntry] {
        guard let first = ranked.first, let last = ranked.last, first.sickDays < last.sickDays else { return ranked }
        var result = ranked
        var free = Array(result.indices)
        func give(_ title: LeagueTitle, to index: Int?) {
            guard let index else { return }
            result[index].title = title
            free.removeAll { $0 == index }
        }
        func most(_ value: (LeagueEntry) -> Int, kidsOnly: Bool = false) -> Int? {
            free.filter { value(result[$0]) > 0 && (!kidsOnly || isKid(result[$0].person)) }
                .max { value(result[$0]) < value(result[$1]) }
        }
        give(.forceField, to: 0)
        give(.patientZero, to: most({ $0.germs }, kidsOnly: true))
        give(.frequentFlyer, to: most { $0.germs })
        give(.couchChampion, to: most { $0.sickDays })
        return result
    }

    private static func isKid(_ person: Person) -> Bool {
        if case .kid = person { return true }
        return false
    }
}

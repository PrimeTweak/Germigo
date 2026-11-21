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

struct SeasonStats {
    let germsCaught: Int
    let daysSick: Int
    let dodged: Int
    let months: [MonthBucket]
    let topSupplier: SupplierStat?
    let longestChain: ChainStat?
}

/// Aggregates the season's logs for the Season tab and the recap card.
enum StatsEngine {
    /// One flag per week of the season so far: true when a germ was going on during it.
    static func sickWeeks(data: AppData, season: Season, now: Date) -> [Bool] {
        let calendar = Calendar.current
        let count = min(53, season.week(for: now))
        return (0..<count).map { index in
            guard let start = calendar.date(byAdding: .day, value: index * 7, to: season.start),
                  let end = calendar.date(byAdding: .day, value: 7, to: start) else { return false }
            return data.logs.contains { $0.startedAt < end && ($0.endedAt ?? now) >= start }
        }
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

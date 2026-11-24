import Foundation

/// One illness of one person, as their file counts it: from its first day to its last, or to today while it goes on.
struct PersonIllness: Identifiable {
    enum Note {
        /// A kid's illness the parent caught too, or one the parent dodged.
        case gotYou, youDodged
        /// Where a parent's germ came from.
        case from(GermSource)
    }

    let id: UUID
    let germID: String
    let start: Date
    let end: Date
    let goingOn: Bool
    let symptoms: [String]
    let note: Note?

    var days: Int { StreakMath.days(from: start, to: end) + 1 }

    var dodged: Bool {
        if case .youDodged? = note { return true }
        return false
    }
}

/// A germ and how often it came, with its latest illness.
struct GermCount {
    let germID: String
    let count: Int
    let last: PersonIllness
}

/// What a person's file shows beyond the list: the season day by day, what keeps coming back and the patterns.
/// Counts only, from dates the journal already holds; nothing here judges or predicts an illness.
enum PersonFileEngine {
    /// Every illness of the person, newest first.
    static func illnesses(of person: Person, data: AppData, catalog: GermCatalog, now: Date) -> [PersonIllness] {
        let list: [PersonIllness]
        switch person {
        case .kid(let id):
            list = data.kidIllnesses.filter { $0.kidID == id }.map { illness in
                PersonIllness(id: illness.id, germID: illness.germID, start: illness.startedAt,
                              end: DayEngine.kidEnd(illness, catalog: catalog, now: now),
                              goingOn: DayEngine.isGoingOn(illness, catalog: catalog, now: now),
                              symptoms: illness.symptoms,
                              note: illness.outcome == .caught ? .gotYou : (illness.outcome == .dodged ? .youDodged : nil))
            }
        case .me, .partner:
            list = data.logs.filter { person == .me ? $0.sufferer.includesMe : $0.sufferer.includesPartner }.map { log in
                PersonIllness(id: log.id, germID: log.germID, start: log.startedAt, end: log.endedAt ?? now,
                              goingOn: log.isActive, symptoms: log.symptoms,
                              note: log.source == .unknown ? nil : .from(log.source))
            }
        }
        return list.sorted { $0.start > $1.start }
    }

    /// The germ of each sick day within the season, keyed by the start of the day; the newest illness wins a shared day.
    static func sickDays(_ illnesses: [PersonIllness], in season: Season) -> [Date: String] {
        let calendar = Calendar.current
        var days: [Date: String] = [:]
        for illness in illnesses.reversed() {
            var day = calendar.startOfDay(for: illness.start)
            let last = calendar.startOfDay(for: illness.end)
            while day <= last {
                if season.contains(day) { days[day] = illness.germID }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }
        return days
    }

    /// Days sick in each month of the season, September first.
    static func monthTotals(_ sickDays: [Date: String], season: Season) -> [Int] {
        let calendar = Calendar.current
        var totals = Array(repeating: 0, count: 12)
        for day in sickDays.keys {
            let months = calendar.dateComponents([.month], from: season.start, to: day).month ?? 0
            if (0..<12).contains(months) { totals[months] += 1 }
        }
        return totals
    }

    /// Germs by how often they came, most first; a tie goes to the most recent.
    static func comingBack(_ illnesses: [PersonIllness]) -> [GermCount] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for illness in illnesses {
            if counts[illness.germID] == nil { order.append(illness.germID) }
            counts[illness.germID, default: 0] += 1
        }
        return order.enumerated()
            .sorted { counts[$0.element]! != counts[$1.element]! ? counts[$0.element]! > counts[$1.element]! : $0.offset < $1.offset }
            .compactMap { item in
                illnesses.first { $0.germID == item.element }.map { GermCount(germID: item.element, count: counts[item.element]!, last: $0) }
            }
    }

    /// The usual length in days, rounded, over the illnesses that are over.
    static func usualDays(_ illnesses: [PersonIllness]) -> Int? {
        let over = illnesses.filter { !$0.goingOn }
        guard !over.isEmpty else { return nil }
        return Int((Double(over.reduce(0) { $0 + $1.days }) / Double(over.count)).rounded())
    }

    /// Days of the season so far, today included.
    static func seasonDaysSoFar(_ season: Season, now: Date) -> Int {
        StreakMath.days(from: season.start, to: min(now, season.end)) + 1
    }
}

import Foundation

/// Germ-free streak and day-count arithmetic, from the journal.
enum StreakMath {
    static func days(from start: Date, to end: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: end)).day ?? 0
        return max(0, days)
    }

    /// Start of the current germ-free run; nil while sick.
    static func currentStart(data: AppData) -> Date? {
        if data.logs.contains(where: { $0.isActive }) { return nil }
        return data.logs.compactMap { $0.endedAt }.max() ?? data.installedAt
    }

    static func current(data: AppData, now: Date) -> Int {
        guard let start = currentStart(data: data) else { return 0 }
        return days(from: start, to: now)
    }

    /// Every germ-free gap so far, in chronological order.
    static func gaps(data: AppData, now: Date) -> [Int] {
        var result: [Int] = []
        var cursor = data.installedAt
        for log in data.logs.sorted(by: { $0.startedAt < $1.startedAt }) {
            result.append(days(from: cursor, to: max(cursor, log.startedAt)))
            cursor = max(cursor, log.endedAt ?? now)
        }
        if !data.logs.contains(where: { $0.isActive }) {
            result.append(days(from: cursor, to: now))
        }
        return result
    }

    static func record(data: AppData, now: Date) -> Int {
        gaps(data: data, now: now).max() ?? 0
    }
}

/// Points and badges earned by logging germs.
enum RewardEngine {
    static let nightShiftPoints = 50

    /// Answering "Dodged it" when a kid's germ skipped the parent.
    static let dodgePoints = 40

    /// A log closed sooner than this is a correction, not a recovery.
    static let speedrunMinimum: TimeInterval = 3600

    /// Each right answer in the daily quiz.
    static let quizAnswerPoints = 5

    /// Saying "I'm better", once per germ.
    static let recoveryPoints = 30

    /// Guessing the season's nemesis before the Wrapped reveal.
    static let wrapGuessPoints = 10

    static func bonuses(for draft: LogDraft, germ: Germ) -> [LogBonus] {
        var result = [LogBonus(kind: .rarity, points: germ.rarity.basePoints)]
        let hour = Calendar.current.component(.hour, from: draft.startedAt)
        if hour >= 1 && hour < 5 {
            result.append(LogBonus(kind: .nightShift, points: nightShiftPoints))
        }
        return result
    }

    static func totalPoints(data: AppData) -> Int {
        let dodged = data.kidIllnesses.filter { $0.outcome == .dodged }.count
        let guesses = data.wrapGuesses.values.filter { $0 }.count
        return data.logs.reduce(0) { $0 + $1.points } + dodged * dodgePoints + data.quiz.rightTotal * quizAnswerPoints
            + guesses * wrapGuessPoints
    }

    static func earnedBadges(data: AppData, catalog: GermCatalog, now: Date) -> Set<String> {
        var earned = Set<String>()
        let logs = data.logs.sorted { $0.startedAt < $1.startedAt }
        let calendar = Calendar.current

        if !logs.isEmpty { earned.insert(BadgeCatalog.patientOne) }
        if logs.contains(where: { log in log.bonuses.contains { $0.kind == .nightShift } }) {
            earned.insert(BadgeCatalog.nightShift)
        }
        if logs.contains(where: { $0.sufferer == .both }) { earned.insert(BadgeCatalog.tagTeam) }
        if logs.contains(where: { $0.dayCount(now: now) >= 10 }) { earned.insert("marathon") }
        if logs.contains(where: { log in
            guard let end = log.endedAt else { return false }
            let length = end.timeIntervalSince(log.startedAt)
            return length >= speedrunMinimum && length <= 24 * 3600
        }) {
            earned.insert("speedrun")
        }

        var lastSeen: [String: Date] = [:]
        var perMonth: [String: Int] = [:]
        for log in logs {
            if let previous = lastSeen[log.germID], log.startedAt.timeIntervalSince(previous) <= 30 * 24 * 3600 {
                earned.insert("boomerang")
            }
            lastSeen[log.germID] = log.startedAt
            let parts = calendar.dateComponents([.year, .month], from: log.startedAt)
            let key = "\(parts.year ?? 0)-\(parts.month ?? 0)"
            perMonth[key, default: 0] += 1
        }
        if perMonth.values.contains(where: { $0 >= 3 }) { earned.insert("rough_month") }

        let distinct = Set(logs.map { $0.germID }).count
        if distinct >= 5 { earned.insert("collector") }
        if distinct >= 12 { earned.insert("half_album") }
        if !catalog.germs.isEmpty && distinct >= catalog.germs.count { earned.insert("full_album") }

        if data.kidIllnesses.filter({ $0.outcome == .dodged }).count >= 3 { earned.insert(BadgeCatalog.dodger) }
        if StreakMath.record(data: data, now: now) >= 30 { earned.insert(BadgeCatalog.ironParent) }
        if !data.quiz.doneDays.isEmpty { earned.insert(BadgeCatalog.labRat) }
        if !catalog.myths.isEmpty && Set(data.quiz.mythsRight).isSuperset(of: catalog.myths.map { $0.id }) {
            earned.insert(BadgeCatalog.mythBuster)
        }
        if !catalog.articles.isEmpty && Set(data.readArticles).isSuperset(of: catalog.articles.map { $0.id }) {
            earned.insert(BadgeCatalog.professor)
        }
        if Set(data.mascotTricks).isSuperset(of: MascotTrick.allCases.map { $0.rawValue }) {
            earned.insert(BadgeCatalog.ticklish)
        }
        return earned
    }
}

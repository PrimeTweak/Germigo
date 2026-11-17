import Foundation
import Observation
import WidgetKit

/// What the reward screen shows after a germ is logged.
struct RewardResult: Identifiable {
    let id = UUID()
    let log: SickLog
    let germ: Germ
    let isNewCard: Bool
    let previousStreak: Int
    let newBadges: [Badge]
    let levelBefore: LevelInfo
    let levelAfter: LevelInfo
    let unlockedIcons: [AppIconOption]
}

/// The single source of truth for the journal and everything derived from it.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var data: AppData
    let catalog: GermCatalog
    var pendingReward: RewardResult?
    var logRequest: LogRequest?
    var selectedTab = AppTab.today

    init() {
        catalog = GermCatalog.load()
        data = Persistence.load() ?? AppData()
    }

    // MARK: - Derived state

    var hasPass: Bool { PurchaseManager.shared.hasPass }

    var activeLog: SickLog? {
        data.logs.last { $0.isActive }
    }

    var activeGerm: Germ? {
        guard let log = activeLog else { return nil }
        return catalog.germ(log.germID)
    }

    var season: Season {
        Season.containing(Date(), firstUse: data.installedAt)
    }

    var caughtGermIDs: Set<String> {
        Set(data.logs.map { $0.germID })
    }

    var totalPoints: Int {
        data.logs.reduce(0) { $0 + $1.points }
    }

    var level: LevelInfo {
        Levels.info(for: totalPoints)
    }

    var openExposures: [KidIllness] {
        data.kidIllnesses.filter { $0.outcome == .open }.sorted { $0.startedAt > $1.startedAt }
    }

    var displayName: String {
        data.profileName.isEmpty ? tr("You") : data.profileName
    }

    func streakDays(now: Date = Date()) -> Int {
        StreakMath.current(data: data, now: now)
    }

    func recordDays(now: Date = Date()) -> Int {
        StreakMath.record(data: data, now: now)
    }

    func lastRunDays(now: Date = Date()) -> Int {
        StreakMath.lastRun(data: data, now: now)
    }

    func count(of germID: String) -> Int {
        data.logs.filter { $0.germID == germID }.count
    }

    func logs(of germID: String) -> [SickLog] {
        data.logs.filter { $0.germID == germID }.sorted { $0.startedAt > $1.startedAt }
    }

    func kid(_ id: UUID) -> Kid? {
        data.kids.first { $0.id == id }
    }

    func sourceName(_ source: GermSource) -> String {
        switch source {
        case .kid(let id): return kid(id)?.name ?? tr("A kid")
        case .partner: return data.partnerName ?? tr("Partner")
        case .daycare: return tr("Daycare")
        case .unknown: return tr("Not sure")
        }
    }

    func seasonStats(now: Date = Date()) -> SeasonStats {
        StatsEngine.stats(data: data, catalog: catalog, season: season, now: now)
    }

    func hasBadge(_ id: String) -> Bool {
        data.badges[id] != nil
    }

    func isIconUnlocked(_ icon: AppIconOption) -> Bool {
        switch icon {
        case .petri: return true
        case .nightShift: return hasBadge(BadgeCatalog.nightShift)
        case .tissueBox: return count(of: "rhino") >= 3
        case .goldenDish: return data.logs.count >= 20
        case .soupBowl: return hasPass
        case .holo: return !catalog.germs.isEmpty && caughtGermIDs.count >= catalog.germs.count
        }
    }

    func isThemeUnlocked(_ theme: Theme) -> Bool {
        switch theme {
        case .agar: return true
        case .nightShift: return hasBadge(BadgeCatalog.nightShift)
        case .mint: return hasBadge(BadgeCatalog.ironParent)
        }
    }

    func isArticleUnlocked(_ article: Article) -> Bool {
        hasPass || caughtGermIDs.count >= article.unlockAtGerms
    }

    func deepDiveUnlocked(for germ: Germ) -> Bool {
        hasPass || count(of: germ.id) > 0
    }

    /// Free accounts keep one kid; the Season Pass lifts the limit.
    var canAddKid: Bool {
        hasPass || data.kids.isEmpty
    }

    // MARK: - Household

    func completeOnboarding(kid: Kid?) {
        if let kid, !kid.name.isEmpty { data.kids = [kid] }
        data.onboardingDone = true
        commit()
    }

    func setProfileName(_ name: String) {
        data.profileName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        commit()
    }

    func setPartnerName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        data.partnerName = trimmed.isEmpty ? nil : trimmed
        commit()
    }

    func saveKid(_ kid: Kid) {
        if let index = data.kids.firstIndex(where: { $0.id == kid.id }) {
            data.kids[index] = kid
        } else {
            data.kids.append(kid)
        }
        commit()
    }

    func removeKid(_ id: UUID) {
        for illness in data.kidIllnesses where illness.kidID == id {
            stopWatching(illness)
        }
        data.kids.removeAll { $0.id == id }
        data.kidIllnesses.removeAll { $0.kidID == id }
        commit()
    }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        change(&data.settings)
        commit()
        rescheduleNotifications()
    }

    func markArticleRead(_ id: String) {
        guard !data.readArticles.contains(id) else { return }
        data.readArticles.append(id)
        commit()
    }

    // MARK: - Logging

    @discardableResult
    func logGerm(_ draft: LogDraft, now: Date = Date()) -> RewardResult? {
        guard let germ = catalog.germ(draft.germID) else { return nil }
        let previousStreak = streakDays(now: draft.startedAt)
        let isNewCard = !caughtGermIDs.contains(germ.id)
        let levelBefore = level
        let iconsBefore = AppIconOption.allCases.filter { isIconUnlocked($0) }

        if let active = activeLog, let index = data.logs.firstIndex(where: { $0.id == active.id }) {
            data.logs[index].endedAt = max(active.startedAt, draft.startedAt)
        }

        let bonuses = RewardEngine.bonuses(for: draft, germ: germ)
        let log = SickLog(germID: germ.id, source: draft.source, severity: draft.severity,
                          startedAt: draft.startedAt, endedAt: nil,
                          points: bonuses.reduce(0) { $0 + $1.points }, bonuses: bonuses,
                          partnerSickToo: draft.partnerSickToo, kidIllnessID: draft.kidIllnessID)
        data.logs.append(log)

        if let illnessID = draft.kidIllnessID,
           let index = data.kidIllnesses.firstIndex(where: { $0.id == illnessID }) {
            stopWatching(data.kidIllnesses[index])
            data.kidIllnesses[index].outcome = .caught
            data.kidIllnesses[index].watching = false
        }

        let newBadges = awardBadges(now: now)
        commit()
        NotificationManager.scheduleSickCheckIn(settings: data.settings)

        let iconsAfter = AppIconOption.allCases.filter { isIconUnlocked($0) }
        return RewardResult(log: log, germ: germ, isNewCard: isNewCard, previousStreak: previousStreak,
                            newBadges: newBadges, levelBefore: levelBefore, levelAfter: level,
                            unlockedIcons: iconsAfter.filter { !iconsBefore.contains($0) })
    }

    func markBetter(now: Date = Date()) {
        guard let active = activeLog, let index = data.logs.firstIndex(where: { $0.id == active.id }) else { return }
        data.logs[index].endedAt = max(active.startedAt, now)
        _ = awardBadges(now: now)
        commit()
        NotificationManager.cancelSickCheckIn()
    }

    func updateLog(_ log: SickLog) {
        guard let index = data.logs.firstIndex(where: { $0.id == log.id }) else { return }
        data.logs[index] = log
        commit()
    }

    func deleteLog(_ id: UUID) {
        let wasActive = activeLog?.id == id
        data.logs.removeAll { $0.id == id }
        commit()
        if wasActive { NotificationManager.cancelSickCheckIn() }
    }

    // MARK: - Kid illnesses and exposures

    @discardableResult
    func addKidIllness(kidID: UUID, germID: String, startedAt: Date) -> KidIllness {
        let illness = KidIllness(kidID: kidID, germID: germID, startedAt: startedAt, watching: false, outcome: .open)
        data.kidIllnesses.append(illness)
        commit()
        return illness
    }

    func setWatching(_ id: UUID, watching: Bool) {
        guard let index = data.kidIllnesses.firstIndex(where: { $0.id == id }) else { return }
        data.kidIllnesses[index].watching = watching
        let illness = data.kidIllnesses[index]
        commit()
        if watching, let germ = catalog.germ(illness.germID) {
            let kidName = kid(illness.kidID)?.name ?? tr("Your kid")
            NotificationManager.scheduleExposure(illness: illness, kidName: kidName, germ: germ, settings: data.settings)
            LiveActivityManager.start(illness: illness, kidName: kidName, germ: germ)
        } else {
            stopWatching(illness)
        }
    }

    func resolveExposure(_ id: UUID, outcome: ExposureOutcome, now: Date = Date()) {
        guard let index = data.kidIllnesses.firstIndex(where: { $0.id == id }) else { return }
        stopWatching(data.kidIllnesses[index])
        data.kidIllnesses[index].outcome = outcome
        data.kidIllnesses[index].watching = false
        _ = awardBadges(now: now)
        commit()
    }

    func deleteKidIllness(_ id: UUID) {
        if let illness = data.kidIllnesses.first(where: { $0.id == id }) { stopWatching(illness) }
        data.kidIllnesses.removeAll { $0.id == id }
        commit()
    }

    private func stopWatching(_ illness: KidIllness) {
        NotificationManager.cancelExposure(id: illness.id)
        LiveActivityManager.end(exposureID: illness.id)
    }

    // MARK: - Lifecycle

    /// Runs when the app comes to the foreground.
    func refresh(now: Date = Date()) {
        var changed = false
        for index in data.kidIllnesses.indices where data.kidIllnesses[index].outcome == .open {
            let illness = data.kidIllnesses[index]
            guard let germ = catalog.germ(illness.germID),
                  let window = germ.window(from: illness.startedAt) else { continue }
            if now > window.closes.addingTimeInterval(24 * 3600) {
                stopWatching(illness)
                data.kidIllnesses[index].outcome = .dodged
                data.kidIllnesses[index].watching = false
                changed = true
            }
        }
        if !awardBadges(now: now).isEmpty { changed = true }
        if changed { commit() } else { publishSnapshot() }
    }

    /// Handles the Live Activity buttons, which run in the app process.
    func handle(_ action: IntentAction) async {
        switch action {
        case .caught(let exposureID):
            guard let id = UUID(uuidString: exposureID),
                  let illness = data.kidIllnesses.first(where: { $0.id == id }) else { return }
            let draft = LogDraft(germID: illness.germID, source: .kid(illness.kidID), severity: 3,
                                 startedAt: Date(), partnerSickToo: false, kidIllnessID: illness.id)
            pendingReward = logGerm(draft)
        case .stillFine(let exposureID):
            guard let id = UUID(uuidString: exposureID) else { return }
            LiveActivityManager.end(exposureID: id)
        }
    }

    func passDidChange() {
        publishSnapshot()
    }

    func eraseEverything() {
        for illness in data.kidIllnesses { stopWatching(illness) }
        NotificationManager.cancelSickCheckIn()
        Persistence.erase()
        data = AppData()
        pendingReward = nil
        logRequest = nil
        selectedTab = .today
        publishSnapshot()
    }

    // MARK: - Internals

    private func awardBadges(now: Date) -> [Badge] {
        let earned = RewardEngine.earnedBadges(data: data, catalog: catalog, now: now)
        var fresh: [Badge] = []
        for badge in BadgeCatalog.all where earned.contains(badge.id) && data.badges[badge.id] == nil {
            data.badges[badge.id] = now
            fresh.append(badge)
        }
        return fresh
    }

    private func rescheduleNotifications() {
        for illness in data.kidIllnesses where illness.watching && illness.outcome == .open {
            guard let germ = catalog.germ(illness.germID) else { continue }
            let kidName = kid(illness.kidID)?.name ?? tr("Your kid")
            NotificationManager.scheduleExposure(illness: illness, kidName: kidName, germ: germ, settings: data.settings)
        }
        if activeLog != nil {
            NotificationManager.scheduleSickCheckIn(settings: data.settings)
        }
    }

    private func commit() {
        Persistence.save(data)
        publishSnapshot()
    }

    private func publishSnapshot() {
        var snapshot = WidgetSnapshot.empty
        snapshot.streakStart = StreakMath.currentStart(data: data)
        snapshot.recordDays = recordDays()
        snapshot.hasPass = hasPass
        if let log = activeLog, let germ = catalog.germ(log.germID) {
            snapshot.sickGermID = germ.id
            snapshot.sickIllness = germ.illness.value
            snapshot.sickSince = log.startedAt
        }
        if let illness = openExposures.first, let germ = catalog.germ(illness.germID),
           let window = germ.window(from: illness.startedAt) {
            snapshot.exposure = WidgetSnapshot.Exposure(
                kidName: kid(illness.kidID)?.name ?? tr("Your kid"), germID: germ.id, germName: germ.name,
                illness: germ.illness.value, exposedAt: illness.startedAt,
                windowOpens: window.opens, windowCloses: window.closes)
        }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

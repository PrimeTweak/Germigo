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

/// What answering a quiz question earned.
struct QuizOutcome {
    let right: Bool
    let newBadges: [Badge]
}

/// A streak milestone waiting to be celebrated.
struct MilestoneEvent: Identifiable {
    let days: Int
    var id: Int { days }
}

/// A journal problem the parent has to be told about.
enum JournalNotice {
    case setAside
    case saveFailed
}

/// The single source of truth for the journal and everything derived from it.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    /// Longest first name or nickname the journal keeps.
    static let nameLimit = 24

    /// An exposure to a germ without a known window closes by itself after this long.
    static let openExposureLifetime: TimeInterval = 21 * 24 * 3600

    /// How far back a new entry may be dated.
    static var earliestNewEntry: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    }

    private(set) var data: AppData
    let catalog: GermCatalog
    var pendingReward: RewardResult?
    var logRequest: LogRequest?
    var selectedTab = AppTab.today
    var journalNotice: JournalNotice?
    var askBetter = false
    var pendingMilestone: MilestoneEvent?
    /// A short confirmation shown at the top of the screen.
    var toast: String?

    /// False while the journal file exists but cannot be read; nothing is saved over it then.
    @ObservationIgnored private var journalAvailable = true
    @ObservationIgnored private var saveFailureReported = false

    init() {
        catalog = GermCatalog.load()
        data = AppData()
        loadJournal()
    }

    private func loadJournal() {
        switch Persistence.load() {
        case .loaded(let stored):
            data = stored
            journalAvailable = true
        case .missing:
            journalAvailable = true
        case .setAside:
            journalAvailable = true
            journalNotice = .setAside
        case .unavailable:
            journalAvailable = false
        }
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
        RewardEngine.totalPoints(data: data)
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

    var partnerDisplayName: String {
        data.partnerName ?? tr("Partner")
    }

    /// The skill tree title the parent chose to wear, if still earned.
    var wornTitle: String? {
        SkillTree.wornTitle(data: data, catalog: catalog)
    }

    var displayTitle: String {
        wornTitle ?? level.title
    }

    func name(of sufferer: Sufferer) -> String {
        switch sufferer {
        case .me: return displayName
        case .partner: return partnerDisplayName
        case .both: return tr("%1$@ and %2$@", displayName, partnerDisplayName)
        }
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

    /// The season that many daycare years before the current one.
    func season(back offset: Int) -> Season {
        let date = Calendar.current.date(byAdding: .year, value: -offset, to: Date()) ?? Date()
        return Season.containing(date, firstUse: data.installedAt)
    }

    func seasonStats(for season: Season, now: Date = Date()) -> SeasonStats {
        StatsEngine.stats(data: data, catalog: catalog, season: season, now: now)
    }

    func hasBadge(_ id: String) -> Bool {
        data.badges[id] != nil
    }

    func isIconUnlocked(_ icon: AppIconOption) -> Bool {
        switch icon {
        case .petri, .classic: return true
        case .nightShift: return hasBadge(BadgeCatalog.nightShift)
        case .tissueBox: return count(of: GermCatalog.commonColdID) >= 3
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

    /// Lessons open with right answers in the daily quiz.
    func isArticleUnlocked(_ article: Article) -> Bool {
        hasPass || data.quiz.rightTotal >= article.unlockAtAnswers
    }

    func deepDiveUnlocked(for germ: Germ) -> Bool {
        hasPass || count(of: germ.id) > 0
    }

    /// Free accounts keep one kid; the Season Pass lifts the limit.
    var canAddKid: Bool {
        hasPass || data.kids.isEmpty
    }

    // MARK: - Household

    /// Trims a name and keeps it within the limit.
    private func clean(_ name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.nameLimit))
    }

    func completeOnboarding(kid: Kid?) {
        if var kid {
            kid.name = clean(kid.name)
            if !kid.name.isEmpty { data.kids = [kid] }
        }
        data.onboardingDone = true
        commit()
    }

    func setProfileName(_ name: String) {
        data.profileName = clean(name)
        commit()
    }

    func setPartnerName(_ name: String) {
        let trimmed = clean(name)
        data.partnerName = trimmed.isEmpty ? nil : trimmed
        commit()
    }

    func saveKid(_ kid: Kid) {
        var kid = kid
        kid.name = clean(kid.name)
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
        reconcileUnlocks()
        commit()
    }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        change(&data.settings)
        commit()
        rescheduleNotifications()
    }

    func wearTitle(_ id: String?) {
        data.settings.wornTitle = id
        commit()
    }

    func markArticleRead(_ id: String, now: Date = Date()) {
        guard !data.readArticles.contains(id) else { return }
        data.readArticles.append(id)
        _ = awardBadges(now: now)
        commit()
    }

    // MARK: - Lab

    var quizBank: [QuizQuestion] {
        QuizEngine.bank(catalog.germs)
    }

    func quizPlan(now: Date = Date()) -> [QuizQuestion] {
        QuizEngine.plan(progress: data.quiz, bank: quizBank, day: QuizEngine.dayKey(now))
    }

    func quizDone(now: Date = Date()) -> Bool {
        data.quiz.doneDays.contains(QuizEngine.dayKey(now))
    }

    /// Answers already given today, in order.
    func quizAnswers(now: Date = Date()) -> [Int] {
        guard let round = data.quiz.round, round.day == QuizEngine.dayKey(now) else { return [] }
        return round.answers
    }

    func labStreak(now: Date = Date()) -> Int {
        QuizEngine.streak(doneDays: data.quiz.doneDays, now: now)
    }

    /// Fixes today's questions the first time the quiz opens, so they survive a restart.
    func startQuiz(now: Date = Date()) -> [QuizQuestion] {
        let day = QuizEngine.dayKey(now)
        let plan = quizPlan(now: now)
        if data.quiz.round?.day != day {
            QuizEngine.start(&data.quiz, plan: plan, day: day)
            commit()
        }
        return plan
    }

    func answerQuiz(_ choice: Int, to question: QuizQuestion, now: Date = Date()) -> QuizOutcome? {
        let bankSize = quizBank.count
        guard let right = QuizEngine.answer(choice, to: question, progress: &data.quiz,
                                            day: QuizEngine.dayKey(now), bankSize: bankSize) else { return nil }
        let fresh = awardBadges(now: now)
        commit()
        return QuizOutcome(right: right, newBadges: fresh)
    }

    /// The lesson that opens next, and how many right answers it still needs.
    var nextLesson: (article: Article, remaining: Int)? {
        guard !hasPass, let article = catalog.articles.first(where: { !isArticleUnlocked($0) }) else { return nil }
        return (article, article.unlockAtAnswers - data.quiz.rightTotal)
    }

    // MARK: - Logging

    @discardableResult
    func logGerm(_ draft: LogDraft, now: Date = Date()) -> RewardResult? {
        guard let germ = catalog.germ(draft.germID) else { return nil }
        if let illnessID = draft.kidIllnessID,
           data.kidIllnesses.contains(where: { $0.id == illnessID && $0.outcome == .caught }) {
            return nil
        }
        let previousStreak = streakDays(now: draft.startedAt)
        let isNewCard = !caughtGermIDs.contains(germ.id)
        let levelBefore = level
        let iconsBefore = AppIconOption.allCases.filter { isIconUnlocked($0) }

        let bonuses = RewardEngine.bonuses(for: draft, germ: germ)
        let entry = SickLog(germID: germ.id, source: draft.source, severity: draft.severity,
                            startedAt: draft.startedAt, endedAt: nil,
                            points: bonuses.reduce(0) { $0 + $1.points }, bonuses: bonuses,
                            sufferer: draft.sufferer, kidIllnessID: draft.kidIllnessID)
        data.logs = JournalRules.normalized(data.logs + [entry])
        let log = data.logs.first { $0.id == entry.id } ?? entry

        if let illnessID = draft.kidIllnessID,
           let index = data.kidIllnesses.firstIndex(where: { $0.id == illnessID }) {
            stopWatching(data.kidIllnesses[index])
            data.kidIllnesses[index].outcome = .caught
            data.kidIllnesses[index].watching = false
        }

        let newBadges = awardBadges(now: now)
        commit()
        syncSickCheckIn()

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
        syncSickCheckIn()
    }

    func updateLog(_ log: SickLog, now: Date = Date()) {
        guard let index = data.logs.firstIndex(where: { $0.id == log.id }) else { return }
        data.logs[index] = log
        data.logs = JournalRules.normalized(data.logs)
        reconcileUnlocks(now: now)
        _ = awardBadges(now: now)
        commit()
        syncSickCheckIn()
    }

    func deleteLog(_ id: UUID) {
        data.logs.removeAll { $0.id == id }
        reconcileUnlocks()
        commit()
        syncSickCheckIn()
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
        data.kidIllnesses[index].liveDismissed = false
        let illness = data.kidIllnesses[index]
        commit()
        if watching, let germ = catalog.germ(illness.germID) {
            let kidName = kid(illness.kidID)?.name ?? tr("Your kid")
            NotificationManager.scheduleExposure(illness: illness, germ: germ, settings: data.settings)
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
        if outcome == .dodged {
            toast = tr("Dodged it. +%lld Sick Points", RewardEngine.dodgePoints)
        }
    }

    func deleteKidIllness(_ id: UUID) {
        if let illness = data.kidIllnesses.first(where: { $0.id == id }) { stopWatching(illness) }
        data.kidIllnesses.removeAll { $0.id == id }
        reconcileUnlocks()
        commit()
    }

    private func stopWatching(_ illness: KidIllness) {
        NotificationManager.cancelExposure(id: illness.id)
        LiveActivityManager.end(exposureID: illness.id)
    }

    // MARK: - Lifecycle

    /// Runs when the app comes to the foreground.
    func refresh(now: Date = Date()) {
        if !journalAvailable { loadJournal() }
        var changed = false
        for index in data.kidIllnesses.indices where data.kidIllnesses[index].outcome == .open {
            let illness = data.kidIllnesses[index]
            guard let germ = catalog.germ(illness.germID) else { continue }
            let deadline = germ.window(from: illness.startedAt)?.closes.addingTimeInterval(24 * 3600)
                ?? illness.startedAt.addingTimeInterval(Self.openExposureLifetime)
            if now > deadline {
                stopWatching(illness)
                data.kidIllnesses[index].outcome = .expired
                data.kidIllnesses[index].watching = false
                changed = true
            } else if illness.watching, !illness.liveDismissed {
                let kidName = kid(illness.kidID)?.name ?? tr("Your kid")
                LiveActivityManager.start(illness: illness, kidName: kidName, germ: germ)
            }
        }
        if !awardBadges(now: now).isEmpty { changed = true }
        if data.onboardingDone, pendingMilestone == nil, let days = Milestones.pending(data: data, now: now),
           let start = StreakMath.currentStart(data: data) {
            data.celebratedMilestone = MilestoneMark(streakStart: start, days: days)
            pendingMilestone = MilestoneEvent(days: days)
            changed = true
        }
        if changed { commit() } else { publishSnapshot() }
        syncStreakReminders(now: now)
    }

    /// Opens what a widget or a link asked for.
    func open(_ url: URL) {
        guard url.scheme == "petri", data.onboardingDone else { return }
        selectedTab = .today
        if url.host == "log" {
            pendingMilestone = nil
            logRequest = LogRequest()
        }
    }

    /// Replaces the journal with a backup, keeping the parent past onboarding.
    func restore(_ backup: AppData, now: Date = Date()) {
        for illness in data.kidIllnesses { stopWatching(illness) }
        var restored = backup
        restored.onboardingDone = true
        data = restored
        journalAvailable = true
        reconcileUnlocks(now: now)
        _ = awardBadges(now: now)
        commit()
        rescheduleNotifications()
    }

    /// Handles the Live Activity buttons, which run in the app process.
    func handle(_ action: IntentAction) async {
        switch action {
        case .caught(let exposureID):
            guard let id = UUID(uuidString: exposureID),
                  let illness = data.kidIllnesses.first(where: { $0.id == id }),
                  illness.outcome == .open else { return }
            let draft = LogDraft(germID: illness.germID, source: .kid(illness.kidID), severity: 3,
                                 startedAt: Date(), sufferer: .me, kidIllnessID: illness.id)
            pendingReward = logGerm(draft)
        case .stillFine(let exposureID):
            guard let id = UUID(uuidString: exposureID) else { return }
            LiveActivityManager.end(exposureID: id)
            if let index = data.kidIllnesses.firstIndex(where: { $0.id == id }) {
                data.kidIllnesses[index].liveDismissed = true
                commit()
            }
        }
    }

    func passDidChange() {
        publishSnapshot()
    }

    func eraseEverything() {
        for illness in data.kidIllnesses { stopWatching(illness) }
        NotificationManager.cancelSickCheckIn()
        NotificationManager.cancelStreakReminders()
        Persistence.erase()
        data = AppData()
        journalAvailable = true
        saveFailureReported = false
        journalNotice = nil
        pendingReward = nil
        logRequest = nil
        askBetter = false
        pendingMilestone = nil
        toast = nil
        selectedTab = .today
        publishSnapshot()
    }

    /// Asks for notification permission the first time a reminder needs it, then schedules them.
    func enableReminders() async {
        guard await NotificationManager.ensureAuthorization() else { return }
        rescheduleNotifications()
    }

    // MARK: - Internals

    /// After an entry is removed or changed: drops the badges the journal no longer earns,
    /// and falls back to the default theme and icon when theirs is locked again.
    private func reconcileUnlocks(now: Date = Date()) {
        let earned = RewardEngine.earnedBadges(data: data, catalog: catalog, now: now)
        data.badges = data.badges.filter { earned.contains($0.key) }
        if !isThemeUnlocked(data.settings.theme) {
            data.settings.theme = .agar
        }
        if data.settings.wornTitle != nil, SkillTree.wornTitle(data: data, catalog: catalog) == nil {
            data.settings.wornTitle = nil
        }
        let icon = AppIconManager.current
        if icon != .petri, !isIconUnlocked(icon) {
            Task {
                _ = await AppIconManager.apply(.petri)
            }
        }
    }

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
            NotificationManager.scheduleExposure(illness: illness, germ: germ, settings: data.settings)
        }
        syncSickCheckIn()
    }

    /// The daily check-in exists only while a germ is active; it carries that germ's advice.
    private func syncSickCheckIn() {
        if let log = activeLog {
            NotificationManager.scheduleSickCheckIn(settings: data.settings, germ: catalog.germ(log.germID),
                                                    startedAt: log.startedAt)
        } else {
            NotificationManager.cancelSickCheckIn()
        }
        syncStreakReminders(now: Date())
    }

    /// Announces the next streak milestone and the season story.
    private func syncStreakReminders(now: Date) {
        guard data.onboardingDone else { return }
        let calendar = Calendar.current
        if let start = StreakMath.currentStart(data: data),
           let next = Milestones.next(after: StreakMath.days(from: start, to: now)),
           let day = calendar.date(byAdding: .day, value: next, to: calendar.startOfDay(for: start)) {
            NotificationManager.scheduleMilestone(days: next, on: day, settings: data.settings)
        } else {
            NotificationManager.cancelMilestone()
        }
        let reveal = WrapEngine.revealDate(for: season)
        if reveal > now, data.logs.contains(where: { season.contains($0.startedAt) }) {
            NotificationManager.scheduleWrapped(at: reveal, settings: data.settings)
        }
    }

    private func commit() {
        if journalAvailable, !Persistence.save(data), !saveFailureReported {
            saveFailureReported = true
            journalNotice = .saveFailed
        }
        publishSnapshot()
    }

    private func publishSnapshot() {
        guard journalAvailable else { return }
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

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

    /// True when the log brought something new: a card, a badge, a level or an icon.
    var isNotable: Bool {
        isNewCard || !newBadges.isEmpty || levelAfter.number > levelBefore.number || !unlockedIcons.isEmpty
    }
}

/// What the boss-defeated screen shows after "I'm better".
struct Victory: Identifiable {
    let id = UUID()
    let log: SickLog
    let germ: Germ
    let points: Int
}

/// What the kid's victory screen shows once they are better.
struct KidVictory: Identifiable {
    let id = UUID()
    let kid: Kid
    let germ: Germ
    let days: Int
    /// How many times this kid has beaten this germ, this time included.
    let wins: Int
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
    private(set) var catalog: GermCatalog
    /// The weekly "Going around" reports from the online Guide file.
    private(set) var goingAroundReports: [GoingAroundReport]
    let household = HouseholdGuide.load()
    var pendingReward: RewardResult?
    /// The reward of a log made in a sheet; it shows once that sheet has closed.
    @ObservationIgnored var stagedReward: RewardResult?
    var pendingVictory: Victory?
    var pendingKidVictory: KidVictory?
    var logRequest: LogRequest?
    var selectedTab = AppTab.today
    var journalNotice: JournalNotice?
    var askBetter = false
    /// Settings, opened from the gear in the corner of every tab.
    var showSettings = false
    var pendingMilestone: MilestoneEvent?
    /// A short confirmation shown at the top of the screen.
    var toast: String?
    /// A mascot trick just found, shown with the clue to the next one.
    var trickFound: MascotTrick?
    /// The free trial's offer after the first illness.
    var showTrialOffer = false

    /// False while the journal file exists but cannot be read; nothing is saved over it then.
    @ObservationIgnored private var journalAvailable = true
    /// The last copy of the online Guide file.
    @ObservationIgnored private var lessonFeed: LessonFeed
    @ObservationIgnored private var saveFailureReported = false

    init() {
        let feed = LessonFeedClient.cached()
        lessonFeed = feed
        goingAroundReports = feed.goingAround ?? []
        catalog = GermCatalog.load(feed: feed.lessons)
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

    /// Kids' illnesses still going on today.
    var sickKidIllnesses: [KidIllness] {
        let now = Date()
        return data.kidIllnesses.filter { DayEngine.isGoingOn($0, catalog: catalog, now: now) }
    }

    /// Whether this person has an illness going on today.
    func isSick(_ person: Person) -> Bool {
        switch person {
        case .kid(let id): sickKidIllnesses.contains { $0.kidID == id }
        case .me: data.logs.contains { $0.isActive && $0.sufferer.includesMe }
        case .partner: data.logs.contains { $0.isActive && $0.sufferer.includesPartner }
        }
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
        case .germily, .daylight: return true
        case .nightShift: return hasBadge(BadgeCatalog.nightShift)
        case .snowDay: return count(of: GermCatalog.commonColdID) >= 3
        case .golden: return data.logs.count >= 20
        case .soupBowl: return hasPass
        case .holo: return !catalog.germs.isEmpty && caughtGermIDs.count >= catalog.germs.count
        }
    }

    /// Each theme opens with the badge it takes its color from, or all open with the Season Pass.
    func isThemeUnlocked(_ theme: Theme) -> Bool {
        guard let badge = theme.badgeID else { return true }
        return hasPass || hasBadge(badge)
    }

    /// Open once read, with the Season Pass for an online lesson, with right answers for a bundled one.
    func isArticleUnlocked(_ article: Article) -> Bool {
        LessonEngine.isUnlocked(article, data: data, hasPass: hasPass)
    }

    /// Online lessons in their first week, newest first.
    func lessonsThisWeek(now: Date = Date()) -> [Article] {
        catalog.articles.filter { LessonEngine.isNew($0, now: now) }
            .sorted { ($0.releasedOn ?? now) > ($1.releasedOn ?? now) }
    }

    /// Every lesson, the next one to read first.
    func lessonsToRead(now: Date = Date()) -> [Article] {
        LessonEngine.readingOrder(catalog.articles, data: data, hasPass: hasPass, now: now)
    }

    /// The report for the phone's country, Canada or the US, while it is recent.
    func goingAround(now: Date = Date()) -> GoingAroundReport? {
        guard let region = GoingAroundEngine.region(for: Locale.current.region?.identifier) else { return nil }
        return GoingAroundEngine.current(goingAroundReports, region: region, known: Set(catalog.germs.map { $0.id }), now: now)
    }

    /// The first day a free journal shows; nil with the Season Pass, which shows every day.
    var historyStart: Date? {
        guard !hasPass else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: Date()))
    }

    /// What a lock row says the free week leaves out: the season's sick days, or the older entries
    /// when the season has none yet.
    func lockedHistoryTitle(for person: Person?, hidden: Int, now: Date = Date()) -> String {
        let days = DayEngine.loggedDays(in: season, person: person, data: data, catalog: catalog, now: now)
        return days > 0 ? trCount(days, one: "%lld day logged this season", other: "%lld days logged this season")
                        : trCount(hidden, one: "%lld older entry", other: "%lld older entries")
    }

    /// Entries on or after the first day the journal shows, plus anything still going on.
    func isShown(_ start: Date, ongoing: Bool = false) -> Bool {
        guard let first = historyStart else { return true }
        return ongoing || start >= first
    }

    /// Free accounts keep one kid; the Season Pass lifts the limit.
    var canAddKid: Bool {
        hasPass || data.kids.isEmpty
    }

    /// The first kid is free; the others need the Season Pass.
    func isKidOpen(_ kidID: UUID) -> Bool {
        hasPass || data.kids.first?.id == kidID
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

    func setHostLook(_ look: Int) {
        data.hostLook = look
        commit()
    }

    func setPartnerLook(_ look: Int) {
        data.partnerLook = look
        commit()
    }

    /// Without the Season Pass, only the free looks can be picked.
    func isLookOpen(_ look: Int) -> Bool {
        Looks.isOpen(look, hasPass: hasPass)
    }

    /// The looks offered when someone is added, in picker order; Settings can hide the others.
    var shownLooks: [Int] {
        Looks.shown(hidden: data.settings.hiddenLooks, hasPass: hasPass)
    }

    /// The first open, shown look nobody in the household has yet, so a new kid does not start as a twin.
    var nextKidLook: Int {
        let taken = Set((data.kids.map { $0.colorIndex } + [data.hostLook, data.partnerLook]).map { abs($0) % Looks.count })
        let open = shownLooks.filter(isLookOpen)
        return open.first { !taken.contains($0) } ?? open[data.kids.count % open.count]
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
            retire(illness)
        }
        let photos = data.photos.filter { $0.person == .kid(id) }
        data.kids.removeAll { $0.id == id }
        data.kidIllnesses.removeAll { $0.kidID == id }
        data.photos.removeAll { $0.person == .kid(id) }
        reconcileUnlocks()
        commit()
        for photo in photos { PhotoStore.delete(photo.id) }
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

    // MARK: - Quiz

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
        QuizEngine.streak(doneDays: data.quiz.doneDays, sickDays: QuizEngine.sickDays(logs: data.logs, now: now), now: now)
    }

    /// True while the parent is sick, which pauses the quiz streak instead of breaking it.
    var onSickLeave: Bool {
        activeLog?.sufferer.includesMe == true
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

    /// The bundled lesson that opens next, and how many right answers it still needs.
    var nextLesson: (article: Article, remaining: Int)? {
        guard let article = catalog.articles.first(where: { !$0.needsPass && !isArticleUnlocked($0) }) else { return nil }
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
        var entry = SickLog(germID: germ.id, source: draft.source, severity: draft.severity,
                            startedAt: draft.startedAt, endedAt: nil,
                            points: bonuses.reduce(0) { $0 + $1.points }, bonuses: bonuses,
                            sufferer: draft.sufferer, kidIllnessID: draft.kidIllnessID)
        entry.symptoms = draft.symptoms
        data.logs = JournalRules.normalized(data.logs + [entry])
        let log = data.logs.first { $0.id == entry.id } ?? entry

        if let illnessID = draft.kidIllnessID,
           let index = data.kidIllnesses.firstIndex(where: { $0.id == illnessID }) {
            retire(data.kidIllnesses[index])
            data.kidIllnesses[index].outcome = .caught
            data.kidIllnesses[index].watching = false
        }

        let newBadges = awardBadges(now: now)
        commit()
        syncSickCheckIn()
        syncSymptomCheck(for: log)

        let iconsAfter = AppIconOption.allCases.filter { isIconUnlocked($0) }
        return RewardResult(log: log, germ: germ, isNewCard: isNewCard, previousStreak: previousStreak,
                            newBadges: newBadges, levelBefore: levelBefore, levelAfter: level,
                            unlockedIcons: iconsAfter.filter { !iconsBefore.contains($0) })
    }

    /// Ends the active germ; a real recovery, not a quick correction, earns points and the boss-defeated screen.
    func markBetter(now: Date = Date()) {
        guard let active = activeLog, let index = data.logs.firstIndex(where: { $0.id == active.id }) else { return }
        data.logs[index].endedAt = max(active.startedAt, now)
        let recovered = now.timeIntervalSince(active.startedAt) >= RewardEngine.speedrunMinimum
        if recovered && !data.logs[index].bonuses.contains(where: { $0.kind == .recovery }) {
            data.logs[index].bonuses.append(LogBonus(kind: .recovery, points: RewardEngine.recoveryPoints))
            data.logs[index].points += RewardEngine.recoveryPoints
        }
        _ = awardBadges(now: now)
        commit()
        syncSickCheckIn()
        NotificationManager.cancelSymptomCheck(id: active.id)
        if recovered, let germ = catalog.germ(active.germID) {
            pendingVictory = Victory(log: data.logs[index], germ: germ, points: RewardEngine.recoveryPoints)
        }
    }

    /// Last month in numbers, for the recap card in Season.
    func lastMonthRecap(now: Date = Date()) -> MonthRecap {
        MonthRecapEngine.recap(data: data, catalog: catalog, month: MonthRecapEngine.previousMonth(now), now: now)
    }

    /// Records a trick of the Today mascot the first time it is found; the last one earns the Ticklish badge.
    func discoverTrick(_ trick: MascotTrick, now: Date = Date()) {
        guard !data.mascotTricks.contains(trick.rawValue) else { return }
        data.mascotTricks.append(trick.rawValue)
        let fresh = awardBadges(now: now)
        commit()
        guard let badge = fresh.first else {
            trickFound = trick
            return
        }
        Haptics.success()
        SoundPlayer.shared.play(.badge)
        toast = tr("New badge: %@", badge.title)
    }

    /// Records the season's nemesis guess once; a right guess adds points.
    func guessNemesis(_ germID: String, season: Season, now: Date = Date()) {
        let key = String(season.number)
        guard data.wrapGuesses[key] == nil else { return }
        let wrap = WrapEngine.wrap(data: data, catalog: catalog, season: season, now: now)
        data.wrapGuesses[key] = wrap.topGerm?.germ.id == germID
        commit()
    }

    func updateLog(_ log: SickLog, now: Date = Date()) {
        guard let index = data.logs.firstIndex(where: { $0.id == log.id }) else { return }
        data.logs[index] = log
        data.logs = JournalRules.normalized(data.logs)
        reconcileUnlocks(now: now)
        _ = awardBadges(now: now)
        commit()
        syncSickCheckIn()
        if let stored = data.logs.first(where: { $0.id == log.id }) {
            syncSymptomCheck(for: stored)
        }
    }

    /// Changes what a logged germ was once the symptoms say more. Its points follow the new germ's rarity.
    func reassignLog(_ id: UUID, germID: String, symptoms: [String], now: Date = Date()) {
        guard var log = data.logs.first(where: { $0.id == id }), let germ = catalog.germ(germID) else { return }
        if log.germID != germID, let rarity = log.bonuses.firstIndex(where: { $0.kind == .rarity }) {
            log.points += germ.rarity.basePoints - log.bonuses[rarity].points
            log.bonuses[rarity].points = germ.rarity.basePoints
        }
        log.germID = germID
        log.symptoms = symptoms
        updateLog(log, now: now)
    }

    func deleteLog(_ id: UUID) {
        data.logs.removeAll { $0.id == id }
        for index in data.photos.indices where data.photos[index].logID == id {
            data.photos[index].logID = nil
        }
        reconcileUnlocks()
        commit()
        syncSickCheckIn()
        NotificationManager.cancelSymptomCheck(id: id)
    }

    // MARK: - Kid illnesses and exposures

    @discardableResult
    func addKidIllness(kidID: UUID, germID: String, startedAt: Date, symptoms: [String] = []) -> KidIllness {
        var illness = KidIllness(kidID: kidID, germID: germID, startedAt: startedAt, watching: false, outcome: .open)
        illness.symptoms = symptoms
        data.kidIllnesses.append(illness)
        commit()
        syncSymptomCheck(for: illness)
        return illness
    }

    /// Changes what a kid has once the symptoms say more; the countdown follows the new germ.
    func reassignKidIllness(_ id: UUID, germID: String, symptoms: [String]) {
        guard let index = data.kidIllnesses.firstIndex(where: { $0.id == id }),
              let germ = catalog.germ(germID) else { return }
        let keepWatching = data.kidIllnesses[index].watching && germ.incubationMinHours != nil
        stopWatching(data.kidIllnesses[index])
        data.kidIllnesses[index].germID = germID
        data.kidIllnesses[index].symptoms = symptoms
        data.kidIllnesses[index].watching = false
        let illness = data.kidIllnesses[index]
        commit()
        syncSymptomCheck(for: illness)
        if keepWatching { setWatching(id, watching: true) }
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
        retire(data.kidIllnesses[index])
        data.kidIllnesses[index].outcome = outcome
        data.kidIllnesses[index].watching = false
        _ = awardBadges(now: now)
        commit()
        if outcome == .dodged {
            toast = tr("Dodged it. +%lld Sick Points", RewardEngine.dodgePoints)
        }
    }

    /// Ends a kid's illness on a day; on today it ends now.
    func markKidBetter(_ id: UUID, on day: Date, now: Date = Date()) {
        guard let index = data.kidIllnesses.firstIndex(where: { $0.id == id }) else { return }
        let calendar = Calendar.current
        let end = calendar.isDate(day, inSameDayAs: now)
            ? now : calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        data.kidIllnesses[index].endedAt = max(data.kidIllnesses[index].startedAt, end)
        let illness = data.kidIllnesses[index]
        commit()
        syncSymptomCheck(for: illness)
    }

    /// Takes "better" back: the kid's illness goes on again.
    func reopenKidIllness(_ id: UUID) {
        guard let index = data.kidIllnesses.firstIndex(where: { $0.id == id }) else { return }
        data.kidIllnesses[index].endedAt = nil
        let illness = data.kidIllnesses[index]
        commit()
        syncSymptomCheck(for: illness)
    }

    func deleteKidIllness(_ id: UUID) {
        if let illness = data.kidIllnesses.first(where: { $0.id == id }) { retire(illness) }
        data.kidIllnesses.removeAll { $0.id == id }
        for index in data.photos.indices where data.photos[index].illnessID == id {
            data.photos[index].illnessID = nil
        }
        reconcileUnlocks()
        commit()
    }

    private func stopWatching(_ illness: KidIllness) {
        NotificationManager.cancelExposure(id: illness.id)
        LiveActivityManager.end(exposureID: illness.id)
    }

    /// Ends everything scheduled for an illness that is over or gone.
    private func retire(_ illness: KidIllness) {
        stopWatching(illness)
        NotificationManager.cancelSymptomCheck(id: illness.id)
    }

    /// A mystery germ gets one question two days in: any new symptoms?
    private func syncSymptomCheck(for illness: KidIllness) {
        if illness.outcome == .open, illness.endedAt == nil, illness.germID == GermCatalog.mysteryID {
            NotificationManager.scheduleSymptomCheck(id: illness.id, name: kid(illness.kidID)?.name,
                                                     startedAt: illness.startedAt, settings: data.settings)
        } else {
            NotificationManager.cancelSymptomCheck(id: illness.id)
        }
    }

    private func syncSymptomCheck(for log: SickLog) {
        if log.isActive, log.germID == GermCatalog.mysteryID {
            NotificationManager.scheduleSymptomCheck(id: log.id, name: nil, startedAt: log.startedAt,
                                                     settings: data.settings)
        } else {
            NotificationManager.cancelSymptomCheck(id: log.id)
        }
    }

    // MARK: - Photos

    /// Files pictures already written by PhotoStore under one person, moment and illness.
    func addPhotos(_ ids: [UUID], person: Person, takenAt: Date, logID: UUID?, illnessID: UUID?) {
        data.photos += ids.map {
            PatientPhoto(id: $0, person: person, takenAt: takenAt, logID: logID, illnessID: illnessID)
        }
        commit()
    }

    func deletePhoto(_ id: UUID) {
        data.photos.removeAll { $0.id == id }
        commit()
        PhotoStore.delete(id)
    }

    // MARK: - Lifecycle

    /// Runs when the app comes to the foreground.
    func refresh(now: Date = Date()) {
        if !journalAvailable { loadJournal() }
        catalog = catalog.updated(feed: lessonFeed.lessons, now: now)
        var changed = false
        for index in data.kidIllnesses.indices where data.kidIllnesses[index].outcome == .open {
            let illness = data.kidIllnesses[index]
            guard let germ = catalog.germ(illness.germID) else { continue }
            let deadline = germ.window(from: illness.startedAt)?.closes.addingTimeInterval(24 * 3600)
                ?? illness.startedAt.addingTimeInterval(Self.openExposureLifetime)
            if now > deadline {
                retire(illness)
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
        guard url.scheme == "germily", data.onboardingDone else { return }
        selectedTab = .today
        if url.host == "log" {
            pendingMilestone = nil
            logRequest = LogRequest()
        }
    }

    /// Replaces the journal and its photos with a backup, keeping the parent past onboarding.
    func restore(_ backup: Backup, now: Date = Date()) {
        for illness in data.kidIllnesses { retire(illness) }
        for log in data.logs { NotificationManager.cancelSymptomCheck(id: log.id) }
        var restored = backup.data
        restored.onboardingDone = true
        restored.photos = restored.photos.filter { photo in
            backup.photoFiles[photo.id].map { PhotoStore.write($0, id: photo.id) } ?? false
        }
        PhotoStore.keepOnly(Set(restored.photos.map { $0.id }))
        data = restored
        journalAvailable = true
        reconcileUnlocks(now: now)
        _ = awardBadges(now: now)
        commit()
        rescheduleNotifications()
    }

    /// The full reveal when the log brought something new; a toast for a repeat catch.
    /// After a sheet, the reveal waits a second so the screen settles first.
    func showReward(_ reward: RewardResult, settling: Bool = true) {
        guard reward.isNotable else {
            Haptics.success()
            toast = tr("Repeat catch: %1$@, card ×%2$lld", reward.germ.name, count(of: reward.germ.id))
            return
        }
        guard settling else {
            pendingReward = reward
            return
        }
        SoundPlayer.shared.play(.flap)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self.pendingReward = reward
        }
    }

    /// Offers the free trial once, after the first illness, when the trial is on offer and nothing else is showing.
    func offerTrialIfDue() {
        guard data.onboardingDone, !data.trialOffered, !hasPass, PurchaseManager.shared.trialDays != nil,
              !data.logs.isEmpty || !data.kidIllnesses.isEmpty,
              pendingReward == nil, pendingVictory == nil, pendingKidVictory == nil, pendingMilestone == nil,
              logRequest == nil else { return }
        data.trialOffered = true
        commit()
        showTrialOffer = true
    }

    /// Shows the reward staged by a sheet that just closed.
    func showStagedReward() {
        guard let reward = stagedReward else { return }
        stagedReward = nil
        showReward(reward)
    }

    /// Handles the Live Activity and notification buttons, which run in the app process.
    func handle(_ action: IntentAction) async {
        switch action {
        case .caught(let exposureID):
            guard let id = UUID(uuidString: exposureID),
                  let illness = data.kidIllnesses.first(where: { $0.id == id }),
                  illness.outcome == .open else { return }
            let draft = LogDraft(germID: illness.germID, source: .kid(illness.kidID), severity: 3,
                                 startedAt: Date(), sufferer: .me, kidIllnessID: illness.id)
            if let result = logGerm(draft) { showReward(result, settling: false) }
        case .stillFine(let exposureID):
            guard let id = UUID(uuidString: exposureID) else { return }
            LiveActivityManager.end(exposureID: id)
            if let index = data.kidIllnesses.firstIndex(where: { $0.id == id }) {
                data.kidIllnesses[index].liveDismissed = true
                commit()
            }
        case .dodged(let exposureID):
            guard let id = UUID(uuidString: exposureID),
                  data.kidIllnesses.contains(where: { $0.id == id && $0.outcome == .open }) else { return }
            resolveExposure(id, outcome: .dodged)
        case .better:
            markBetter()
        case .kidCaught(let kidID, let germID):
            guard let id = UUID(uuidString: kidID), let kid = data.kids.first(where: { $0.id == id }),
                  catalog.germ(germID) != nil else { return }
            addKidIllness(kidID: id, germID: germID, startedAt: Date())
            selectedTab = .family
            toast = tr("Added to %@'s history.", kid.name)
        }
    }

    func passDidChange() {
        publishSnapshot()
        syncLessonReminders()
    }

    func eraseEverything() {
        for illness in data.kidIllnesses { retire(illness) }
        for log in data.logs { NotificationManager.cancelSymptomCheck(id: log.id) }
        NotificationManager.cancelSickCheckIn()
        NotificationManager.cancelStreakReminders()
        Persistence.erase()
        PhotoStore.eraseAll()
        data = AppData()
        journalAvailable = true
        saveFailureReported = false
        journalNotice = nil
        pendingReward = nil
        logRequest = nil
        askBetter = false
        showSettings = false
        pendingMilestone = nil
        toast = nil
        trickFound = nil
        pendingKidVictory = nil
        showTrialOffer = false
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
        if icon != .germily, !isIconUnlocked(icon) {
            Task {
                _ = await AppIconManager.apply(.germily)
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

    /// Reads the online Guide file, then announces the lessons still to come.
    func refreshLessons() async {
        let previous = lessonFeed.lessons.map { $0.id }
        if let feed = await LessonFeedClient.fetch() {
            lessonFeed = feed
            goingAroundReports = feed.goingAround ?? []
        }
        catalog = catalog.updated(feed: lessonFeed.lessons)
        syncLessonReminders(dropping: previous)
    }

    /// Replaces the lesson announcements; `dropping` also clears lessons no longer in the file.
    private func syncLessonReminders(dropping previous: [String] = []) {
        let known = Array(Set(previous + lessonFeed.lessons.map { $0.id }))
        NotificationManager.scheduleLessons(catalog.upcoming, known: known, settings: data.settings, hasPass: hasPass)
    }

    private func rescheduleNotifications() {
        for illness in data.kidIllnesses where illness.watching && illness.outcome == .open {
            guard let germ = catalog.germ(illness.germID) else { continue }
            NotificationManager.scheduleExposure(illness: illness, germ: germ, settings: data.settings)
        }
        for illness in data.kidIllnesses { syncSymptomCheck(for: illness) }
        if let log = activeLog { syncSymptomCheck(for: log) }
        syncSickCheckIn()
        syncLessonReminders()
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
        let month = MonthRecapEngine.recap(data: data, catalog: catalog, month: now, now: now)
        if !month.isEmpty, let next = calendar.dateInterval(of: .month, for: now)?.end {
            NotificationManager.scheduleMonthRecap(month: month.monthName, on: next, settings: data.settings)
        } else {
            NotificationManager.cancelMonthRecap()
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

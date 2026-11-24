import Foundation

// Logic checks for the journal rules, streaks, badges, stats, days, lessons, journal decoding, character motion,
// the Today mascot, the Season Pass offer and day one.
// They need no simulator: tools/run_logic_tests.sh compiles them with the files they exercise.

var failures = 0

func check(_ condition: Bool, _ label: String) {
    if condition { return }
    failures += 1
    print("FAILED: " + label)
}

func day(_ offset: Int, hour: Int = 12) -> Date {
    let calendar = Calendar.current
    let base = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: hour)) ?? Date()
    return calendar.date(byAdding: .day, value: offset, to: base) ?? base
}

func makeLog(_ germID: String, from start: Date, to end: Date?, sufferer: Sufferer = .me,
             bonuses: [LogBonus] = []) -> SickLog {
    SickLog(germID: germID, source: .unknown, severity: 3, startedAt: start, endedAt: end,
            points: 80, bonuses: bonuses, sufferer: sufferer, kidIllnessID: nil)
}

func makeGerm(_ id: String, rarity: Rarity, family: GermFamily = .airways, lasts: Int? = 10, myths: Int = 1) -> Germ {
    let text = LocalizedText(en: id, fr: id)
    return Germ(id: id, number: 1, name: id, illness: text, phrase: text, scientific: text, rarity: rarity,
                tintLight: "#FFFFFF", tintDeep: "#000000", quickPick: true, incubationMinHours: 24,
                incubationMaxHours: 72, showsUp: text, lasts: text, facts: [], tips: [], doctor: text,
                deepDive: [], sources: [], family: family, lastsUpToDays: lasts, doctorLead: text, doctorSigns: [text],
                doctorNote: nil, boss: GermBoss(attack: text, weakness: text),
                myths: (1...myths).map { GermMyth(id: "\(id)-\($0)", claim: text, isTrue: true, explanation: text, source: "") },
                kidSource: nil)
}

func makeData(logs: [SickLog] = [], illnesses: [KidIllness] = []) -> AppData {
    var data = AppData()
    data.installedAt = day(0)
    data.logs = logs
    data.kidIllnesses = illnesses
    return data
}

let catalog = GermCatalog(germs: [makeGerm("rhino", rarity: .common), makeGerm("noro", rarity: .rare, family: .gut)],
                          articles: [])

// MARK: - Streaks

do {
    let empty = makeData()
    check(StreakMath.current(data: empty, now: day(5)) == 5, "streak counts days since install")
    check(StreakMath.record(data: empty, now: day(5)) == 5, "record equals the only run")

    let closed = makeData(logs: [makeLog("rhino", from: day(5), to: day(8))])
    check(StreakMath.current(data: closed, now: day(10)) == 2, "streak restarts when a germ ends")
    check(StreakMath.gaps(data: closed, now: day(10)) == [5, 2], "gaps before and after one germ")
    check(StreakMath.record(data: closed, now: day(10)) == 5, "record keeps the longest run")

    let sick = makeData(logs: [makeLog("rhino", from: day(5), to: day(8)), makeLog("noro", from: day(12), to: nil)])
    check(StreakMath.current(data: sick, now: day(13)) == 0, "streak is zero while sick")
    check(StreakMath.currentStart(data: sick) == nil, "no streak start while sick")
}

// MARK: - Journal rules

do {
    let first = makeLog("rhino", from: day(1), to: nil)
    let second = makeLog("noro", from: day(4), to: nil)
    let fixed = JournalRules.normalized([second, first])
    check(fixed.map { $0.id } == [second.id, first.id], "normalizing keeps the stored order")
    check(fixed[1].endedAt == day(4), "an earlier open log ends when the next one starts")
    check(fixed[0].endedAt == nil, "the latest log may stay open")
    check(fixed.filter { $0.isActive }.count == 1, "at most one log is open")
    check(JournalRules.latestID(in: [second, first]) == second.id, "latest log is found by start date")

    let backwards = makeLog("rhino", from: day(6), to: day(5))
    check(JournalRules.normalized([backwards])[0].endedAt == day(6), "a log never ends before it starts")

    let single = makeLog("rhino", from: day(2), to: day(3))
    check(JournalRules.normalized([single]) == [single], "a consistent journal is left alone")
}

// MARK: - Points and badges

do {
    let night = LogDraft(germID: "rhino", source: .unknown, severity: 3, startedAt: day(0, hour: 2),
                         sufferer: .me, kidIllnessID: nil)
    let noon = LogDraft(germID: "rhino", source: .unknown, severity: 3, startedAt: day(0, hour: 12),
                        sufferer: .me, kidIllnessID: nil)
    let germ = makeGerm("rhino", rarity: .common)
    check(RewardEngine.bonuses(for: night, germ: germ).contains { $0.kind == .nightShift }, "night shift bonus at 2 AM")
    check(RewardEngine.bonuses(for: noon, germ: germ).map { $0.kind } == [.rarity], "no night bonus at noon")
    check(RewardEngine.bonuses(for: noon, germ: germ)[0].points == Rarity.common.basePoints, "rarity sets the base points")

    let one = makeData(logs: [makeLog("rhino", from: day(1), to: nil)])
    check(RewardEngine.earnedBadges(data: one, catalog: catalog, now: day(1)).contains("patient_one"), "first germ badge")
    check(!RewardEngine.earnedBadges(data: makeData(), catalog: catalog, now: day(1)).contains("patient_one"),
          "an emptied journal no longer earns the first germ badge")

    let blink = makeData(logs: [makeLog("rhino", from: day(1), to: day(1).addingTimeInterval(600))])
    check(!RewardEngine.earnedBadges(data: blink, catalog: catalog, now: day(2)).contains("speedrun"),
          "a log closed after ten minutes is not a speedrun")
    let quick = makeData(logs: [makeLog("rhino", from: day(1), to: day(1).addingTimeInterval(6 * 3600))])
    check(RewardEngine.earnedBadges(data: quick, catalog: catalog, now: day(2)).contains("speedrun"),
          "recovering in six hours is a speedrun")

    let long = makeData(logs: [makeLog("rhino", from: day(1), to: day(11))])
    check(RewardEngine.earnedBadges(data: long, catalog: catalog, now: day(12)).contains("marathon"), "ten days is a marathon")

    let again = makeData(logs: [makeLog("rhino", from: day(1), to: day(3)), makeLog("rhino", from: day(20), to: day(22))])
    check(RewardEngine.earnedBadges(data: again, catalog: catalog, now: day(23)).contains("boomerang"), "same germ within 30 days")

    let rough = makeData(logs: [makeLog("rhino", from: day(1), to: day(2)), makeLog("noro", from: day(8), to: day(9)),
                                makeLog("rhino", from: day(15), to: day(16))])
    check(RewardEngine.earnedBadges(data: rough, catalog: catalog, now: day(17)).contains("rough_month"), "three germs in a month")

    let pair = makeData(logs: [makeLog("rhino", from: day(1), to: day(2), sufferer: .both)])
    check(RewardEngine.earnedBadges(data: pair, catalog: catalog, now: day(3)).contains("tag_team"), "both parents sick")

    let kidID = UUID()
    func exposures(_ outcome: ExposureOutcome) -> [KidIllness] {
        (0..<3).map { KidIllness(kidID: kidID, germID: "noro", startedAt: day($0), watching: false, outcome: outcome) }
    }
    check(RewardEngine.earnedBadges(data: makeData(illnesses: exposures(.dodged)), catalog: catalog, now: day(9)).contains("dodger"),
          "three answered dodges earn the badge")
    check(!RewardEngine.earnedBadges(data: makeData(illnesses: exposures(.expired)), catalog: catalog, now: day(9)).contains("dodger"),
          "expired windows do not count as dodges")
}

// MARK: - Season stats

do {
    let kid = Kid(name: "Lou", colorIndex: 0)
    var data = makeData(logs: [makeLog("rhino", from: day(1), to: day(3)), makeLog("noro", from: day(10), to: day(11))],
                        illnesses: [KidIllness(kidID: kid.id, germID: "noro", startedAt: day(2), watching: false, outcome: .dodged),
                                    KidIllness(kidID: kid.id, germID: "noro", startedAt: day(4), watching: false, outcome: .expired)])
    data.kids = [kid]
    let season = Season.containing(day(0), firstUse: day(0))
    let stats = StatsEngine.stats(data: data, catalog: catalog, season: season, now: day(20))
    check(stats.germsCaught == 2, "season counts both germs")
    check(stats.daysSick == 5, "sick days count first and last day")
    check(stats.dodged == 1, "only answered dodges are counted")
    check(stats.months.count == 12, "a season has twelve months")
}

// MARK: - Journal decoding

do {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    let older = """
    {"schemaVersion":1,"onboardingDone":true,"profileName":"Sam","installedAt":"2026-09-01T12:00:00Z",
     "kids":[{"id":"6F1B7C0E-7C39-4E9D-9B1D-0C3E1A2B3C4D","name":"Lou","ageYears":2,
              "daycareSince":"2026-01-10T12:00:00Z","colorIndex":1}],
     "logs":[{"id":"0A1B2C3D-0000-4000-8000-000000000001","germID":"rhino","source":{"unknown":{}},"severity":3,
              "startedAt":"2026-10-02T12:00:00Z","points":80,"bonuses":[{"kind":"rarity","points":80}],
              "partnerSickToo":false}],
     "kidIllnesses":[],"badges":{"patient_one":"2026-10-02T12:00:00Z"},
     "settings":{"appearance":"dark","theme":"agar","soundsOn":false,"checkInsOn":true,"crewAlertsOn":true,
                 "quietHoursOn":true,"quietStartMinute":1320,"quietEndMinute":420,"sideloadPass":false},
     "readArticles":["fever"]}
    """
    let fromOlder = try? decoder.decode(AppData.self, from: Data(older.utf8))
    check(fromOlder != nil, "a journal written by the first version still loads")
    check(fromOlder?.kids.first?.name == "Lou", "kids survive the removed fields")
    check(fromOlder?.logs.count == 1 && fromOlder?.logs.first?.isActive == true, "logs survive, open log stays open")
    check(fromOlder?.settings.appearance == .dark && fromOlder?.settings.soundsOn == false, "settings survive")
    check(fromOlder?.badges["patient_one"] != nil, "badges survive")
    check(fromOlder?.logs.first?.sufferer == .me, "an old log without a partner is the parent's own")

    let tagTeam = """
    {"logs":[{"id":"0A1B2C3D-0000-4000-8000-000000000005","germID":"rhino","startedAt":"2026-10-05T12:00:00Z",
              "partnerSickToo":true}]}
    """
    check((try? decoder.decode(AppData.self, from: Data(tagTeam.utf8)))?.logs.first?.sufferer == .both,
          "an old log with the partner sick too counts for both")

    let sparse = """
    {"logs":[{"id":"0A1B2C3D-0000-4000-8000-000000000002","germID":"noro","startedAt":"2026-10-05T12:00:00Z"}]}
    """
    let fromSparse = try? decoder.decode(AppData.self, from: Data(sparse.utf8))
    check(fromSparse?.logs.first?.severity == 3, "a missing field takes its default")
    check(fromSparse?.settings.checkInsOn == true, "missing settings take their defaults")
    check(fromSparse?.onboardingDone == false, "missing flags take their defaults")

    let future = """
    {"onboardingDone":true,"somethingNew":{"a":1},"settings":{"theme":"not-a-theme","brandNew":true},"logs":[]}
    """
    let fromFuture = try? decoder.decode(AppData.self, from: Data(future.utf8))
    check(fromFuture?.onboardingDone == true, "unknown keys from a newer version are ignored")
    check(fromFuture?.settings.theme == .agar, "an unknown setting value falls back to its default")

    let broken = """
    {"logs":[{"id":"0A1B2C3D-0000-4000-8000-000000000003","germID":"noro"}]}
    """
    check((try? decoder.decode(AppData.self, from: Data(broken.utf8))) == nil, "a log without a start date is refused, not invented")

    let exposure = """
    {"kidIllnesses":[{"id":"0A1B2C3D-0000-4000-8000-000000000004","kidID":"6F1B7C0E-7C39-4E9D-9B1D-0C3E1A2B3C4D",
                      "germID":"noro","startedAt":"2026-10-05T12:00:00Z","watching":true,"outcome":"open"}]}
    """
    let fromExposure = try? decoder.decode(AppData.self, from: Data(exposure.utf8))
    check(fromExposure?.kidIllnesses.first?.watching == true, "an exposure saved by the previous version still loads")
    check(fromExposure?.kidIllnesses.first?.liveDismissed == false, "its Live Activity counts as not dismissed")

    var current = makeData(logs: [makeLog("rhino", from: day(1), to: day(2))])
    current.kids = [Kid(name: "Lou", colorIndex: 2)]
    let roundTrip = (try? encoder.encode(current)).flatMap { try? decoder.decode(AppData.self, from: $0) }
    check(roundTrip?.logs.first?.germID == "rhino" && roundTrip?.kids.first?.colorIndex == 2, "encode then decode keeps the journal")
}

// MARK: - Levels, skill tree, milestones and goals

do {
    check(Levels.info(for: 0).number == 1 && Levels.info(for: 0).span == 150, "level 1 asks for 150 points")
    check(Levels.info(for: 150).number == 2 && Levels.info(for: 150).progress == 0, "150 points reach level 2")
    check(Levels.info(for: 3999).number == 9, "just under the last threshold is level 9")
    check(Levels.info(for: 4000).number == 10 && Levels.info(for: 9000).fraction == 1, "the last level is full")

    let kidID = UUID()
    var dodging = makeData(logs: [makeLog("rhino", from: day(1), to: day(2))])
    dodging.kidIllnesses = (0..<2).map { KidIllness(kidID: kidID, germID: "noro", startedAt: day($0), watching: false, outcome: .dodged) }
    check(RewardEngine.totalPoints(data: dodging) == 80 + 2 * RewardEngine.dodgePoints, "dodges add points")

    let night = [LogBonus(kind: .rarity, points: 80), LogBonus(kind: .nightShift, points: 50)]
    var colds = makeData(logs: (0..<5).map { makeLog("rhino", from: day($0 * 3), to: day($0 * 3 + 1)) }
                         + [makeLog("noro", from: day(20), to: day(21), bonuses: night)])
    let counts = SkillTree.counts(data: colds, catalog: catalog)
    check(counts[.airways] == 5 && counts[.gut] == 1 && counts[.night] == 1, "the tree counts germs by family and night logs")
    check(SkillTree.rank(of: .airways, count: 5) == 2, "five colds reach rank 2")
    colds.settings.wornTitle = "airways-2"
    check(SkillTree.wornTitle(data: colds, catalog: catalog) == SkillBranch.airways.titles[1], "an earned title can be worn")
    colds.logs.removeFirst()
    check(SkillTree.wornTitle(data: colds, catalog: catalog) == nil, "a title goes away with the logs that earned it")
    let capstone = SkillTree.nodes(data: colds, catalog: catalog).first { $0.id == SkillTree.capstoneID }
    check(capstone?.isUnlocked == false, "the capstone needs three strong branches")

    var fresh = makeData()
    check(Milestones.pending(data: fresh, now: day(6)) == nil, "no milestone before a week")
    check(Milestones.pending(data: fresh, now: day(8)) == 7, "a week without a germ is a milestone")
    fresh.celebratedMilestone = MilestoneMark(streakStart: day(0), days: 7)
    check(Milestones.pending(data: fresh, now: day(9)) == nil, "a milestone is celebrated once")
    check(Milestones.pending(data: fresh, now: day(15)) == 14, "the next milestone comes later")
    check(Milestones.pending(data: makeData(logs: [makeLog("rhino", from: day(1), to: nil)]), now: day(30)) == nil,
          "no milestone while sick")

    check(GoalEngine.next(data: makeData(), catalog: catalog, now: day(3))?.title == BadgeCatalog.badge(BadgeCatalog.labRat)?.title,
          "a new parent aims for the first quiz badge")
    var quizzed = makeData(logs: [makeLog("rhino", from: day(1), to: day(2))])
    quizzed.badges[BadgeCatalog.labRat] = day(1)
    let nextGoal = GoalEngine.next(data: quizzed, catalog: catalog, now: day(3))
    check(nextGoal != nil && nextGoal?.title != BadgeCatalog.badge(BadgeCatalog.labRat)?.title && (nextGoal?.target ?? 0) < 7,
          "the next goal is a title or a badge, never the run without a germ")
}

// MARK: - Couple duel and season wrapped

do {
    let season = Season.containing(day(0), firstUse: day(0))
    let duelData = makeData(logs: [makeLog("rhino", from: day(1), to: day(2)),
                                   makeLog("noro", from: day(5), to: day(6), sufferer: .partner),
                                   makeLog("rhino", from: day(9), to: day(10), sufferer: .both)])
    let duel = DuelEngine.stats(data: duelData, season: season, now: day(30))
    check(duel.me.germs == 2 && duel.partner.germs == 2, "a shared germ counts for both")
    check(duel.leader == nil, "equal points, germs and days are a tie")
    let partnerAhead = makeData(logs: [makeLog("noro", from: day(5), to: day(9), sufferer: .partner)])
    check(DuelEngine.stats(data: partnerAhead, season: season, now: day(30)).leader == .partner, "the one who suffered more leads")

    check(WrapEngine.persona(caught: 1, nights: 3, dodged: 0, longest: 2, repeats: 1, distinct: 1) == .ironParent,
          "one germ or less is the iron parent")
    check(WrapEngine.persona(caught: 5, nights: 2, dodged: 0, longest: 2, repeats: 1, distinct: 5) == .nightOwl,
          "two night logs make a night owl")
    check(WrapEngine.persona(caught: 4, nights: 0, dodged: 0, longest: 3, repeats: 1, distinct: 4) == .survivor,
          "nothing special is a survivor")
    let wrap = WrapEngine.wrap(data: duelData, catalog: catalog, season: season, now: day(30))
    check(wrap.germsCaught == 3 && wrap.families[.airways] == 2 && wrap.families[.gut] == 1, "the story counts families")
    check(wrap.topGerm?.germ.id == "rhino" && wrap.topGerm?.value == 2, "the nemesis is the most frequent germ")
    let reveal = Calendar.current.dateComponents([.year, .month, .day], from: WrapEngine.revealDate(for: season))
    check(reveal.year == 2027 && reveal.month == 6 && reveal.day == 20, "the story is announced on June 20")
}

// MARK: - Month recap

do {
    var month = makeData(logs: [makeLog("rhino", from: day(3), to: day(5)), makeLog("rhino", from: day(10), to: day(11)),
                                makeLog("noro", from: day(40), to: day(41))])
    month.quiz.doneDays = [QuizEngine.dayKey(day(4)), QuizEngine.dayKey(day(40))]
    let recap = MonthRecapEngine.recap(data: month, catalog: catalog, month: day(1), now: day(60))
    check(recap.caught == 2 && recap.daysSick == 5 && recap.labDays == 1,
          "the month recap counts its own germs, sick days and quiz days")
    check(recap.nemesis?.id == "rhino", "the month's nemesis is its most frequent germ")
    check(MonthRecapEngine.recap(data: makeData(), catalog: catalog, month: day(1), now: day(60)).isEmpty,
          "a quiet month has no recap")
}

// MARK: - Daily quiz

do {
    let quizGerms = ["alpha", "bravo", "charlie", "delta", "echo"].map { makeGerm($0, rarity: .common) }
    let bank = QuizEngine.bank(quizGerms)
    check(bank.count == 20, "each germ gives a myth, a boss and two timings")
    check(bank.allSatisfy { $0.answer >= 0 && $0.answer < $0.options.count }, "every answer is one of the options")
    check(bank.filter { $0.kind != .myth }.allSatisfy { Set($0.options).count == 3 }, "choices offer three different options")
    check(QuizEngine.bank(quizGerms).map { $0.options } == bank.map { $0.options }, "options keep their order between launches")

    let today = QuizEngine.dayKey(day(3))
    var progress = QuizProgress()
    let plan = QuizEngine.plan(progress: progress, bank: bank, day: today)
    check(plan.count == QuizEngine.questionsPerDay, "a day asks three questions")
    check(Set(plan.map { $0.germ.id }).count == plan.count, "a day never asks twice about the same germ")
    check(QuizEngine.plan(progress: progress, bank: bank, day: today).map { $0.id } == plan.map { $0.id },
          "the day's questions stay put")

    QuizEngine.start(&progress, plan: plan, day: today)
    check(QuizEngine.answer(0, to: plan[1], progress: &progress, day: today, bankSize: bank.count) == nil,
          "only the next question can be answered")
    let wrong = (plan[0].answer + 1) % plan[0].options.count
    check(QuizEngine.answer(wrong, to: plan[0], progress: &progress, day: today, bankSize: bank.count) == false,
          "a wrong answer is recorded")
    check(progress.missed == [plan[0].id], "a missed question is kept for later")
    check(QuizEngine.answer(plan[1].answer, to: plan[1], progress: &progress, day: today, bankSize: bank.count) == true,
          "a right answer is recorded")
    _ = QuizEngine.answer(plan[2].answer, to: plan[2], progress: &progress, day: today, bankSize: bank.count)
    check(progress.rightTotal == 2 && progress.doneDays == [today], "the day is done after three answers")
    check(QuizEngine.plan(progress: progress, bank: bank, day: today).map { $0.id } == plan.map { $0.id },
          "a finished day keeps its questions")

    let tomorrow = QuizEngine.dayKey(day(4))
    check(QuizEngine.plan(progress: progress, bank: bank, day: tomorrow).first?.id == plan[0].id,
          "the missed question comes back the next day")
    check(QuizEngine.streak(doneDays: progress.doneDays, now: day(3)) == 1, "today's quiz starts a streak")
    check(QuizEngine.streak(doneDays: progress.doneDays, now: day(4)) == 1, "the streak waits until the end of the next day")
    check(QuizEngine.streak(doneDays: progress.doneDays, now: day(5)) == 0, "a skipped day ends the streak")
    let sickLeave = QuizEngine.sickDays(logs: [makeLog("rhino", from: day(4), to: day(4, hour: 20))], now: day(5))
    check(QuizEngine.streak(doneDays: progress.doneDays, sickDays: sickLeave, now: day(5)) == 1,
          "a sick day pauses the streak instead of ending it")
    let partnerSick = QuizEngine.sickDays(logs: [makeLog("rhino", from: day(4), to: nil, sufferer: .partner)], now: day(5))
    check(partnerSick.isEmpty, "only the parent's own sick days count as sick leave")

    var typed = makeGerm("foxtrot", rarity: .common)
    typed.microbe = .bacterium
    typed.symptoms = [GermSymptom(icon: "eye", text: LocalizedText(en: "sign", fr: "signe"), telltale: true)]
    let richer = QuizEngine.bank(quizGerms + [typed])
    let antibiotics = richer.first { $0.id == "antibiotics-foxtrot" }
    check(richer.contains { $0.id == "microbe-foxtrot" } && antibiotics?.answer == 0,
          "a bacterium asks what is behind it, and antibiotics help")
    check(richer.contains { $0.id == "telltale-foxtrot" }, "a telltale sign becomes a question")
    check(richer.count == 24 + 3, "germs without the extra notes keep their four questions")

    var learner = makeData()
    learner.quiz = progress
    check(RewardEngine.totalPoints(data: learner) == 2 * RewardEngine.quizAnswerPoints, "right answers add points")
    learner.wrapGuesses = ["1": true, "2": false]
    check(RewardEngine.totalPoints(data: learner) == 2 * RewardEngine.quizAnswerPoints + RewardEngine.wrapGuessPoints,
          "only a right nemesis guess adds points")
    let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: day(3))?.start ?? day(3)
    let fullWeek = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }.map(QuizEngine.dayKey)
    check(RewardEngine.fullWeeks(fullWeek) == 1 && RewardEngine.fullWeeks(Array(fullWeek.dropLast())) == 0,
          "a week counts as full with all seven days")
    check(QuizEngine.longestRun(fullWeek + [QuizEngine.dayKey(day(30))]) == 7 && QuizEngine.longestRun([]) == 0,
          "the longest quiz run counts days in a row only")
    var checker = makeData()
    checker.checkIns = fullWeek + [fullWeek[0]]
    check(RewardEngine.totalPoints(data: checker) == 7 * RewardEngine.checkInPoints + RewardEngine.fullWeekPoints,
          "each day of All good counts once, and a full week adds its bonus")
    let quizCatalog = GermCatalog(germs: quizGerms, articles: [])
    check(RewardEngine.earnedBadges(data: learner, catalog: quizCatalog, now: day(3)).contains(BadgeCatalog.labRat),
          "a finished quiz earns the Lab Rat badge")
    learner.quiz.mythsRight = quizGerms.map { $0.id }
    check(!RewardEngine.earnedBadges(data: learner, catalog: quizCatalog, now: day(3)).contains(BadgeCatalog.mythBuster),
          "the Myth Buster badge counts myths, not germs")
    learner.quiz.mythsRight = quizCatalog.myths.map { $0.id }
    check(RewardEngine.earnedBadges(data: learner, catalog: quizCatalog, now: day(3)).contains(BadgeCatalog.mythBuster),
          "every myth right earns the Myth Buster badge")

    let twoMyths = [makeGerm("golf", rarity: .common, myths: 2), makeGerm("hotel", rarity: .common, myths: 2)]
    check(GermCatalog(germs: twoMyths, articles: []).myths.map { $0.id } == ["golf-1", "hotel-1", "golf-2", "hotel-2"],
          "the myths take turns: every germ's first one, then every germ's second one")
    let mythBank = QuizEngine.bank(twoMyths).filter { $0.kind == .myth }
    check(mythBank.map { $0.id } == ["myth-golf-1", "myth-golf-2", "myth-hotel-1", "myth-hotel-2"], "every myth is a quiz question")
    var busted = QuizProgress()
    QuizEngine.start(&busted, plan: [mythBank[1]], day: today)
    _ = QuizEngine.answer(mythBank[1].answer, to: mythBank[1], progress: &busted, day: today, bankSize: mythBank.count)
    check(busted.mythsRight == ["golf-2"], "a right myth answer counts that myth")
    var stale = QuizProgress()
    stale.missed = ["myth-gone", mythBank[2].id]
    check(QuizEngine.plan(progress: stale, bank: mythBank, day: tomorrow).first?.id == mythBank[2].id,
          "a missed question no longer in the bank gives way to the next missed one")

    let saved = """
    {"quiz":{"doneDays":["2026-10-04"],"rightTotal":7}}
    """
    let fromQuiz = try? JSONDecoder().decode(AppData.self, from: Data(saved.utf8))
    check(fromQuiz?.quiz.rightTotal == 7 && fromQuiz?.quiz.missed == [], "a partial quiz history loads with defaults")
}

// MARK: - Symptoms

do {
    func sign(_ name: String, tags: [String], telltale: Bool? = nil) -> GermSymptom {
        GermSymptom(icon: "circle", text: LocalizedText(en: name, fr: name), telltale: telltale, tags: tags)
    }
    var cold = makeGerm("rhino", rarity: .common)
    cold.symptoms = [sign("Runny nose", tags: ["runny_nose"]), sign("Sore throat", tags: ["sore_throat"]),
                     sign("Low fever", tags: ["fever"])]
    var strep = makeGerm("strep", rarity: .rare)
    strep.symptoms = [sign("Sudden sore throat", tags: ["sore_throat"]), sign("Fever", tags: ["fever"]),
                      sign("White patches", tags: [])]
    var coxy = makeGerm("coxy", rarity: .rare)
    coxy.symptoms = [sign("Fever", tags: ["fever"]), sign("Sore throat", tags: ["sore_throat"]),
                     sign("Rash on the palms", tags: ["rash"], telltale: true)]
    let mystery = makeGerm("mystery", rarity: .common)
    let germs = [cold, strep, coxy, mystery]

    let early = SymptomEngine.lineup(for: ["fever", "sore_throat"], in: germs)
    check(early.top.count == 3 && early.top.first?.germ.id == "rhino", "ties rank the common germ first")
    check(early.isFull && early.others.isEmpty, "every suspect covers both signs")

    let later = SymptomEngine.lineup(for: ["fever", "sore_throat", "rash"], in: germs)
    check(later.top.map { $0.germ.id } == ["coxy"], "a third sign narrows the suspects to one")
    check(later.top.first?.telltaleMatched == true, "the telltale sign is recognized")
    check(later.others.count == 2, "the partial fits stay available")

    let urgent = SymptomEngine.lineup(for: ["fever", Symptom.urgentID], in: germs)
    check(urgent.chosen == 1, "trouble breathing is never matched to a germ")
    check(SymptomEngine.lineup(for: ["itching"], in: germs).top.isEmpty, "a sign no germ has gives no suspect")

    check(SymptomEngine.clue(for: coxy, chosen: ["fever"])?.isTelltale == true, "the clue is the telltale sign when there is one")
    check(SymptomEngine.clue(for: strep, chosen: ["fever", "sore_throat"])?.text == "white patches",
          "without a telltale sign, the clue is the first sign not ticked")
    check(Symptom.ordered(["rash", "fever", "unknown"]).map { $0.id } == ["fever", "rash"], "stored signs keep the picker's order")

    let season = Season(number: 1, start: day(0), end: day(365))
    let weeks = StatsEngine.sickWeekGerms(data: makeData(logs: [makeLog("rhino", from: day(8), to: day(10))]),
                                          season: season, now: day(20))
    check(weeks == [nil, "rhino", nil], "a germ marks the week it was going on")
    var lateStart = makeData(logs: [makeLog("rhino", from: day(8), to: day(10))])
    lateStart.installedAt = day(7)
    check(StatsEngine.sickWeekGerms(data: lateStart, season: season, now: day(20)) == ["rhino", nil],
          "the weeks start when the app was installed")
    let twice = makeData(logs: [makeLog("rhino", from: day(2), to: day(4)), makeLog("noro", from: day(9), to: day(10)),
                                makeLog("rhino", from: day(15), to: day(16))])
    check(StatsEngine.nemesis(data: twice, season: season) == Nemesis(germID: "rhino", count: 2), "the germ caught twice is the nemesis")
    check(StatsEngine.nemesis(data: makeData(logs: [makeLog("noro", from: day(2), to: day(3))]), season: season) == nil,
          "one catch makes no nemesis")

    let withSigns = """
    {"logs":[{"id":"7F0C1B1E-2B58-4B67-9C1B-0B1E7D0C1A11","germID":"mystery","startedAt":0,"symptoms":["fever"]}],"hostLook":3}
    """
    let decoded = try? JSONDecoder().decode(AppData.self, from: Data(withSigns.utf8))
    check(decoded?.logs.first?.symptoms == ["fever"] && decoded?.hostLook == 3 && decoded?.partnerLook == Looks.partner,
          "symptoms and looks load, with defaults for what is missing")
}

// MARK: - Days

do {
    let kidID = UUID()
    var data = makeData(logs: [makeLog("rhino", from: day(2), to: day(4), sufferer: .both)])
    data.kids = [Kid(id: kidID, name: "Kid", colorIndex: 0)]
    var cold = KidIllness(kidID: kidID, germID: "rhino", startedAt: day(1), watching: false, outcome: .dodged)
    data.kidIllnesses = [cold]

    let third = DayEngine.entries(on: day(3), data: data, catalog: catalog, now: day(20))
    check(third.map { $0.person } == [.me, .partner, .kid(kidID)], "a day lists the parent, the partner, then the kids")
    check(third.first?.dayNumber == 2 && third.first?.length == 3, "a day knows the day of the illness and its length")
    check(third.last?.length == nil, "a kid's illness without an end has no length")
    check(DayEngine.entries(on: day(10), data: data, catalog: catalog, now: day(20)).count == 1,
          "a kid's illness without an end lasts its germ's usual length")
    check(DayEngine.entries(on: day(11), data: data, catalog: catalog, now: day(20)).isEmpty, "and stops after it")
    check(DayEngine.isGoingOn(cold, catalog: catalog, now: day(10)) && !DayEngine.isGoingOn(cold, catalog: catalog, now: day(11)),
          "a kid stays sick until the usual length runs out")

    cold.endedAt = day(5)
    data.kidIllnesses = [cold]
    let fifth = DayEngine.entries(on: day(5), data: data, catalog: catalog, now: day(20))
    check(fifth.count == 1 && fifth[0].isLastDay && fifth[0].length == 5, "the day a kid is better ends the illness")
    check(DayEngine.entries(on: day(6), data: data, catalog: catalog, now: day(20)).isEmpty, "nothing after the kid is better")
    check(!DayEngine.isGoingOn(cold, catalog: catalog, now: day(5)), "a kid marked better is not sick anymore")
    check(DayEntry(person: .me, germID: "rhino", symptoms: [], dayNumber: 1, length: nil, logID: data.logs[0].id,
                   illnessID: nil, isLastDay: false).id
          != DayEntry(person: .partner, germID: "rhino", symptoms: [], dayNumber: 1, length: nil, logID: data.logs[0].id,
                      illnessID: nil, isLastDay: false).id, "a germ shared by the couple gives two cards")

    check(DayEngine.entries(on: day(21), data: data, catalog: catalog, now: day(20)).isEmpty, "a future day is empty")
    let daysSeason = Season.containing(day(0), firstUse: day(0))
    check(DayEngine.loggedDays(in: daysSeason, data: data, catalog: catalog, now: day(20)) == 5,
          "the season counts each day someone was sick once")
    check(DayEngine.loggedDays(in: daysSeason, person: .me, data: data, catalog: catalog, now: day(20)) == 3
            && DayEngine.loggedDays(in: daysSeason, person: .kid(kidID), data: data, catalog: catalog, now: day(20)) == 5,
          "a person's count keeps only their own sick days")
    check(DayEngine.firstDay(data: data) == Calendar.current.startOfDay(for: day(0)), "the first day is the install day")
    data.logs.append(makeLog("rhino", from: day(-3), to: day(-1)))
    check(DayEngine.firstDay(data: data) == Calendar.current.startOfDay(for: day(-3)), "or an older entry")

    let unknownCatalog = GermCatalog(germs: [makeGerm("mystery", rarity: .common, lasts: nil)], articles: [])
    let mystery = KidIllness(kidID: kidID, germID: "mystery", startedAt: day(1), watching: false, outcome: .open)
    check(DayEngine.isGoingOn(mystery, catalog: unknownCatalog, now: day(7))
          && !DayEngine.isGoingOn(mystery, catalog: unknownCatalog, now: day(8)),
          "a germ without a usual length counts a week")

    let withEnd = """
    {"kidIllnesses":[{"id":"7F0C1B1E-2B58-4B67-9C1B-0B1E7D0C1A12","kidID":"7F0C1B1E-2B58-4B67-9C1B-0B1E7D0C1A13",
    "germID":"rhino","startedAt":0,"endedAt":86400},
    {"id":"7F0C1B1E-2B58-4B67-9C1B-0B1E7D0C1A14","kidID":"7F0C1B1E-2B58-4B67-9C1B-0B1E7D0C1A13","germID":"rhino","startedAt":0}]}
    """
    let ends = (try? JSONDecoder().decode(AppData.self, from: Data(withEnd.utf8)))?.kidIllnesses.map { $0.endedAt }
    check(ends?.count == 2 && ends?[0] != nil && ends?[1] == nil, "a kid's end date loads, and is empty when missing")
}

// MARK: - The run and the themes

do {
    let fresh = RunGoal(days: 0, record: 0)
    check(fresh.target == 7 && !fresh.isBest && fresh.share == 0, "a first run aims at the first milestone")
    let chasing = RunGoal(days: 12, record: 23)
    check(chasing.target == 23 && !chasing.isBest && abs(chasing.share - 12.0 / 23.0) < 0.001, "below the record, the run aims at it")
    let ahead = RunGoal(days: 24, record: 24)
    check(ahead.target == 30 && ahead.isBest, "once the record is beaten, the run aims at the next milestone")
    let top = RunGoal(days: 400, record: 400)
    check(top.target == 400 && top.share == 1, "past the last milestone, the track is full")

    let old = try? JSONDecoder().decode(AppSettings.self, from: Data("""
    {"appearance":"dark","theme":"nightShift","soundsOn":false,"checkInsOn":true,"lessonAlertsOn":true,"crewAlertsOn":true,"sideloadPass":false}
    """.utf8))
    check(old?.theme == .agar && old?.soundsOn == false, "a theme that no longer exists reads as the standard one, and the settings load")
    check(Theme.allCases.filter { $0.badgeID == nil } == [.agar], "every theme but the standard one opens with a badge")
}

// MARK: - Germ of the week

do {
    let pool = [makeGerm("a", rarity: .common), makeGerm("b", rarity: .common), makeGerm(GermCatalog.mysteryID, rarity: .common)]
    let monday = day(4)
    check(QuizEngine.germOfTheWeek(pool, now: monday)?.id == QuizEngine.germOfTheWeek(pool, now: day(10))?.id,
          "the germ of the week holds from Monday to Sunday")
    check(QuizEngine.germOfTheWeek(pool, now: monday)?.id != QuizEngine.germOfTheWeek(pool, now: day(11))?.id,
          "a new germ comes on Monday")
    check((0..<10).allSatisfy { QuizEngine.germOfTheWeek(pool, now: day(4 + 7 * $0))?.id != GermCatalog.mysteryID },
          "the mystery germ is never the germ of the week")
    let myths = GermCatalog(germs: pool, articles: []).myths
    check(QuizEngine.mythOfTheWeek(myths, germs: pool, now: monday)?.id == QuizEngine.mythOfTheWeek(myths, germs: pool, now: day(10))?.id,
          "the myth of the week holds from Monday to Sunday")
    check((0..<10).allSatisfy { week in
        let now = day(4 + 7 * week)
        return QuizEngine.mythOfTheWeek(myths, germs: pool, now: now)?.germ.id != QuizEngine.germOfTheWeek(pool, now: now)?.id
    }, "the myth of the week belongs to another germ than the germ of the week")
}

// MARK: - Photos

do {
    let kidID = UUID()
    let log = makeLog("rhino", from: day(2), to: day(4))
    var data = makeData(logs: [log])
    data.kids = [Kid(id: kidID, name: "Kid", colorIndex: 0)]
    let cold = KidIllness(kidID: kidID, germID: "rhino", startedAt: day(3), watching: false, outcome: .open)
    data.kidIllnesses = [cold]
    let linked = PatientPhoto(person: .kid(kidID), takenAt: day(3, hour: 9), logID: nil, illnessID: cold.id)
    let loose = PatientPhoto(person: .me, takenAt: day(3, hour: 10), logID: nil, illnessID: nil)
    let healthy = PatientPhoto(person: .partner, takenAt: day(3, hour: 11), logID: nil, illnessID: nil)
    let otherDay = PatientPhoto(person: .me, takenAt: day(5), logID: log.id, illnessID: nil)
    data.photos = [linked, loose, healthy, otherDay]

    let entries = DayEngine.entries(on: day(3), data: data, catalog: catalog, now: day(20))
    let photos = DayEngine.photos(on: day(3), entries: entries, data: data)
    let kidEntry = entries.first { $0.person == .kid(kidID) }
    let myEntry = entries.first { $0.person == .me }
    check(kidEntry.flatMap { photos.byEntry[$0.id] }?.map { $0.id } == [linked.id], "a photo goes on its illness's card")
    check(myEntry.flatMap { photos.byEntry[$0.id] }?.map { $0.id } == [loose.id], "a loose photo goes on the person's card")
    check(photos.others.map { $0.id } == [healthy.id], "a photo of someone not sick that day stays apart")

    let backup = Persistence.backupData(data, photos: [linked.id: Data([1, 2, 3])])
    let read = backup.flatMap { Persistence.readBackup($0) }
    check(read == nil, "a journal that skipped onboarding is not a backup")
    data.onboardingDone = true
    let again = Persistence.backupData(data, photos: [linked.id: Data([1, 2, 3])]).flatMap { Persistence.readBackup($0) }
    check(again?.data.photos.count == 4 && again?.photoFiles[linked.id] == Data([1, 2, 3]),
          "a backup carries the photos and their files")
    check(again?.data.photos.first?.person == .kid(kidID) && again?.data.photos.first?.illnessID == cold.id,
          "a photo keeps who and what it is for")

    let older = """
    {"onboardingDone":true,"logs":[]}
    """
    let fromOlder = Persistence.readBackup(Data(older.utf8))
    check(fromOlder?.data.photos.isEmpty == true && fromOlder?.photoFiles.isEmpty == true, "an older backup has no photos")
}

// MARK: - Family league

do {
    let season = Season(number: 1, start: day(0), end: day(365))
    let kid = Kid(name: "Lou", colorIndex: 0)
    var data = makeData(logs: [makeLog("rhino", from: day(2), to: day(4)), makeLog("noro", from: day(9), to: day(10)),
                               makeLog("rhino", from: day(20), to: day(20), sufferer: .partner)])
    data.partnerName = "Nathan"
    data.kids = [kid]
    var first = KidIllness(kidID: kid.id, germID: "rhino", startedAt: day(1), watching: false, outcome: .open)
    first.endedAt = day(6)
    var second = KidIllness(kidID: kid.id, germID: "noro", startedAt: day(8), watching: false, outcome: .open)
    second.endedAt = day(10)
    data.kidIllnesses = [first, second]
    let table = LeagueEngine.standings(data: data, catalog: catalog, season: season, now: day(30))
    check(table.map { $0.person } == [.partner, .me, .kid(kid.id)], "the league ranks the fewest sick days first")
    check(table.map { $0.sickDays } == [1, 5, 9], "a kid's sick days run from start to better")
    check(table.map { $0.title } == [.forceField, .frequentFlyer, .patientZero],
          "the leader is the force field and the kid who brought germs home is patient zero")
    let calm = makeData()
    var pair = calm
    pair.partnerName = "Nathan"
    check(LeagueEngine.standings(data: pair, catalog: catalog, season: season, now: day(30)).allSatisfy { $0.title == nil },
          "nobody gets a title while nobody stands apart")
    check(LeagueEngine.standings(data: calm, catalog: catalog, season: season, now: day(30)).count == 1,
          "the parent alone makes no league")
}

// MARK: - Lessons

do {
    let text = LocalizedText(en: "a", fr: "a")
    let bundled = [0, 5, 25].map { step in
        Article(id: "b\(step)", icon: "book", unlockAtAnswers: step, title: text, summary: text, paragraphs: [],
                sources: [], releasedOn: nil)
    }
    func lesson(_ id: String, _ released: String) -> FeedLesson {
        FeedLesson(id: id, icon: nil, released: released, title: text, summary: text, paragraphs: [], sources: [],
                   reviewedOn: "2026-09-30")
    }
    let merged = LessonEngine.merge(bundled: bundled, feed: [lesson("late", "2026-10-15"), lesson("early", "2026-10-08"),
                                                             lesson("b5", "2026-10-01"), lesson("bad", "soon")])
    check(merged.map { $0.id } == ["b0", "b5", "b25", "early", "late"],
          "online lessons follow the bundled ones in release order, without duplicates or bad dates")
    check(merged.suffix(2).allSatisfy { $0.needsPass } && !merged.prefix(3).contains { $0.needsPass },
          "online lessons need the Season Pass, bundled ones climb the ladder")
    check(merged.last?.reviewedOn == "2026-09-30", "an online lesson keeps its review day")

    let shelf = GermCatalog(germs: [], articles: bundled,
                            feed: [lesson("early", "2026-10-08"), lesson("late", "2026-10-15")], now: day(10))
    check(shelf.articles.map { $0.id } == ["b0", "b5", "b25", "early"], "a lesson shows from its release day")
    check(shelf.upcoming.map { $0.id } == ["late"], "a lesson waits for its release day")
    check(LessonEngine.readingOrder(shelf.articles, data: makeData(), hasPass: true, now: day(10)).map { $0.id }
            == ["early", "b0", "b5", "b25"], "with the Pass, this week's lesson leads the reading order")
    check(LessonEngine.readingOrder(shelf.articles, data: makeData(), hasPass: false, now: day(10)).map { $0.id }
            == ["b0", "b5", "b25", "early"], "without the Pass, the open lesson leads and the new one waits with the locked ones")
    var reader = makeData()
    reader.readArticles = ["b0", "early"]
    check(LessonEngine.readingOrder(shelf.articles, data: reader, hasPass: false, now: day(10)).map { $0.id }
            == ["b5", "b25", "b0", "early"], "lessons already read go last")

    if let early = shelf.articles.last, let second = shelf.articles.first(where: { $0.id == "b5" }) {
        var data = makeData()
        check(LessonEngine.isNew(early, now: day(7)) && LessonEngine.isNew(early, now: day(13)), "a lesson is new for its first 7 days")
        check(!LessonEngine.isNew(early, now: day(14)) && !LessonEngine.isNew(second, now: day(10)), "after its week, or bundled, a lesson is not new")
        check(!LessonEngine.isUnlocked(early, data: data, hasPass: false), "an online lesson waits for the Season Pass")
        check(LessonEngine.isUnlocked(early, data: data, hasPass: true), "the Season Pass opens an online lesson")
        data.quiz.rightTotal = 30
        check(!LessonEngine.isUnlocked(early, data: data, hasPass: false), "right answers do not open an online lesson")
        check(LessonEngine.isUnlocked(second, data: data, hasPass: false), "right answers open a bundled lesson")
        data.quiz.rightTotal = 0
        data.readArticles = [early.id]
        check(LessonEngine.isUnlocked(early, data: data, hasPass: false), "a lesson read once stays open")
    } else {
        check(false, "the released online lesson is in the catalog")
    }
}

// Going around: the newest recent report for the country, with only the germs the app knows.
do {
    let text = LocalizedText(en: "a", fr: "a")
    let source = GermReference(name: "FluWatch+", url: "https://www.canada.ca/fluwatch")
    func report(_ id: String, _ region: String, _ published: String, _ germs: [String]) -> GoingAroundReport {
        GoingAroundReport(id: id, region: region, week: "2026-10-01", published: published, headline: text,
                          germs: germs.map { GoingAroundGerm(germID: $0, trend: .rising, line: text) },
                          source: source, approvedOn: "2026-10-02")
    }
    let reports = [report("old", "CA", "2026-10-02", ["flu"]), report("new", "CA", "2026-10-09", ["flu", "ghost"]),
                   report("us", "US", "2026-10-09", ["flu"]), report("future", "CA", "2026-10-30", ["flu"])]
    let known: Set<String> = ["flu"]
    let shown = GoingAroundEngine.current(reports, region: "CA", known: known, now: day(10))
    check(shown?.id == "new", "the newest report already published leads")
    check(shown?.germs.map { $0.germID } == ["flu"], "a germ the app does not know is left out")
    check(GoingAroundEngine.current(reports, region: "US", known: known, now: day(10))?.id == "us", "each country has its own report")
    check(GoingAroundEngine.current(reports, region: "CA", known: known, now: day(70)) == nil, "a report over five weeks old is not shown")
    check(GoingAroundEngine.current(reports, region: "CA", known: [], now: day(10)) == nil, "a report without a known germ is not shown")
    check(GoingAroundEngine.region(for: "US") == "US" && GoingAroundEngine.region(for: "CA") == "CA",
          "a phone in Canada or the US reads its own country's report")
    check(GoingAroundEngine.region(for: "FR") == nil && GoingAroundEngine.region(for: nil) == nil,
          "a phone elsewhere gets no report")
}

// Motion: each look has its own accent and sick routine, only the cap hops at rest, germs move by shelf,
// and the fourth tap in three seconds makes a character dizzy.
do {
    let accents = (0..<8).map { Liveliness.household($0, sick: false, leads: true) }
    let routines = (0..<8).map { Liveliness.household($0, sick: true, leads: true) }
    check(Set(accents).count == 8, "each healthy look has its own accent")
    check(Set(routines).count == 8, "each sick look has its own routine")
    check(Liveliness.household(3, sick: false, leads: false) == .resting, "a healthy character that does not lead only breathes")
    for (index, accent) in accents.enumerated() {
        let highest = stride(from: 0.0, to: CharacterPose.accentCycle, by: 0.01).map { CharacterPose.at($0, mood: accent).lift }.min() ?? 0
        if index == 7 {
            check(highest < -5, "the cap hops at rest")
        } else {
            check(highest > -0.01, "look \(index) stays on the ground at rest")
        }
    }
    let rest = stride(from: 0.0, to: 7.0, by: 0.05).map { CharacterPose.at($0, mood: .resting) }
    check(rest.allSatisfy { $0.lift == 0 && $0.tilt == 0 && $0.shiftX == 0 }, "resting is breath only")
    check(Liveliness.germ(.airways) == .floating && Liveliness.germ(.skin) == .creeping
          && Liveliness.germ(.gut) == .jiggling && Liveliness.germ(.other) == .jiggling, "germs move by shelf")
    let start = day(0)
    var streak = TapStreak()
    let firstThree = (0..<3).map { streak.tap(at: start.addingTimeInterval(Double($0) * 0.4), usual: .giggle) }
    check(firstThree == [.giggle, .giggle, .giggle], "the first three taps giggle")
    check(streak.tap(at: start.addingTimeInterval(1.2), usual: .giggle) == .dizzy, "the fourth tap within three seconds makes it dizzy")
    var slow = TapStreak()
    let spread = (0..<4).map { slow.tap(at: start.addingTimeInterval(Double($0) * 1.5), usual: .squish) }
    check(!spread.contains(.dizzy), "taps spread over more than three seconds never make it dizzy")
    check(CharacterPose.at(0, mood: .resting, reaction: .squish, elapsed: 0.1).stretchY < 0.9, "a squish flattens the germ")
    check(CharacterPose.at(0, mood: .resting, reaction: .squish, elapsed: 0.7) == CharacterPose.at(0, mood: .resting),
          "a reaction ends after its duration")
}


// The Today mascot: its faces over time, the night shush, the tickle and its pacifier, the rub and the pull.
do {
    func near(_ value: Double?, _ target: Double) -> Bool {
        value.map { abs($0 - target) < 0.000_001 } ?? false
    }
    check(CharacterPose.at(0, mood: .resting, reaction: .sneeze, elapsed: 0.5).stretchY > 1.04, "a sneeze breathes in first")
    check(CharacterPose.at(0, mood: .resting, reaction: .sneeze, elapsed: 0.62).stretchY < 0.9, "then it sneezes forward")
    check(CharacterPose.at(0, mood: .resting, reaction: .sneeze, elapsed: 1.1) == CharacterPose.at(0, mood: .resting),
          "a sneeze ends after its duration")

    var mind = MascotMind()
    check(mind.face(at: 0, lean: 0) == .asleep, "the mascot starts asleep")
    check(mind.touch(at: 10, night: false) == .woke, "a touch in the day wakes it")
    check(mind.face(at: 10.2, lean: 0) == .grumpy, "it wakes up grumpy")
    check(mind.face(at: 11, lean: 0) == .awake, "then it is awake")
    check(mind.face(at: 11, lean: 0.5) == .lookRight && mind.face(at: 11, lean: -0.5) == .lookLeft,
          "it looks toward the side the phone leans")
    check(mind.face(at: 16.5, lean: 0) == .drowsy, "it gets drowsy before it dozes off")
    check(mind.face(at: 16.9, lean: 0) == .asleep, "and it falls asleep about 7 seconds after the last touch")

    var night = MascotMind()
    check(night.touch(at: 0, night: true) == .shushed, "at night the first touch only gets a shush")
    check(night.face(at: 1, lean: 0) == .grumpy && !night.isAwake(at: 1), "the shush opens one eye without waking it")
    check(night.touch(at: 1.5, night: true) == .woke, "a second touch during the shush wakes it")
    check(night.face(at: 3, lean: 0) == .awake, "once woken at night, it plays as in the day")

    var tickled = MascotMind()
    _ = tickled.touch(at: 0, night: false)
    tickled.startTickle(at: 0)
    check(tickled.face(at: 1, lean: 0) == .giggle, "a tickle giggles")
    check(!tickled.popsPacifier(at: 1.9) && tickled.popsPacifier(at: 2.0), "the pacifier flies after two seconds")
    tickled.popPacifier(at: 2.0)
    check(!tickled.popsPacifier(at: 2.5), "only once per tickle")
    check(tickled.face(at: 2.5, lean: 0) == .laugh, "it laughs while the tickle goes on")
    check(tickled.isAwake(at: 30), "it stays awake during a long tickle")
    tickled.endTickle(at: 3)
    check(tickled.face(at: 4, lean: 0) == .gasp, "without its pacifier it gasps")
    check(near(tickled.pacifierFlight(at: 2.4), 0.5) && tickled.pacifierFlight(at: 3) == nil, "the pacifier lands after 0.8 s")
    tickled.returnPacifier(at: 5)
    check(!tickled.pacifierIsOut(at: 5) && near(tickled.pacifierReturn(at: 5.15), 0.5), "a touch sends it back in 0.3 s")
    check(tickled.face(at: 5.4, lean: 0) == .giggle, "it giggles with its pacifier back")
    var forgot = MascotMind()
    _ = forgot.touch(at: 0, night: false)
    forgot.popPacifier(at: 0)
    check(forgot.pacifierIsOut(at: 19.9) && !forgot.pacifierIsOut(at: 20), "the pacifier comes back by itself after 20 s")
    check(forgot.isAwake(at: 25), "it stays awake a while after the pacifier is back")

    var sneezy = MascotMind()
    _ = sneezy.touch(at: 0, night: false)
    sneezy.sneeze(at: 2)
    check(sneezy.face(at: 2.3, lean: 0) == .drowsy && sneezy.face(at: 2.7, lean: 0) == .sneeze, "a.. a.. then the sneeze")

    var rub = RubDetector()
    var rubbed = false
    for (index, x) in [0.0, 20, 40, 20, 0, 20, 40, 20, 0].enumerated() {
        rubbed = rub.track(x: x, at: Double(index) * 0.1) || rubbed
    }
    check(rubbed, "three quick turns back and forth make a rub")
    var slow = RubDetector()
    var slowRub = false
    for (index, x) in [0.0, 20, 40, 20, 0, 20, 40, 20, 0].enumerated() {
        slowRub = slow.track(x: x, at: Double(index) * 0.5) || slowRub
    }
    check(!slowRub, "slow turns are not a rub")
    var drag = RubDetector()
    check(![0.0, 30, 60, 90, 120].map { drag.track(x: $0, at: 0) }.contains(true), "a drag one way is not a rub")

    let up = MascotMind.stretch(dx: 0, dy: -200, side: 200)
    check(up.scaleY > 1.3 && up.scaleX < 0.9 && up.tilt == 0, "a pull up stretches it tall")
    check(MascotMind.stretch(dx: 300, dy: -10, side: 200).tilt == 30, "a pull to the side leans it 30 degrees at most")
    check(MascotMind.stretch(dx: 0, dy: 100, side: 200).scaleY < 1, "a pull down squashes it")

    var found = makeData()
    found.mascotTricks = MascotTrick.allCases.dropLast().map { $0.rawValue }
    check(!RewardEngine.earnedBadges(data: found, catalog: catalog, now: day(1)).contains(BadgeCatalog.ticklish),
          "nine tricks are not enough for Ticklish")
    check(BadgeProgress.counts(data: found, catalog: catalog, now: day(1))[BadgeCatalog.ticklish]
          == BadgeCount(progress: 9, target: 10), "Ticklish counts the tricks found")
    found.mascotTricks.append(MascotTrick.shush.rawValue)
    check(RewardEngine.earnedBadges(data: found, catalog: catalog, now: day(1)).contains(BadgeCatalog.ticklish),
          "all ten tricks earn Ticklish")
    let ticklish = BadgeCatalog.badge(BadgeCatalog.ticklish)
    check(ticklish?.shown(earned: false).title != ticklish?.title && ticklish?.shown(earned: true).title == ticklish?.title,
          "Ticklish keeps its name secret until it is earned")
}

// Characters: three looks are free, the Season Pass opens the others, and each look has a sick routine.
do {
    check(Looks.order.count == Looks.count && Set(Looks.order) == Set(0..<Looks.count), "the picker lists every look once")
    check(Looks.free == [0, Looks.host, Looks.partner], "the free looks are the ones handed out first")
    check(Looks.order.prefix(Looks.free.count).allSatisfy { Looks.free.contains($0) }, "the free looks come first in the picker")
    check(!Looks.isOpen(10, hasPass: false) && Looks.isOpen(10, hasPass: true), "a Pass look opens with the Season Pass")
    check(Looks.isOpen(Looks.host + Looks.count, hasPass: false), "a look number past the count wraps around")
    check((0..<Looks.count).allSatisfy { Liveliness.household($0, sick: true, leads: false) != .resting },
          "every look has a sick routine")
    check(Looks.shown(hidden: [6, 10], hasPass: false) == Looks.order.filter { $0 != 6 && $0 != 10 },
          "hidden looks leave the choices")
    check(Looks.shown(hidden: Looks.free, hasPass: false) == Looks.order,
          "with every open look hidden, all of them come back")
    check(Looks.shown(hidden: Looks.free, hasPass: true) == Looks.order.filter { !Looks.free.contains($0) },
          "with the Season Pass, the Pass looks are enough")
    check(!Looks.canHide(0, hidden: [6, 7], hasPass: false) && Looks.canHide(10, hidden: [6, 7], hasPass: false),
          "the last look that can be picked stays shown")
    let hiddenSettings = try? JSONDecoder().decode(AppSettings.self, from: Data(#"{"hiddenLooks":[9,12]}"#.utf8))
    check(hiddenSettings?.hiddenLooks == [9, 12] && hiddenSettings?.theme == .agar, "hidden looks are saved with the settings")
}

// The Season Pass offer: each door has its own line, and the trial reminder goes out two days before the payment.
do {
    let doors = PassReason.allCases
    check(Set(doors.map { $0.detail }).count == doors.count, "each door to the Season Pass has its own line")
    check(doors.allSatisfy { !$0.detail.isEmpty && !$0.gain.isEmpty }, "each door says what it gives")
    check(TrialPlan(days: 7).reminderDay == 5, "a 7-day trial reminds on day 5")
    check(TrialPlan(days: 14).reminderDay == 12, "a 14-day trial reminds on day 12")
    check(TrialPlan(days: 3).reminderDay == nil, "a 3-day trial is too short for a reminder")
    let end = day(7)
    check(TrialPlan.reminderDate(endsAt: end, now: day(0)) == day(5), "the reminder is two days before the trial ends")
    check(TrialPlan.reminderDate(endsAt: end, now: day(6)) == nil, "no reminder once its moment has passed")
}

// MARK: - Lesson file checks

do {
    let checked = day(0)
    check(LessonEngine.isCheckDue(lastCheck: nil, now: checked), "a file never checked is due")
    check(!LessonEngine.isCheckDue(lastCheck: checked, now: checked.addingTimeInterval(1800)), "half an hour later is too soon")
    check(LessonEngine.isCheckDue(lastCheck: checked, now: checked.addingTimeInterval(3600)), "an hour later is due")
    check(LessonEngine.isCheckDue(lastCheck: checked, now: checked.addingTimeInterval(-60)), "a clock set back is due")
}

// MARK: - Source links

do {
    check(GermReference(name: "Source", url: "https://example.org/page").link != nil, "an https source opens")
    check(GermReference(name: "Source", url: "http://example.org/page").link == nil, "a plain http source does not open")
    check(GermReference(name: "Source", url: "tel:911").link == nil, "a source cannot start a call")
}

// MARK: - Person file

do {
    let kid = Kid(name: "Lou", colorIndex: 0)
    let catalog = GermCatalog(germs: [makeGerm("noro", rarity: .common, lasts: 3), makeGerm("rhino", rarity: .common, lasts: 10)],
                              articles: [])
    var data = makeData(illnesses: [
        KidIllness(kidID: kid.id, germID: "noro", startedAt: day(0), watching: false, outcome: .caught),
        KidIllness(kidID: kid.id, germID: "rhino", startedAt: day(10), watching: false, outcome: .dodged, endedAt: day(14)),
        KidIllness(kidID: kid.id, germID: "rhino", startedAt: day(30), watching: false, outcome: .open),
    ])
    data.kids = [kid]
    let now = day(31)
    let list = PersonFileEngine.illnesses(of: .kid(kid.id), data: data, catalog: catalog, now: now)
    check(list.map { $0.germID } == ["rhino", "rhino", "noro"], "a person's illnesses come newest first")
    check(list[0].goingOn && list[0].days == 2, "an illness going on counts its days up to today")
    check(list[1].days == 5 && list[1].dodged, "an illness marked over counts to its last day, and keeps its dodge")
    if case .gotYou? = list[2].note {} else { check(false, "a kid's illness the parent caught says it got them") }
    check(list[2].days == 3, "a kid's illness with no end lasts its germ's usual length")
    let season = Season(number: 1, start: Calendar.current.startOfDay(for: day(0)), end: day(365))
    let sick = PersonFileEngine.sickDays(list, in: season)
    check(sick.count == 10, "the season counts each sick day once")
    let months = PersonFileEngine.monthTotals(sick, season: season)
    check(months[0] == 9 && months[1] == 1, "sick days fall in their month of the season")
    check(PersonFileEngine.comingBack(list).map { $0.germID } == ["rhino", "noro"], "the germ that came most often comes first")
    check(PersonFileEngine.usualDays(list) == 4, "the usual length leaves out the illness going on")

    var parent = data
    parent.logs = [SickLog(germID: "rhino", source: .kid(kid.id), severity: 3, startedAt: day(12), endedAt: day(15),
                           points: 80, bonuses: [], sufferer: .me, kidIllnessID: nil)]
    let mine = PersonFileEngine.illnesses(of: .me, data: parent, catalog: catalog, now: now)
    if case .from(.kid(kid.id))? = mine.first?.note {} else { check(false, "a parent's germ says which kid it came from") }
    check(mine.first?.severity == 3 && list.allSatisfy { $0.severity == nil },
          "a parent's germ keeps how bad it was, a kid's illness has no severity")
    check(PersonFileEngine.illnesses(of: .partner, data: parent, catalog: catalog, now: now).isEmpty,
          "the partner's file leaves out the parent's germs")
}

// MARK: - Day one

do {
    let kid = Kid(name: "Lou", colorIndex: 0)
    let fresh = makeData()
    check(StreakMath.isFirstDay(data: fresh, now: day(0, hour: 20)), "the install day with nothing logged is day 1")
    check(!StreakMath.isFirstDay(data: fresh, now: day(1)), "the next day counts a germ-free day again")
    let withKid = makeData(illnesses: [KidIllness(kidID: kid.id, germID: "noro", startedAt: day(0), watching: false, outcome: .open)])
    check(!StreakMath.isFirstDay(data: withKid, now: day(0)), "a logged kid illness ends day 1")

    let calendar = Calendar.current
    check(PersonFileEngine.trackedSince(data: fresh) == calendar.startOfDay(for: day(0)), "the journal covers the days since install")
    let backdated = makeData(logs: [makeLog("rhino", from: day(-12), to: day(-9))])
    check(PersonFileEngine.trackedSince(data: backdated) == calendar.startOfDay(for: day(-12)),
          "an illness logged after the fact moves the start back")
    check(PersonFileEngine.doctorSince(data: fresh, now: day(0)) == calendar.startOfDay(for: day(0)),
          "the doctor's page starts at install when that is within six months")
    var old = makeData()
    old.installedAt = day(-400)
    let sixMonths = calendar.date(byAdding: .month, value: -6, to: day(0)) ?? day(0)
    check(PersonFileEngine.doctorSince(data: old, now: day(0)) == sixMonths, "the doctor's page goes back six months at most")

    let season = Season(number: 1, start: calendar.startOfDay(for: day(-30)), end: day(335))
    check(StatsEngine.isUntouched(data: fresh, season: season), "a season with nothing logged waits for its first germ")
    check(!StatsEngine.isUntouched(data: withKid, season: season), "a kid's illness counts as the season's first germ")
    check(!StatsEngine.isUntouched(data: backdated, season: season), "a parent's germ counts as the season's first germ")

    let september = Season(number: 1, start: calendar.date(from: DateComponents(year: 2026, month: 9, day: 1)) ?? day(0),
                           end: calendar.date(from: DateComponents(year: 2027, month: 9, day: 1)) ?? day(365))
    let november = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23)) ?? day(0)
    check(StatsEngine.monthsBeforeJournal(since: november, season: september) == 2,
          "September and October come before a journal begun in November")
    check(StatsEngine.monthsBeforeJournal(since: september.start, season: september) == 0,
          "a journal begun on the first day leaves no month before it")
}

if failures == 0 {
    print("logic tests: all checks passed")
} else {
    print("logic tests: \(failures) check(s) failed")
}
exit(failures == 0 ? 0 : 1)

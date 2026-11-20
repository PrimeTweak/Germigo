import Foundation

// Logic checks for the journal rules, streaks, badges, stats and journal decoding.
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

func makeGerm(_ id: String, rarity: Rarity, family: GermFamily = .airways) -> Germ {
    let text = LocalizedText(en: id, fr: id)
    return Germ(id: id, number: 1, name: id, illness: text, phrase: text, scientific: text, rarity: rarity,
                tintLight: "#FFFFFF", tintDeep: "#000000", quickPick: true, incubationMinHours: 24,
                incubationMaxHours: 72, showsUp: text, lasts: text, facts: [], tips: [], doctor: text,
                deepDive: [], sources: [], family: family, lastsUpToDays: 10, doctorLead: text, doctorSigns: [text],
                doctorNote: nil, boss: GermBoss(attack: text, weakness: text),
                myth: GermMyth(claim: text, isTrue: true, explanation: text), kidSource: nil)
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
    check(StreakMath.lastRun(data: sick, now: day(13)) == 4, "last run ends when the active germ starts")
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

    check(GoalEngine.next(data: makeData(), catalog: catalog, now: day(3))?.target == 7, "a new parent aims for a week first")
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
    let quizCatalog = GermCatalog(germs: quizGerms, articles: [])
    check(RewardEngine.earnedBadges(data: learner, catalog: quizCatalog, now: day(3)).contains(BadgeCatalog.labRat),
          "a finished quiz earns the Lab Rat badge")
    learner.quiz.mythsRight = quizGerms.map { $0.id }
    check(RewardEngine.earnedBadges(data: learner, catalog: quizCatalog, now: day(3)).contains(BadgeCatalog.mythBuster),
          "every myth right earns the Myth Buster badge")

    let saved = """
    {"quiz":{"doneDays":["2026-10-04"],"rightTotal":7}}
    """
    let fromQuiz = try? JSONDecoder().decode(AppData.self, from: Data(saved.utf8))
    check(fromQuiz?.quiz.rightTotal == 7 && fromQuiz?.quiz.missed == [], "a partial quiz history loads with defaults")
}

if failures == 0 {
    print("logic tests: all checks passed")
} else {
    print("logic tests: \(failures) check(s) failed")
}
exit(failures == 0 ? 0 : 1)

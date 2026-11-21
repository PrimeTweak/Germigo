import Foundation

enum QuizKind: String, Codable {
    case myth
    case whoAmI
    case showsUp
    case lasts
    case microbe
    case antibiotics
    case telltale
    case weakness
}

/// One quiz question, built from a germ's health notes.
struct QuizQuestion: Identifiable, Hashable {
    let id: String
    let kind: QuizKind
    let germ: Germ
    let prompt: String
    let options: [String]
    let answer: Int
}

/// A generator that gives the same sequence for the same seed, so a day's quiz stays put.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

/// Builds the daily quiz from the germ notes and keeps its history.
enum QuizEngine {
    static let questionsPerDay = 3
    /// Right answers needed for each new lesson.
    static let answersPerLesson = 5

    static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04ld-%02ld-%02ld", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// A stable number for a text, unlike `hashValue`, which changes at every launch.
    static func seed(_ text: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in text.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return hash
    }

    /// Every question the notes allow: a myth and a boss per germ, the timings given in numbers,
    /// the microbe behind it, and the signs and weaknesses flagged as naming the germ alone.
    static func bank(_ germs: [Germ]) -> [QuizQuestion] {
        var questions: [QuizQuestion] = []
        for germ in germs {
            questions.append(QuizQuestion(id: "myth-" + germ.id, kind: .myth, germ: germ, prompt: germ.myth.claim.value,
                                          options: [tr("Myth"), tr("Fact")], answer: germ.myth.isTrue ? 1 : 0))
            if let question = choice(id: "who-" + germ.id, kind: .whoAmI, germ: germ, prompt: germ.boss.attack.value,
                                     pool: germs, text: { $0.illness.value }) {
                questions.append(question)
            }
            if germ.incubationMinHours != nil,
               let question = choice(id: "shows-" + germ.id, kind: .showsUp, germ: germ,
                                     prompt: tr("%@: when do symptoms usually start?", germ.illness.value),
                                     pool: germs.filter { $0.incubationMinHours != nil }, text: { $0.showsUp.value }) {
                questions.append(question)
            }
            if germ.lastsUpToDays != nil,
               let question = choice(id: "lasts-" + germ.id, kind: .lasts, germ: germ,
                                     prompt: tr("%@: how long does it usually last?", germ.illness.value),
                                     pool: germs.filter { $0.lastsUpToDays != nil }, text: { $0.lasts.value }) {
                questions.append(question)
            }
            if let microbe = germ.microbe {
                let kinds = Microbe.allCases
                questions.append(QuizQuestion(id: "microbe-" + germ.id, kind: .microbe, germ: germ,
                                              prompt: tr("%@: what's behind it?", germ.illness.value),
                                              options: kinds.map { $0.label }, answer: kinds.firstIndex(of: microbe) ?? 0))
                questions.append(QuizQuestion(id: "antibiotics-" + germ.id, kind: .antibiotics, germ: germ,
                                              prompt: tr("Do antibiotics help against %@?", germ.phrase.value),
                                              options: [tr("Yes"), tr("No")], answer: microbe.antibioticsHelp ? 0 : 1))
            }
            if let sign = germ.symptoms.first(where: { $0.telltale == true }),
               let question = choice(id: "telltale-" + germ.id, kind: .telltale, germ: germ,
                                     prompt: tr("Telltale sign: %@", sign.text.value), pool: germs, text: { $0.illness.value }) {
                questions.append(question)
            }
            if germ.boss.weaknessQuiz == true,
               let question = choice(id: "weakness-" + germ.id, kind: .weakness, germ: germ,
                                     prompt: tr("Its weakness: %@", germ.boss.weakness.value), pool: germs,
                                     text: { $0.illness.value }) {
                questions.append(question)
            }
        }
        return questions
    }

    /// Three options: the germ's own answer and two from other germs, preferring its family.
    private static func choice(id: String, kind: QuizKind, germ: Germ, prompt: String, pool: [Germ],
                               text: (Germ) -> String) -> QuizQuestion? {
        let right = text(germ)
        var generator = SeededGenerator(seed: seed(id))
        var seen: Set<String> = [right]
        var others: [String] = []
        let candidates = pool.filter { $0.id != germ.id }.shuffled(using: &generator)
        let ordered = candidates.filter { $0.family == germ.family } + candidates.filter { $0.family != germ.family }
        for other in ordered where others.count < 2 {
            let value = text(other)
            if seen.insert(value).inserted {
                others.append(value)
            }
        }
        guard others.count == 2 else { return nil }
        let options = ([right] + others).shuffled(using: &generator)
        guard let answer = options.firstIndex(of: right) else { return nil }
        return QuizQuestion(id: id, kind: kind, germ: germ, prompt: prompt, options: options, answer: answer)
    }

    /// The day's questions: the round already started, or one missed question then fresh ones of different kinds.
    static func plan(progress: QuizProgress, bank: [QuizQuestion], day: String) -> [QuizQuestion] {
        if let round = progress.round, round.day == day {
            return round.questionIDs.compactMap { id in bank.first { $0.id == id } }
        }
        var picked: [QuizQuestion] = []
        if let id = progress.missed.first, let question = bank.first(where: { $0.id == id }) {
            picked.append(question)
        }
        var fresh = bank.filter { question in
            !progress.asked.contains(question.id) && !picked.contains { $0.id == question.id }
        }
        if fresh.count < questionsPerDay - picked.count {
            fresh = bank.filter { question in !picked.contains { $0.id == question.id } }
        }
        var generator = SeededGenerator(seed: seed(day))
        fresh.shuffle(using: &generator)
        for question in fresh where picked.count < questionsPerDay {
            if !picked.contains(where: { $0.kind == question.kind || $0.germ.id == question.germ.id }) {
                picked.append(question)
            }
        }
        for question in fresh where picked.count < questionsPerDay {
            if !picked.contains(where: { $0.id == question.id || $0.germ.id == question.germ.id }) {
                picked.append(question)
            }
        }
        return picked
    }

    static func start(_ progress: inout QuizProgress, plan: [QuizQuestion], day: String) {
        guard progress.round?.day != day, !plan.isEmpty else { return }
        progress.round = QuizRound(day: day, questionIDs: plan.map { $0.id }, answers: [])
    }

    /// Records the answer to the round's next question; nil when it is not that question.
    static func answer(_ choice: Int, to question: QuizQuestion, progress: inout QuizProgress, day: String,
                       bankSize: Int) -> Bool? {
        guard var round = progress.round, round.day == day, round.answers.count < round.questionIDs.count,
              round.questionIDs[round.answers.count] == question.id else { return nil }
        let right = choice == question.answer
        round.answers.append(choice)
        progress.round = round
        if progress.asked.count >= bankSize {
            progress.asked.removeAll()
        }
        if !progress.asked.contains(question.id) {
            progress.asked.append(question.id)
        }
        progress.missed.removeAll { $0 == question.id }
        if right {
            progress.rightTotal += 1
            if !progress.rightIDs.contains(question.id) {
                progress.rightIDs.append(question.id)
            }
            if question.kind == .myth && !progress.mythsRight.contains(question.germ.id) {
                progress.mythsRight.append(question.germ.id)
            }
        } else {
            progress.missed.append(question.id)
        }
        if round.answers.count == round.questionIDs.count && !progress.doneDays.contains(day) {
            progress.doneDays.append(day)
        }
        return right
    }

    /// Days in a row with the quiz done, counting yesterday's run until today's quiz is done.
    /// Sick days without a quiz are sick leave: they neither count nor break the run.
    static func streak(doneDays: [String], sickDays: Set<String> = [], now: Date) -> Int {
        let done = Set(doneDays)
        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: now)
        if !done.contains(dayKey(cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while done.contains(dayKey(cursor)) || sickDays.contains(dayKey(cursor)) {
            if done.contains(dayKey(cursor)) {
                count += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// Germs whose every question was answered right at least once.
    static func studied(bank: [QuizQuestion], rightIDs: [String]) -> Set<String> {
        let right = Set(rightIDs)
        var questions: [String: [String]] = [:]
        for question in bank {
            questions[question.germ.id, default: []].append(question.id)
        }
        return Set(questions.filter { $0.value.allSatisfy(right.contains) }.keys)
    }

    /// Every day the parent spent sick, as day keys.
    static func sickDays(logs: [SickLog], now: Date) -> Set<String> {
        let calendar = Calendar.current
        var days = Set<String>()
        for log in logs where log.sufferer.includesMe {
            var cursor = calendar.startOfDay(for: log.startedAt)
            let last = calendar.startOfDay(for: log.endedAt ?? now)
            while cursor <= last {
                days.insert(dayKey(cursor))
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
        }
        return days
    }

    /// The germ shown on a given day, in turn through the album.
    /// Weeks counted from a Monday, so the count turns every Monday.
    static func weekIndex(_ now: Date) -> Int {
        let calendar = Calendar.current
        let monday = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? Date(timeIntervalSince1970: 0)
        let days = calendar.dateComponents([.day], from: monday, to: calendar.startOfDay(for: now)).day ?? 0
        return Int((Double(days) / 7).rounded(.down))
    }

    /// The germ that opens the Lab's collection for the week; the mystery germ never does.
    static func germOfTheWeek(_ germs: [Germ], now: Date) -> Germ? {
        let pool = germs.filter { $0.id != GermCatalog.mysteryID }
        guard !pool.isEmpty else { return nil }
        let index = weekIndex(now) % pool.count
        return pool[(index + pool.count) % pool.count]
    }
}

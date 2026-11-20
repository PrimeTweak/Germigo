import Foundation

enum QuizKind: String, Codable {
    case myth
    case whoAmI
    case showsUp
    case lasts
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

    /// Every question the notes allow: a myth and a boss per germ, plus the timings the notes give in numbers.
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
    static func streak(doneDays: [String], now: Date) -> Int {
        let done = Set(doneDays)
        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: now)
        if !done.contains(dayKey(cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while done.contains(dayKey(cursor)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// The germ shown on a given day, in turn through the album.
    static func germOfTheDay(_ germs: [Germ], now: Date) -> Germ? {
        guard !germs.isEmpty else { return nil }
        let index = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        return germs[index % germs.count]
    }
}

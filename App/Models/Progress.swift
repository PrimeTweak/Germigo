import Foundation

struct Badge: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: UInt32
    /// A secret badge shows neither its name nor its symbol until it is earned.
    var secret = false

    /// What a locked secret badge shows: only where to look.
    func shown(earned: Bool) -> Badge {
        guard secret, !earned else { return self }
        return Badge(id: id, title: tr("Secret badge"), detail: tr("Hidden somewhere on Today."), symbol: "questionmark",
                     tint: tint, secret: true)
    }
}

enum BadgeCatalog {
    static let patientOne = "patient_one"
    static let nightShift = "night_shift"
    static let tagTeam = "tag_team"
    static let dodger = "dodger"
    static let ironParent = "iron_parent"
    static let labRat = "lab_rat"
    static let mythBuster = "myth_buster"
    static let professor = "daycare_professor"
    static let ticklish = "ticklish"

    static var all: [Badge] {
        [
            Badge(id: patientOne, title: tr("Patient One"), detail: tr("Logged your first germ"), symbol: "1.circle.fill", tint: Swatch.coral),
            Badge(id: nightShift, title: tr("Night Shift"), detail: tr("Logged a germ between 1 and 5 AM"), symbol: "moon.fill", tint: Swatch.lilac),
            Badge(id: tagTeam, title: tr("Tag Team"), detail: tr("Both parents sick at the same time"), symbol: "person.2.fill", tint: Swatch.pink),
            Badge(id: "boomerang", title: tr("Boomerang"), detail: tr("Same germ twice within 30 days"), symbol: "arrow.uturn.backward.circle.fill", tint: Swatch.mint),
            Badge(id: "rough_month", title: tr("Rough Month"), detail: tr("Three germs in one month"), symbol: "calendar", tint: Swatch.tangerine),
            Badge(id: "speedrun", title: tr("Speedrun"), detail: tr("Back on your feet in a day"), symbol: "hare.fill", tint: Swatch.sky),
            Badge(id: "marathon", title: tr("Marathon"), detail: tr("One germ, ten days or more"), symbol: "tortoise.fill", tint: Swatch.slate),
            Badge(id: dodger, title: tr("Dodger"), detail: tr("Dodged three incoming germs"), symbol: "figure.run", tint: Swatch.azure),
            Badge(id: "collector", title: tr("Collector"), detail: tr("Five different germs caught"), symbol: "square.stack.3d.up.fill", tint: Swatch.grass),
            Badge(id: "half_album", title: tr("Half Album"), detail: tr("Twelve different germs caught"), symbol: "circle.lefthalf.filled", tint: Swatch.gold),
            Badge(id: "full_album", title: tr("Full Album"), detail: tr("Every germ caught"), symbol: "checkmark.seal.fill", tint: Swatch.violet),
            Badge(id: ironParent, title: tr("Iron Parent"), detail: tr("Thirty days without a germ"), symbol: "shield.fill", tint: Swatch.green),
            Badge(id: labRat, title: tr("Lab Rat"), detail: tr("Finished your first daily quiz"), symbol: "flask.fill", tint: Swatch.limeInk),
            Badge(id: mythBuster, title: tr("Myth Buster"), detail: tr("Got every myth right"), symbol: "checkmark.bubble.fill", tint: Swatch.grape),
            Badge(id: professor, title: tr("Daycare Professor"), detail: tr("Read every lesson"), symbol: "graduationcap.fill", tint: Swatch.gold),
            Badge(id: ticklish, title: tr("Ticklish"), detail: tr("Found every trick of the napping germ"), symbol: "hand.tap.fill",
                  tint: Swatch.iris, secret: true)
        ]
    }

    static func badge(_ id: String) -> Badge? {
        all.first { $0.id == id }
    }
}

struct LevelInfo: Hashable {
    let number: Int
    let title: String
    let progress: Int
    let span: Int

    var fraction: Double { span == 0 ? 0 : Double(progress) / Double(span) }
}

/// What each level unlocks: a sticker, the first one from the start.
enum LevelRewards {
    static let stickers = ["heart", "tissue", "tea", "cushion", "soup", "thermometer", "magnet", "kit", "medal", "crown"]

    static func asset(_ level: Int) -> String? {
        stickers.indices.contains(level - 1) ? "sticker-" + stickers[level - 1] : nil
    }

    static func name(_ level: Int) -> String {
        switch level {
        case 1: return tr("Heart sticker")
        case 2: return tr("Tissue box sticker")
        case 3: return tr("Tea sticker")
        case 4: return tr("Cushion sticker")
        case 5: return tr("Soup sticker")
        case 6: return tr("Thermometer sticker")
        case 7: return tr("Magnet sticker")
        case 8: return tr("Survival kit sticker")
        case 9: return tr("Medal sticker")
        default: return tr("Crown sticker")
        }
    }
}

/// The stickers beyond the levels: full weeks of "All good", and a week of quizzes in a row.
enum StickerBook {
    static let weeks: [(count: Int, sticker: String)] = [(1, "sun"), (4, "rainbow"), (10, "clover")]
    static let quizSticker = "flask"
    static let quizRun = 7

    /// Where a sticker lands when it is put on the couch, in the couch scene's points (320 by 166).
    static let couchSlots: [(x: Double, y: Double)] = [
        (296, 146), (26, 146), (282, 74), (160, 150), (254, 20), (84, 150), (236, 150), (122, 22)
    ]

    /// Every sticker in the book's order: the levels', then the weeks', then the quiz's.
    static var all: [String] {
        LevelRewards.stickers + weeks.map { $0.sticker } + [quizSticker]
    }

    static func name(_ sticker: String) -> String {
        if let index = LevelRewards.stickers.firstIndex(of: sticker) { return LevelRewards.name(index + 1) }
        switch sticker {
        case "sun": return tr("Sun sticker")
        case "rainbow": return tr("Rainbow sticker")
        case "clover": return tr("Clover sticker")
        default: return tr("Lab flask sticker")
        }
    }

    /// How a sticker is earned, in a few words.
    static func how(_ sticker: String) -> String {
        if let index = LevelRewards.stickers.firstIndex(of: sticker) { return tr("Level %lld", index + 1) }
        if let week = weeks.first(where: { $0.sticker == sticker }) {
            return trCount(week.count, one: "%lld full week", other: "%lld full weeks")
        }
        return trCount(quizRun, one: "Quiz, %lld day in a row", other: "Quiz, %lld days in a row")
    }
}

enum Levels {
    /// Points needed for each level: the first ones come within weeks, the last takes a hard season.
    static let thresholds = [0, 150, 350, 600, 900, 1300, 1800, 2400, 3100, 4000]

    static func info(for points: Int) -> LevelInfo {
        let titles = [
            tr("Fresh Host"), tr("Tissue Tester"), tr("Sniffle Scout"), tr("Couch Captain"),
            tr("Soup Sommelier"), tr("Fever Veteran"), tr("Germ Magnet"), tr("Outbreak Survivor"),
            tr("Immune Legend"), tr("Patient Infinity")
        ]
        let reached = thresholds.lastIndex { points >= $0 } ?? 0
        let number = min(titles.count, reached + 1)
        if number >= thresholds.count {
            let span = thresholds[thresholds.count - 1] - thresholds[thresholds.count - 2]
            return LevelInfo(number: number, title: titles[number - 1], progress: span, span: span)
        }
        let floor = thresholds[number - 1]
        return LevelInfo(number: number, title: titles[number - 1], progress: points - floor,
                         span: thresholds[number] - floor)
    }
}

/// A daycare year, from September to the end of August.
struct Season: Hashable {
    let number: Int
    let start: Date
    let end: Date

    func week(for date: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: start, to: date).day ?? 0
        return max(1, days / 7 + 1)
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    static func startYear(for date: Date) -> Int {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        return calendar.component(.month, from: date) >= 9 ? year : year - 1
    }

    static func containing(_ date: Date, firstUse: Date) -> Season {
        let calendar = Calendar.current
        let year = startYear(for: date)
        let start = calendar.date(from: DateComponents(year: year, month: 9, day: 1)) ?? date
        let end = calendar.date(from: DateComponents(year: year + 1, month: 9, day: 1)) ?? date
        let number = max(1, year - startYear(for: firstUse) + 1)
        return Season(number: number, start: start, end: end)
    }
}

/// A home screen icon the parent can unlock.
enum AppIconOption: String, CaseIterable, Identifiable {
    case germily
    case daylight
    case nightShift
    case snowDay
    case golden
    case soupBowl
    case holo

    var id: String { rawValue }

    var alternateName: String? {
        switch self {
        case .germily: return nil
        case .daylight: return "AppIconDaylight"
        case .nightShift: return "AppIconNightShift"
        case .snowDay: return "AppIconSnowDay"
        case .golden: return "AppIconGolden"
        case .soupBowl: return "AppIconSoupBowl"
        case .holo: return "AppIconHolo"
        }
    }

    var previewAsset: String { "icon-preview-" + rawValue }

    var title: String {
        switch self {
        case .germily: return tr("Germily")
        case .daylight: return tr("Daylight")
        case .nightShift: return tr("Night Shift")
        case .snowDay: return tr("Snow Day")
        case .golden: return tr("Golden")
        case .soupBowl: return tr("Soup Bowl")
        case .holo: return tr("Holo")
        }
    }

    var requirement: String {
        switch self {
        case .germily, .daylight: return tr("Always yours")
        case .nightShift: return tr("Earn the Night Shift badge")
        case .snowDay: return tr("Catch 3 colds")
        case .golden: return tr("Catch 20 germs")
        case .soupBowl: return tr("Season Pass")
        case .holo: return tr("Finish the album")
        }
    }
}

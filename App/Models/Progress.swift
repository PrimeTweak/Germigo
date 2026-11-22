import Foundation

struct Badge: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: UInt32
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
            Badge(id: professor, title: tr("Daycare Professor"), detail: tr("Read every lesson"), symbol: "graduationcap.fill", tint: Swatch.gold)
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

import Foundation

struct Badge: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let tint: UInt32
}

enum BadgeCatalog {
    static let nightShift = "night_shift"
    static let ironParent = "iron_parent"

    static var all: [Badge] {
        [
            Badge(id: "patient_one", title: tr("Patient One"), detail: tr("Logged your first germ"), symbol: "1.circle.fill", tint: 0xFF5B4D),
            Badge(id: nightShift, title: tr("Night Shift"), detail: tr("Logged a germ between 1 and 5 AM"), symbol: "moon.fill", tint: 0xB48CFF),
            Badge(id: "tag_team", title: tr("Tag Team"), detail: tr("Both parents sick at the same time"), symbol: "person.2.fill", tint: 0xF26AA8),
            Badge(id: "boomerang", title: tr("Boomerang"), detail: tr("Same germ twice within 30 days"), symbol: "arrow.uturn.backward.circle.fill", tint: 0x2EC4B6),
            Badge(id: "rough_month", title: tr("Rough Month"), detail: tr("Three germs in one month"), symbol: "calendar", tint: 0xFFA33A),
            Badge(id: "speedrun", title: tr("Speedrun"), detail: tr("Back on your feet in a day"), symbol: "hare.fill", tint: 0x7CC4F5),
            Badge(id: "marathon", title: tr("Marathon"), detail: tr("One germ, ten days or more"), symbol: "tortoise.fill", tint: 0x8A93A6),
            Badge(id: "dodger", title: tr("Dodger"), detail: tr("Dodged three incoming germs"), symbol: "figure.run", tint: 0x3D7BFA),
            Badge(id: "collector", title: tr("Collector"), detail: tr("Five different germs caught"), symbol: "square.stack.3d.up.fill", tint: 0x9EDC48),
            Badge(id: "half_album", title: tr("Half Album"), detail: tr("Twelve different germs caught"), symbol: "circle.lefthalf.filled", tint: 0xF2A21B),
            Badge(id: "full_album", title: tr("Full Album"), detail: tr("Every germ of the season caught"), symbol: "checkmark.seal.fill", tint: 0x9B5CFF),
            Badge(id: ironParent, title: tr("Iron Parent"), detail: tr("Thirty days without a germ"), symbol: "shield.fill", tint: 0x2CB868)
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
    static let pointsPerLevel = 400

    static func info(for points: Int) -> LevelInfo {
        let titles = [
            tr("Fresh Host"), tr("Tissue Tester"), tr("Sniffle Scout"), tr("Couch Captain"),
            tr("Soup Sommelier"), tr("Fever Veteran"), tr("Germ Magnet"), tr("Outbreak Survivor"),
            tr("Immune Legend"), tr("Patient Infinity")
        ]
        let number = min(titles.count, points / pointsPerLevel + 1)
        let isMax = number == titles.count
        let progress = isMax ? pointsPerLevel : points % pointsPerLevel
        return LevelInfo(number: number, title: titles[number - 1], progress: progress, span: pointsPerLevel)
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
    case petri
    case nightShift
    case tissueBox
    case goldenDish
    case soupBowl
    case holo

    var id: String { rawValue }

    var alternateName: String? {
        switch self {
        case .petri: return nil
        case .nightShift: return "AppIconNightShift"
        case .tissueBox: return "AppIconTissueBox"
        case .goldenDish: return "AppIconGoldenDish"
        case .soupBowl: return "AppIconSoupBowl"
        case .holo: return "AppIconHolo"
        }
    }

    var previewAsset: String { "icon-preview-" + rawValue }

    var title: String {
        switch self {
        case .petri: return tr("Petri")
        case .nightShift: return tr("Night Shift")
        case .tissueBox: return tr("Tissue Box")
        case .goldenDish: return tr("Golden Dish")
        case .soupBowl: return tr("Soup Bowl")
        case .holo: return tr("Holo")
        }
    }

    var requirement: String {
        switch self {
        case .petri: return tr("Always yours")
        case .nightShift: return tr("Earn the Night Shift badge")
        case .tissueBox: return tr("Catch 3 colds")
        case .goldenDish: return tr("Catch 20 germs")
        case .soupBowl: return tr("Season Pass")
        case .holo: return tr("Finish the album")
        }
    }
}

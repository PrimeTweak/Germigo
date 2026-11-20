import Foundation

enum Rarity: String, Codable, CaseIterable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var basePoints: Int {
        switch self {
        case .common: return 80
        case .uncommon: return 120
        case .rare: return 160
        case .epic: return 220
        case .legendary: return 300
        }
    }

    /// The boss card's health bar, out of 100.
    var bossHealth: Int {
        switch self {
        case .common: return 40
        case .uncommon: return 55
        case .rare: return 70
        case .epic: return 85
        case .legendary: return 100
        }
    }

    var label: String {
        switch self {
        case .common: return tr("Common")
        case .uncommon: return tr("Uncommon")
        case .rare: return tr("Rare")
        case .epic: return tr("Epic")
        case .legendary: return tr("Legendary")
        }
    }
}

struct GermFact: Codable, Hashable {
    let icon: String
    let label: LocalizedText
    let value: LocalizedText
}

struct GermTip: Codable, Hashable {
    let icon: String
    let title: LocalizedText
    let body: LocalizedText
}

struct GermReference: Codable, Hashable {
    let name: String
    let url: String
}

/// The skill tree branch a germ feeds.
enum GermFamily: String, Codable, CaseIterable {
    case airways
    case gut
    case skin
    case other
}

/// The joke stats of a germ's boss card; the weakness restates its Field Notes.
struct GermBoss: Codable, Hashable {
    let attack: LocalizedText
    let weakness: LocalizedText
}

struct GermMyth: Codable, Hashable {
    let claim: LocalizedText
    let isTrue: Bool
    let explanation: LocalizedText
}

/// One collectible germ with its health notes.
struct Germ: Codable, Identifiable, Hashable {
    let id: String
    let number: Int
    let name: String
    let illness: LocalizedText
    let phrase: LocalizedText
    let scientific: LocalizedText
    let rarity: Rarity
    let tintLight: String
    let tintDeep: String
    let quickPick: Bool
    let incubationMinHours: Int?
    let incubationMaxHours: Int?
    let showsUp: LocalizedText
    let lasts: LocalizedText
    let facts: [GermFact]
    let tips: [GermTip]
    let doctor: LocalizedText
    let deepDive: [LocalizedText]
    let sources: [GermReference]
    let family: GermFamily
    /// The upper end of the usual length, in days, when the Field Notes give one.
    let lastsUpToDays: Int?
    let doctorLead: LocalizedText
    let doctorSigns: [LocalizedText]
    let doctorNote: LocalizedText?
    let boss: GermBoss
    let myth: GermMyth
    /// One of the sources that also covers children.
    let kidSource: String?

    var assetName: String { "germ-" + id }

    var kidReference: GermReference? {
        sources.first { $0.url == kidSource }
    }
    var numberLabel: String { String(format: "%02ld", number) }

    /// The period in which symptoms usually start after an exposure.
    func window(from start: Date) -> (opens: Date, closes: Date)? {
        guard let low = incubationMinHours, let high = incubationMaxHours else { return nil }
        return (start.addingTimeInterval(Double(low) * 3600), start.addingTimeInterval(Double(high) * 3600))
    }
}

/// A longer read that unlocks as the album grows.
struct Article: Codable, Identifiable, Hashable {
    let id: String
    let icon: String
    let unlockAtGerms: Int
    let title: LocalizedText
    let summary: LocalizedText
    let paragraphs: [LocalizedText]
    let sources: [GermReference]
}

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

    var assetName: String { "germ-" + id }
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

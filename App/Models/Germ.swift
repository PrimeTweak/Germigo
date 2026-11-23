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

    /// The address to open: https only, so a lesson file cannot start a call or open another app.
    var link: URL? {
        guard let link = URL(string: url), link.scheme?.lowercased() == "https" else { return nil }
        return link
    }
}

/// A page published in English and French; the app opens the one in its language.
struct BilingualReference: Codable, Hashable {
    let name: LocalizedText
    let url: LocalizedText

    var reference: GermReference { GermReference(name: name.value, url: url.value) }
}

/// The skill tree branch a germ feeds.
enum GermFamily: String, Codable, CaseIterable {
    case airways
    case gut
    case skin
    case other
}

/// The kind of microbe behind an illness, when it is always the same kind.
enum Microbe: String, Codable, CaseIterable {
    case virus
    case bacterium
    case fungus
    case parasite

    var label: String {
        switch self {
        case .virus: return tr("Virus")
        case .bacterium: return tr("Bacterium")
        case .fungus: return tr("Fungus")
        case .parasite: return tr("Parasite")
        }
    }

    var antibioticsHelp: Bool { self == .bacterium }

    var antibioticsNote: String {
        switch self {
        case .virus: return tr("Useless against a virus")
        case .bacterium: return tr("Can help, when a doctor prescribes them")
        case .fungus: return tr("Useless: an antifungal treats it")
        case .parasite: return tr("Useless: it needs its own treatment")
        }
    }
}

/// The joke stats of a germ's boss card; the weakness restates its Field Notes.
struct GermBoss: Codable, Hashable {
    let attack: LocalizedText
    let weakness: LocalizedText
    /// True when the weakness alone names the germ, so the quiz may ask about it.
    var weaknessQuiz: Bool?

    /// The attack's name, before the colon of its line.
    var attackName: String {
        let text = attack.value
        return text.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? text
    }

    /// What the attack does, after the colon.
    var attackDetail: String {
        let text = attack.value
        guard let colon = text.firstIndex(of: ":") else { return text }
        let detail = text[text.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        return detail.prefix(1).uppercased() + detail.dropFirst()
    }
}

/// One claim to judge, with the address of the germ source that settles it.
struct GermMyth: Codable, Hashable {
    let id: String
    let claim: LocalizedText
    let isTrue: Bool
    let explanation: LocalizedText
    let source: String
}

/// A myth with the germ it belongs to, as the deck, the quiz and the shelves show it.
struct Myth: Identifiable, Hashable {
    let germ: Germ
    let note: GermMyth

    var id: String { note.id }
    var claim: String { note.claim.value }
    var explanation: String { note.explanation.value }
    var isTrue: Bool { note.isTrue }
    var reference: GermReference? { germ.sources.first { $0.url == note.source } }

    static func == (lhs: Myth, rhs: Myth) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct GermSymptom: Codable, Hashable {
    let icon: String
    let text: LocalizedText
    /// True for the one sign that names the germ on its own.
    var telltale: Bool?
    /// The signs of the symptom picker this line covers.
    var tags: [String]?
}

/// One way a germ travels, with an optional precision.
struct GermSpread: Codable, Hashable {
    let icon: String
    let title: LocalizedText
    let detail: LocalizedText?
}

/// A list of words in English and in French.
struct LocalizedWords: Codable, Hashable {
    let en: [String]
    let fr: [String]
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
    let myths: [GermMyth]
    /// One of the sources that also covers children.
    let kidSource: String?
    /// The health sheet: what it is, what it feels like, how it travels.
    var about: LocalizedText?
    var aboutMore: LocalizedText?
    var symptoms: [GermSymptom] = []
    var symptomsNote: LocalizedText?
    var spreads: [GermSpread] = []
    var spreadNote: LocalizedText?
    var microbe: Microbe?
    /// The Canadian Paediatric Society's page for parents, in English and French.
    var canadaSource: BilingualReference?
    /// Other names parents use for the illness, such as "gastro" or "picotte". Names only, never symptoms.
    var searchWords: LocalizedWords?
    /// The day a health professional approved the case file, written `yyyy-MM-dd`.
    var reviewedOn: String?

    var assetName: String { "germ-" + id }

    var mythCards: [Myth] { myths.map { Myth(germ: self, note: $0) } }

    /// True when the search text is in one of its names, in either language.
    func matches(_ needle: String) -> Bool {
        let names = [illness.en, illness.fr, name, scientific.en, scientific.fr]
            + (searchWords?.en ?? []) + (searchWords?.fr ?? [])
        return names.contains { $0.localizedStandardContains(needle) }
    }

    var kidReference: GermReference? {
        sources.first { $0.url == kidSource }
    }

    /// The page for parents that fits the phone's region: the Canadian one in Canada, otherwise the kid source.
    var parentReference: GermReference? {
        if Locale.current.region?.identifier == "CA", let canada = canadaSource { return canada.reference }
        return kidReference
    }
    var numberLabel: String { String(format: "%02ld", number) }

    /// Who published the sources, for a one-line credit.
    var sourcePublishers: String {
        var names: [String] = []
        for source in sources {
            let name = source.name.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? source.name
            if !names.contains(name) { names.append(name) }
        }
        return names.joined(separator: ", ")
    }

    /// The period in which symptoms usually start after an exposure.
    func window(from start: Date) -> (opens: Date, closes: Date)? {
        guard let low = incubationMinHours, let high = incubationMaxHours else { return nil }
        return (start.addingTimeInterval(Double(low) * 3600), start.addingTimeInterval(Double(high) * 3600))
    }
}

/// A longer read that opens with right answers in the daily quiz, or during its first week online.
struct Article: Codable, Identifiable, Hashable {
    let id: String
    let icon: String
    let unlockAtAnswers: Int
    let title: LocalizedText
    let summary: LocalizedText
    let paragraphs: [LocalizedText]
    let sources: [GermReference]
    /// Set on lessons from the online file; bundled ones have none.
    let releasedOn: Date?
    /// The day a health professional approved the lesson, written `yyyy-MM-dd`.
    var reviewedOn: String?

    /// About how long it takes to read, at 200 words a minute.
    var minutes: Int {
        let words = ([summary] + paragraphs).reduce(0) { $0 + $1.value.split(whereSeparator: \.isWhitespace).count }
        return max(1, Int((Double(words) / 200).rounded(.up)))
    }
}

/// One step of the boss fight, told with the case file's own timings.
struct BossPhase: Hashable {
    let name: String
    let detail: String
}

extension Germ {
    /// Incubation when the case file gives a window, then the attack, then the retreat.
    var bossPhases: [BossPhase] {
        var phases: [BossPhase] = []
        if incubationMinHours != nil {
            phases.append(BossPhase(name: tr("Sneak attack"), detail: tr("Incubation: %@", showsUp.value)))
        }
        phases.append(BossPhase(name: boss.attackName, detail: boss.attackDetail))
        phases.append(BossPhase(name: tr("Retreat"), detail: tr("Lasts: %@", lasts.value)))
        return phases
    }
}

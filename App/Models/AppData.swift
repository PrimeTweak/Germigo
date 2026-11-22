import Foundation

/// The eight household characters, by index. Kids take the first ones in the order they are added.
enum Looks {
    static let count = 8
    static let host = 6
    static let partner = 7
    /// The look that wears a crown.
    static let crown = 3
}

struct Kid: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// The kid's character, one of the household looks.
    var colorIndex: Int

    enum CodingKeys: String, CodingKey {
        case id, name, colorIndex
    }
}

/// Where the parent thinks a germ came from.
enum GermSource: Codable, Hashable {
    case kid(UUID)
    case partner
    case daycare
    case unknown
}

enum BonusKind: String, Codable {
    case rarity
    case nightShift
    case recovery
}

struct LogBonus: Codable, Hashable {
    var kind: BonusKind
    var points: Int
}

/// Who in the couple a log is about.
enum Sufferer: String, Codable, CaseIterable {
    case me
    case partner
    case both

    var includesMe: Bool { self != .partner }
    var includesPartner: Bool { self != .me }
}

/// One time the parent got sick.
struct SickLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var germID: String
    var source: GermSource
    var severity: Int
    var startedAt: Date
    var endedAt: Date?
    var points: Int
    var bonuses: [LogBonus]
    var sufferer: Sufferer
    var kidIllnessID: UUID?
    /// The signs ticked when the germ was picked from its symptoms.
    var symptoms: [String] = []

    enum CodingKeys: String, CodingKey {
        case id, germID, source, severity, startedAt, endedAt, points, bonuses, sufferer, kidIllnessID, symptoms
    }

    var isActive: Bool { endedAt == nil }

    /// Days sick, counting the first day as day one.
    func dayCount(now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let end = endedAt ?? now
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startedAt),
                                           to: calendar.startOfDay(for: end)).day ?? 0
        return max(1, days + 1)
    }
}

/// Someone in the household: the parent, the partner or a kid.
enum Person: Codable, Hashable {
    case me
    case partner
    case kid(UUID)
}

/// A photo of someone in the household. The picture is a file on the phone; the journal keeps who, when and for what.
struct PatientPhoto: Codable, Identifiable, Hashable {
    var id = UUID()
    var person: Person
    var takenAt: Date
    /// The parent's germ the photo belongs to.
    var logID: UUID?
    /// The kid's illness the photo belongs to.
    var illnessID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, person, takenAt, logID, illnessID
    }
}

/// How an exposure ended; expired means the window passed without an answer.
enum ExposureOutcome: String, Codable {
    case open
    case caught
    case dodged
    case expired
}

/// A kid's illness, which starts an incubation countdown for the parent.
struct KidIllness: Codable, Identifiable, Hashable {
    var id = UUID()
    var kidID: UUID
    var germID: String
    var startedAt: Date
    var watching: Bool
    var outcome: ExposureOutcome
    /// Set when the parent dismissed the Live Activity, so it is not started again.
    var liveDismissed = false
    /// The signs ticked when the germ was picked from its symptoms.
    var symptoms: [String] = []
    /// When the kid was better; nil until someone says so.
    var endedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, kidID, germID, startedAt, watching, outcome, liveDismissed, symptoms, endedAt
    }
}

enum AppearanceMode: String, Codable, CaseIterable {
    case system
    case light
    case dark
}

/// The color of the interface. Light or dark is a separate choice, `AppearanceMode`.
enum Theme: String, Codable, CaseIterable {
    case agar
    case coral
    case sky
    case mint
    case bubblegum

    /// A theme this version no longer has reads as the standard one, so the settings still load.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Theme(rawValue: raw) ?? .agar
    }

    /// The badge that opens the theme; the standard one is always open.
    var badgeID: String? {
        switch self {
        case .agar: return nil
        case .coral: return BadgeCatalog.patientOne
        case .sky: return BadgeCatalog.dodger
        case .mint: return BadgeCatalog.ironParent
        case .bubblegum: return BadgeCatalog.tagTeam
        }
    }
}

struct AppSettings: Codable, Hashable {
    var appearance = AppearanceMode.system
    var theme = Theme.agar
    var soundsOn = true
    var checkInsOn = true
    var lessonAlertsOn = true
    var crewAlertsOn = true
    var sideloadPass = false
    /// The skill tree title shown instead of the level title.
    var wornTitle: String?

    enum CodingKeys: String, CodingKey {
        case appearance, theme, soundsOn, checkInsOn, lessonAlertsOn, crewAlertsOn, sideloadPass, wornTitle
    }
}

/// The last streak milestone already celebrated, so it is shown once.
struct MilestoneMark: Codable, Hashable {
    var streakStart: Date
    var days: Int
}

/// The day's quiz once started: its questions and the answers given so far.
struct QuizRound: Codable, Hashable {
    var day: String
    var questionIDs: [String]
    var answers: [Int]
}

/// The daily quiz history: what was asked, what to ask again, and the days it was done.
struct QuizProgress: Codable, Hashable {
    var round: QuizRound?
    var doneDays: [String] = []
    var asked: [String] = []
    var missed: [String] = []
    var rightTotal = 0
    var mythsRight: [String] = []
    /// Every question answered right at least once.
    var rightIDs: [String] = []

    enum CodingKeys: String, CodingKey {
        case round, doneDays, asked, missed, rightTotal, mythsRight, rightIDs
    }
}

/// Everything the app persists on the device.
struct AppData: Codable {
    var onboardingDone = false
    var profileName = ""
    var installedAt = Date()
    var kids: [Kid] = []
    var partnerName: String?
    var logs: [SickLog] = []
    var kidIllnesses: [KidIllness] = []
    var badges: [String: Date] = [:]
    var settings = AppSettings()
    var readArticles: [String] = []
    var celebratedMilestone: MilestoneMark?
    var quiz = QuizProgress()
    /// The Wrapped nemesis guess, by season number: true when it was right.
    var wrapGuesses: [String: Bool] = [:]
    /// The parent's and the partner's characters.
    var hostLook = Looks.host
    var partnerLook = Looks.partner
    var photos: [PatientPhoto] = []

    enum CodingKeys: String, CodingKey {
        case onboardingDone, profileName, installedAt, kids, partnerName, logs, kidIllnesses, badges, settings, readArticles
        case celebratedMilestone, quiz, wrapGuesses, hostLook, partnerLook, photos
    }
}

/// Keys written by earlier versions and read for compatibility only.
private enum LegacySickLogKeys: String, CodingKey {
    case partnerSickToo
}

// MARK: - Tolerant decoding

/// A journal written by another version must still load: a missing key takes its default,
/// and only an unreadable identity, date or list makes the whole file fail.
extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

extension Kid {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorIndex = container.value(.colorIndex, default: 0)
    }
}

extension SickLog {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        germID = try container.decode(String.self, forKey: .germID)
        source = container.value(.source, default: GermSource.unknown)
        severity = container.value(.severity, default: 3)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        points = container.value(.points, default: 0)
        bonuses = container.value(.bonuses, default: [LogBonus]())
        if let stored = try? container.decodeIfPresent(Sufferer.self, forKey: .sufferer) {
            sufferer = stored
        } else {
            let legacy = try decoder.container(keyedBy: LegacySickLogKeys.self)
            sufferer = legacy.value(.partnerSickToo, default: false) ? .both : .me
        }
        kidIllnessID = try? container.decodeIfPresent(UUID.self, forKey: .kidIllnessID)
        symptoms = container.value(.symptoms, default: [String]())
    }
}

extension KidIllness {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kidID = try container.decode(UUID.self, forKey: .kidID)
        germID = try container.decode(String.self, forKey: .germID)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        watching = container.value(.watching, default: false)
        outcome = try container.decodeIfPresent(ExposureOutcome.self, forKey: .outcome) ?? .open
        liveDismissed = container.value(.liveDismissed, default: false)
        symptoms = container.value(.symptoms, default: [String]())
        endedAt = try? container.decodeIfPresent(Date.self, forKey: .endedAt)
    }
}

extension PatientPhoto {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        person = try container.decode(Person.self, forKey: .person)
        takenAt = try container.decode(Date.self, forKey: .takenAt)
        logID = try? container.decodeIfPresent(UUID.self, forKey: .logID)
        illnessID = try? container.decodeIfPresent(UUID.self, forKey: .illnessID)
    }
}

extension AppSettings {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appearance = container.value(.appearance, default: AppearanceMode.system)
        theme = container.value(.theme, default: Theme.agar)
        soundsOn = container.value(.soundsOn, default: true)
        checkInsOn = container.value(.checkInsOn, default: true)
        lessonAlertsOn = container.value(.lessonAlertsOn, default: true)
        crewAlertsOn = container.value(.crewAlertsOn, default: true)
        sideloadPass = container.value(.sideloadPass, default: false)
        wornTitle = try? container.decodeIfPresent(String.self, forKey: .wornTitle)
    }
}

extension QuizProgress {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        round = try? container.decodeIfPresent(QuizRound.self, forKey: .round)
        doneDays = container.value(.doneDays, default: [String]())
        asked = container.value(.asked, default: [String]())
        missed = container.value(.missed, default: [String]())
        rightTotal = container.value(.rightTotal, default: 0)
        mythsRight = container.value(.mythsRight, default: [String]())
        rightIDs = container.value(.rightIDs, default: [String]())
    }
}

extension AppData {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onboardingDone = container.value(.onboardingDone, default: false)
        profileName = container.value(.profileName, default: "")
        installedAt = try container.decodeIfPresent(Date.self, forKey: .installedAt) ?? Date()
        kids = try container.decodeIfPresent([Kid].self, forKey: .kids) ?? []
        partnerName = try? container.decodeIfPresent(String.self, forKey: .partnerName)
        logs = try container.decodeIfPresent([SickLog].self, forKey: .logs) ?? []
        kidIllnesses = try container.decodeIfPresent([KidIllness].self, forKey: .kidIllnesses) ?? []
        badges = container.value(.badges, default: [String: Date]())
        settings = container.value(.settings, default: AppSettings())
        readArticles = container.value(.readArticles, default: [String]())
        celebratedMilestone = try? container.decodeIfPresent(MilestoneMark.self, forKey: .celebratedMilestone)
        quiz = container.value(.quiz, default: QuizProgress())
        wrapGuesses = container.value(.wrapGuesses, default: [String: Bool]())
        hostLook = container.value(.hostLook, default: Looks.host)
        partnerLook = container.value(.partnerLook, default: Looks.partner)
        photos = try container.decodeIfPresent([PatientPhoto].self, forKey: .photos) ?? []
    }
}

/// Input collected by the log sheet.
struct LogDraft {
    var germID: String
    var source: GermSource
    var severity: Int
    var startedAt: Date
    var sufferer: Sufferer
    var kidIllnessID: UUID?
    var symptoms: [String] = []
}

/// A request to open the log sheet, optionally prefilled from a kid's illness or from the symptom pages.
struct LogRequest: Identifiable, Hashable {
    let id = UUID()
    var kidIllnessID: UUID?
    var germID: String?
    var symptoms: [String] = []
    var sufferer = Sufferer.me
}

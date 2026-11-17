import Foundation

struct Kid: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var ageYears: Int
    var daycareSince: Date
    var colorIndex: Int
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
}

struct LogBonus: Codable, Hashable {
    var kind: BonusKind
    var points: Int
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
    var partnerSickToo: Bool
    var kidIllnessID: UUID?

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

enum ExposureOutcome: String, Codable {
    case open
    case caught
    case dodged
}

/// A kid's illness, which starts an incubation countdown for the parent.
struct KidIllness: Codable, Identifiable, Hashable {
    var id = UUID()
    var kidID: UUID
    var germID: String
    var startedAt: Date
    var watching: Bool
    var outcome: ExposureOutcome
}

enum AppearanceMode: String, Codable, CaseIterable {
    case system
    case light
    case dark
}

enum Theme: String, Codable, CaseIterable {
    case agar
    case nightShift
    case mint
}

struct AppSettings: Codable, Hashable {
    var appearance = AppearanceMode.system
    var theme = Theme.agar
    var soundsOn = true
    var checkInsOn = true
    var crewAlertsOn = true
    var quietHoursOn = true
    var quietStartMinute = 22 * 60
    var quietEndMinute = 7 * 60
    var sideloadPass = false
}

/// Everything the app persists on the device.
struct AppData: Codable {
    var schemaVersion = 1
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
}

/// Input collected by the log sheet.
struct LogDraft {
    var germID: String
    var source: GermSource
    var severity: Int
    var startedAt: Date
    var partnerSickToo: Bool
    var kidIllnessID: UUID?
}

/// A request to open the log sheet, optionally prefilled from a kid's illness.
struct LogRequest: Identifiable {
    let id = UUID()
    var kidIllnessID: UUID?
}

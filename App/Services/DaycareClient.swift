import Foundation

struct DaycareGroup: Codable, Identifiable, Hashable {
    let id: String
    var name: String
    /// Families who picked the group; only the daycare sees it.
    var families: Int?
}

struct DaycareInfo: Codable, Hashable {
    let id: String
    let name: String
    let groups: [DaycareGroup]
    var families: Int?
}

struct DaycareNotice: Codable, Identifiable, Hashable {
    let id: String
    let groupID: String?
    let germID: String
    let note: String
    let at: Double
    /// Families reached and reports received; only the daycare sees them.
    var recipients: Int?
    var reports: Int?

    var date: Date { Date(timeIntervalSince1970: at / 1000) }
}

/// What a family subscribed to a daycare receives.
struct DaycareFeed: Codable, Hashable {
    let daycare: DaycareInfo
    let groupIDs: [String]
    let notices: [DaycareNotice]
}

struct DirectorDaycare: Codable, Hashable {
    let id: String
    let name: String
    let code: String
    let email: String?
    /// The private address that turns an email into a notice; nil when the server has none.
    let inbox: String?
    let families: Int
    let groups: [DaycareGroup]
}

struct DirectorState: Codable, Hashable {
    let daycare: DirectorDaycare
    let notices: [DaycareNotice]
}

struct DaycareSession<State: Codable>: Codable {
    let token: String
    let state: State
}

enum DaycareCode {
    static let length = 8

    /// The code inside what was typed or scanned: a bare code, a spaced one, or the link of a daycare's QR code.
    static func extract(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: "/d/") {
            text = String(text[range.upperBound...])
            text = String(text.prefix { $0 != "?" && $0 != "#" && $0 != "/" })
        }
        let code = String(text.uppercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) && $0.isASCII })
        return code.count == length ? code : nil
    }

    /// Written in two halves, the way posters show it.
    static func display(_ code: String) -> String {
        guard code.count == length else { return code }
        return String(code.prefix(4)) + "-" + String(code.suffix(4))
    }

    /// What a daycare's QR code holds: its page on the server, or the bare code without one.
    static func link(_ code: String) -> String {
        AppConfig.serverURL.map { $0.appendingPathComponent("d").appendingPathComponent(code).absoluteString } ?? code
    }
}

extension CrewAPIError {
    /// The same error, told in daycare terms.
    var daycareMessage: String {
        switch code {
        case "invalid_code": return tr("No daycare matches that code.")
        case "unauthorized": return tr("This daycare is no longer on Germigo.")
        case "email_rejected": return tr("That email address doesn't look right.")
        case "note_too_long": return tr("The note is too long.")
        case "note_rejected": return tr("A note can't hold a link or an email address.")
        case "daycare_full": return tr("This daycare's list is full.")
        case "offline": return tr("The server can't be reached right now.")
        default: return errorDescription ?? tr("Something went wrong. Try again.")
        }
    }
}

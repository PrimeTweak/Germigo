import AppIntents
import Foundation

/// Actions the Live Activity buttons forward to the app process.
enum IntentAction {
    case caught(exposureID: String)
    case stillFine(exposureID: String)
    case dodged(exposureID: String)
    case better
    /// From a daycare watch: the kid caught the germ the daycare announced.
    case kidCaught(kidID: String, germID: String)
    /// From the evening report: nobody was sick today.
    case allGood
    /// From the evening report: open Today on the symptom pages.
    case someoneSick
}

/// Set by the app at launch; stays nil inside the widget extension.
enum IntentRelay {
    static var handler: ((IntentAction) async -> Void)?
}

struct CaughtItIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "It got me"
    static let isDiscoverable = false
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @Parameter(title: "Exposure")
    var exposureID: String

    init() {}

    init(exposureID: String) {
        self.exposureID = exposureID
    }

    func perform() async throws -> some IntentResult {
        await IntentRelay.handler?(.caught(exposureID: exposureID))
        return .result()
    }
}

struct StillFineIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Still fine"
    static let isDiscoverable = false
    static let authenticationPolicy = IntentAuthenticationPolicy.requiresAuthentication

    @Parameter(title: "Exposure")
    var exposureID: String

    init() {}

    init(exposureID: String) {
        self.exposureID = exposureID
    }

    func perform() async throws -> some IntentResult {
        await IntentRelay.handler?(.stillFine(exposureID: exposureID))
        return .result()
    }
}

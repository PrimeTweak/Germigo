import Foundation
import Observation

/// The parent's daycare crew: membership, radar, feed and moderation.
@MainActor
@Observable
final class CrewStore {
    static let shared = CrewStore()
    static let reactionKinds = ["soup", "tissue", "tea", "heart"]

    private(set) var state: CrewState?
    private(set) var isMember: Bool
    private(set) var isLoading = false
    private(set) var blockedIDs: Set<String>
    var errorMessage: String?

    /// When true, logged germs also appear in the feed under the crew name.
    private(set) var sharesName: Bool

    @ObservationIgnored private var token: String?

    private enum Keys {
        static let token = "crew.token"
        static let sharesName = "crew.sharesName"
        static let blocked = "crew.blocked"
        static let radarSeen = "crew.radarSeen"
    }

    private struct CreateBody: Encodable {
        let name: String
        let displayName: String
        let emblem: Int
    }

    private struct JoinBody: Encodable {
        let code: String
        let displayName: String
    }

    private struct EventBody: Encodable {
        let germID: String
        let named: Bool
    }

    private struct ReactionBody: Encodable {
        let kind: String
    }

    private struct ReportBody: Encodable {
        let memberID: String
        let reason: String
    }

    private struct RenameBody: Encodable {
        let displayName: String
    }

    init() {
        let stored = Keychain.get(Keys.token)
        token = stored
        isMember = stored != nil
        sharesName = UserDefaults.standard.bool(forKey: Keys.sharesName)
        blockedIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.blocked) ?? [])
    }

    var isConfigured: Bool { AppConfig.serverURL != nil }

    var visibleFeed: [FeedEvent] {
        (state?.feed ?? []).filter { !blockedIDs.contains($0.memberID) }
    }

    var leaderboard: [CrewMember] {
        (state?.members ?? []).filter { !blockedIDs.contains($0.id) && $0.germs > 0 }
            .sorted { $0.germs > $1.germs }
    }

    private func client() throws -> CrewClient {
        guard let url = AppConfig.serverURL else { throw CrewAPIError(code: "offline") }
        return CrewClient(baseURL: url, token: token)
    }

    private func adopt(_ session: CrewSession) {
        token = session.token
        Keychain.set(session.token, for: Keys.token)
        isMember = true
        state = session.state
        rememberRadar(session.state.radar)
    }

    private func run(_ work: () async throws -> Void) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try await work()
            errorMessage = nil
            return true
        } catch let error as CrewAPIError {
            if error.code == "unauthorized" { forget() }
            errorMessage = error.errorDescription
            return false
        } catch {
            errorMessage = tr("Something went wrong. Try again.")
            return false
        }
    }

    func create(name: String, displayName: String, emblem: Int) async -> Bool {
        await run {
            let session: CrewSession = try await self.client().send(
                "POST", "v1/crews", CreateBody(name: name, displayName: displayName, emblem: emblem))
            self.adopt(session)
        }
    }

    func join(code: String, displayName: String) async -> Bool {
        await run {
            let session: CrewSession = try await self.client().send(
                "POST", "v1/crews/join", JoinBody(code: code.uppercased(), displayName: displayName))
            self.adopt(session)
        }
    }

    func refresh() async {
        guard isMember, isConfigured else { return }
        _ = await run {
            let fresh: CrewState = try await self.client().get("v1/crew")
            self.state = fresh
            self.rememberRadar(fresh.radar)
        }
    }

    /// Adds a logged germ to the radar, and to the feed when the name is shared.
    func reportGerm(_ germID: String) async {
        guard isMember, isConfigured else { return }
        _ = await run {
            let fresh: CrewState = try await self.client().send(
                "POST", "v1/crew/events", EventBody(germID: germID, named: self.sharesName))
            self.state = fresh
        }
    }

    func react(to eventID: String, kind: String) async {
        _ = await run {
            let fresh: CrewState = try await self.client().send(
                "POST", "v1/crew/events/" + eventID + "/reactions", ReactionBody(kind: kind))
            self.state = fresh
        }
    }

    func rename(_ displayName: String) async -> Bool {
        await run {
            let fresh: CrewState = try await self.client().send(
                "POST", "v1/crew/me", RenameBody(displayName: displayName))
            self.state = fresh
        }
    }

    func report(memberID: String, reason: String) async -> Bool {
        await run {
            let fresh: CrewState = try await self.client().send(
                "POST", "v1/crew/reports", ReportBody(memberID: memberID, reason: reason))
            self.state = fresh
        }
    }

    func setSharesName(_ value: Bool) {
        sharesName = value
        UserDefaults.standard.set(value, forKey: Keys.sharesName)
    }

    func block(_ memberID: String) {
        blockedIDs.insert(memberID)
        UserDefaults.standard.set(Array(blockedIDs), forKey: Keys.blocked)
    }

    func unblockAll() {
        blockedIDs = []
        UserDefaults.standard.removeObject(forKey: Keys.blocked)
    }

    /// Leaves the crew and deletes everything the server holds about this member.
    func leave() async -> Bool {
        guard isMember else { return true }
        let done = await run {
            try await self.client().delete("v1/crew/me")
        }
        if done { forget() }
        return done
    }

    private func forget() {
        token = nil
        Keychain.set(nil, for: Keys.token)
        isMember = false
        state = nil
        UserDefaults.standard.removeObject(forKey: Keys.radarSeen)
    }

    private func rememberRadar(_ radar: [RadarEntry]) {
        UserDefaults.standard.set(radar.map { $0.germID }, forKey: Keys.radarSeen)
    }

    /// Checks the radar in the background and announces germs that just appeared.
    func backgroundRefresh() async {
        guard isMember, isConfigured, AppModel.shared.data.settings.crewAlertsOn else { return }
        let seen = Set(UserDefaults.standard.stringArray(forKey: Keys.radarSeen) ?? [])
        let fresh: CrewState
        do {
            fresh = try await client().get("v1/crew")
        } catch {
            return
        }
        state = fresh
        for entry in fresh.radar where !seen.contains(entry.germID) {
            let illness = AppModel.shared.catalog.germ(entry.germID)?.illness.value ?? entry.germID
            NotificationManager.notifyRadar(illness: illness, crewName: fresh.crew.name, families: entry.families)
        }
        rememberRadar(fresh.radar)
    }
}

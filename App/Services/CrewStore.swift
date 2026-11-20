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
    private(set) var blockedIDs: Set<String>
    var errorMessage: String?

    /// When true, logged germs also appear in the feed under the crew name.
    private(set) var sharesName: Bool

    /// Requests in flight; several can overlap.
    private var operations = 0

    @ObservationIgnored private var token: String?
    @ObservationIgnored private var isFlushing = false

    private static let pendingLimit = 20
    private static let pendingLifetime: TimeInterval = 7 * 24 * 3600

    private enum Keys {
        static let token = "crew.token"
        static let sharesName = "crew.sharesName"
        static let blocked = "crew.blocked"
        static let radarSeen = "crew.radarSeen"
        static let state = "crew.state"
        static let pending = "crew.pending"
    }

    /// A germ share that has not reached the server yet.
    private struct PendingShare: Codable {
        let id: String
        let germID: String
        let named: Bool
        let queuedAt: Date
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
        let clientID: String
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
        state = stored == nil ? nil : Self.cachedState()
    }

    var isConfigured: Bool { AppConfig.serverURL != nil }

    var isLoading: Bool { operations > 0 }

    private static func cachedState() -> CrewState? {
        guard let raw = UserDefaults.standard.data(forKey: Keys.state) else { return nil }
        return try? JSONDecoder().decode(CrewState.self, from: raw)
    }

    /// Keeps the last state on the device so the crew shows without waiting for the network.
    private func store(_ fresh: CrewState) {
        state = fresh
        UserDefaults.standard.set(try? JSONEncoder().encode(fresh), forKey: Keys.state)
    }

    private var pendingShares: [PendingShare] {
        get {
            guard let raw = UserDefaults.standard.data(forKey: Keys.pending) else { return [] }
            return (try? JSONDecoder().decode([PendingShare].self, from: raw)) ?? []
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: Keys.pending)
        }
    }

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
        store(session.state)
        rememberRadar(session.state.radar)
    }

    /// Runs one request. A quiet request leaves the message of the visible form alone.
    private func run(quiet: Bool = false, _ work: () async throws -> Void) async -> Bool {
        operations += 1
        defer { operations -= 1 }
        do {
            try await work()
            if !quiet { errorMessage = nil }
            return true
        } catch let error as CrewAPIError {
            if error.code == "unauthorized" { forget() }
            if !quiet || error.code == "unauthorized" { errorMessage = error.errorDescription }
            return false
        } catch {
            if !quiet { errorMessage = tr("Something went wrong. Try again.") }
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
        await flushPending()
        _ = await run(quiet: state != nil) {
            let fresh: CrewState = try await self.client().get("v1/crew")
            self.store(fresh)
            self.rememberRadar(fresh.radar)
        }
    }

    /// Adds a logged germ to the radar, and to the feed when the name is shared.
    /// The share is queued first, so it survives a lost connection.
    func reportGerm(_ germID: String) async {
        guard isMember, isConfigured else { return }
        let share = PendingShare(id: UUID().uuidString.lowercased(), germID: germID, named: sharesName, queuedAt: Date())
        pendingShares = Array((pendingShares + [share]).suffix(Self.pendingLimit))
        await flushPending()
    }

    /// Sends queued shares, oldest first, and stops at the first one the server cannot take yet.
    private func flushPending() async {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        pendingShares = pendingShares.filter { Date().timeIntervalSince($0.queuedAt) < Self.pendingLifetime }
        while isMember, let next = pendingShares.first {
            do {
                let fresh: CrewState = try await client().send(
                    "POST", "v1/crew/events", EventBody(germID: next.germID, named: next.named, clientID: next.id))
                store(fresh)
            } catch let error as CrewAPIError {
                if error.code == "unauthorized" {
                    forget()
                    return
                }
                if error.code == "offline" || error.code == "rate_limited" { return }
            } catch {
                return
            }
            pendingShares = Array(pendingShares.dropFirst())
        }
    }

    func react(to eventID: String, kind: String) async {
        _ = await run(quiet: true) {
            let fresh: CrewState = try await self.client().send(
                "POST", "v1/crew/events/" + eventID + "/reactions", ReactionBody(kind: kind))
            self.store(fresh)
        }
    }

    func rename(_ displayName: String) async -> Bool {
        await run {
            let fresh: CrewState = try await self.client().send(
                "POST", "v1/crew/me", RenameBody(displayName: displayName))
            self.store(fresh)
        }
    }

    func report(memberID: String, reason: String) async -> Bool {
        await run {
            let fresh: CrewState = try await self.client().send(
                "POST", "v1/crew/reports", ReportBody(memberID: memberID, reason: reason))
            self.store(fresh)
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
        for key in [Keys.radarSeen, Keys.state, Keys.pending] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Clears what the crew feature keeps on this device; used by Delete Everything.
    func resetLocal() {
        forget()
        unblockAll()
        setSharesName(false)
        errorMessage = nil
    }

    private func rememberRadar(_ radar: [RadarEntry]) {
        UserDefaults.standard.set(radar.map { $0.germID }, forKey: Keys.radarSeen)
    }

    /// Checks the radar in the background and announces germs that just appeared.
    func backgroundRefresh() async {
        guard isMember, isConfigured, AppModel.shared.hasPass,
              AppModel.shared.data.settings.crewAlertsOn else { return }
        let seen = Set(UserDefaults.standard.stringArray(forKey: Keys.radarSeen) ?? [])
        let fresh: CrewState
        do {
            fresh = try await client().get("v1/crew")
        } catch {
            return
        }
        store(fresh)
        for entry in fresh.radar where !seen.contains(entry.germID) {
            let illness = AppModel.shared.catalog.germ(entry.germID)?.illness.value ?? entry.germID
            NotificationManager.notifyRadar(illness: illness, crewName: fresh.crew.name, families: entry.families)
        }
        rememberRadar(fresh.radar)
    }
}

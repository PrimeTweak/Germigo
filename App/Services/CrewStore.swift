import Foundation
import Observation

/// The parent's daycare crew: membership, radar, feed and moderation.
@MainActor
@Observable
final class CrewStore {
    static let shared = CrewStore()
    static let reactionKinds = ["soup", "tissue", "tea", "heart"]
    static let codeLength = 8

    private(set) var state: CrewState?
    private(set) var isMember: Bool
    private(set) var blockedIDs: Set<String>
    var errorMessage: String?

    /// When true, logged germs also appear in the feed under the crew name.
    private(set) var sharesName: Bool
    /// Whether a logged germ is offered to the crew; off until the parent turns it on.
    private(set) var tellsCrew: Bool

    /// Requests in flight; several can overlap.
    private var operations = 0

    @ObservationIgnored private var token: String?
    @ObservationIgnored private var isFlushing = false

    private static let pendingLimit = 20
    private static let pendingLifetime: TimeInterval = 7 * 24 * 3600

    private enum Keys {
        static let token = "crew.token"
        static let sharesName = "crew.sharesName"
        static let tellsCrew = "crew.tellsCrew"
        static let blocked = "crew.blocked"
        static let radarSeen = "crew.radarSeen"
        static let state = "crew.state"
        static let pending = "crew.pending"
        static let sharedLogs = "crew.sharedLogs"
    }

    /// A germ share, caught or beaten, that has not reached the server yet.
    private struct PendingShare: Codable {
        let id: String
        let germID: String
        let named: Bool
        let queuedAt: Date
        let kind: String?
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
        let kind: String?
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
        tellsCrew = UserDefaults.standard.bool(forKey: Keys.tellsCrew)
        blockedIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.blocked) ?? [])
        state = stored == nil ? nil : Self.cachedState()
        #if GERMIGO_SIDELOAD
        if AppConfig.serverURL == nil {
            isMember = true
            state = Self.demoState(crewName: "The Ladybugs", emblem: 0, displayName: "You")
        }
        #endif
    }

    var isConfigured: Bool { AppConfig.serverURL != nil }

    /// True in a test build without a server: the crew is a sample that never leaves the phone.
    var isDemo: Bool {
        #if GERMIGO_SIDELOAD
        return !isConfigured
        #else
        return false
        #endif
    }

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

    /// Logs posted under the crew name, newest last, so their end can be posted too.
    private var sharedLogIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: Keys.sharedLogs) ?? [] }
        set { UserDefaults.standard.set(Array(newValue.suffix(Self.pendingLimit)), forKey: Keys.sharedLogs) }
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
        #if GERMIGO_SIDELOAD
        if isDemo {
            isMember = true
            state = Self.demoState(crewName: name, emblem: emblem, displayName: displayName)
            return true
        }
        #endif
        return await run {
            let session: CrewSession = try await self.client().send(
                "POST", "v1/crews", CreateBody(name: name, displayName: displayName, emblem: emblem))
            self.adopt(session)
        }
    }

    func join(code: String, displayName: String) async -> Bool {
        #if GERMIGO_SIDELOAD
        if isDemo {
            isMember = true
            state = Self.demoState(crewName: "The Ladybugs", emblem: 0, displayName: displayName)
            return true
        }
        #endif
        return await run {
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
    func reportGerm(_ germID: String, logID: UUID) async {
        if sharesName { sharedLogIDs.append(logID.uuidString) }
        #if GERMIGO_SIDELOAD
        if isDemo {
            demoReport(germID)
            return
        }
        #endif
        guard isMember, isConfigured else { return }
        let share = PendingShare(id: UUID().uuidString.lowercased(), germID: germID, named: sharesName, queuedAt: Date(),
                                 kind: nil)
        pendingShares = Array((pendingShares + [share]).suffix(Self.pendingLimit))
        await flushPending()
    }

    /// Posts a recovery to the feed, only for a germ that was posted there under the crew name.
    func reportWin(_ germID: String, logID: UUID) async {
        guard sharesName, sharedLogIDs.contains(logID.uuidString) else { return }
        sharedLogIDs.removeAll { $0 == logID.uuidString }
        #if GERMIGO_SIDELOAD
        if isDemo {
            demoWin(germID)
            return
        }
        #endif
        guard isMember, isConfigured else { return }
        let share = PendingShare(id: UUID().uuidString.lowercased(), germID: germID, named: true, queuedAt: Date(),
                                 kind: "beat")
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
                    "POST", "v1/crew/events", EventBody(germID: next.germID, named: next.named, clientID: next.id,
                                                        kind: next.kind))
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
        #if GERMIGO_SIDELOAD
        if isDemo {
            demoReact(to: eventID, kind: kind)
            return
        }
        #endif
        _ = await run(quiet: true) {
            let fresh: CrewState = try await self.client().send(
                "POST", "v1/crew/events/" + eventID + "/reactions", ReactionBody(kind: kind))
            self.store(fresh)
        }
    }

    func rename(_ displayName: String) async -> Bool {
        #if GERMIGO_SIDELOAD
        if isDemo {
            demoRename(displayName)
            return true
        }
        #endif
        return await run {
            let fresh: CrewState = try await self.client().send(
                "POST", "v1/crew/me", RenameBody(displayName: displayName))
            self.store(fresh)
        }
    }

    func report(memberID: String, reason: String) async -> Bool {
        #if GERMIGO_SIDELOAD
        if isDemo { return true }
        #endif
        return await run {
            let fresh: CrewState = try await self.client().send(
                "POST", "v1/crew/reports", ReportBody(memberID: memberID, reason: reason))
            self.store(fresh)
        }
    }

    func setSharesName(_ value: Bool) {
        sharesName = value
        UserDefaults.standard.set(value, forKey: Keys.sharesName)
    }

    func setTellsCrew(_ value: Bool) {
        tellsCrew = value
        UserDefaults.standard.set(value, forKey: Keys.tellsCrew)
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
        #if GERMIGO_SIDELOAD
        if isDemo {
            forget()
            return true
        }
        #endif
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
        tellsCrew = false
        for key in [Keys.radarSeen, Keys.state, Keys.pending, Keys.sharedLogs, Keys.tellsCrew] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// Clears what the crew feature keeps on this device; used by Delete everything.
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

#if GERMIGO_SIDELOAD
/// The sample crew of a test build without a server: made-up families, kept in memory only.
extension CrewStore {
    static func demoState(crewName: String, emblem: Int, displayName: String) -> CrewState {
        let me = CrewMember(id: "demo-me", name: displayName, germs: 2, colorIndex: 0)
        let others = [
            CrewMember(id: "demo-1", name: "Maude", germs: 5, colorIndex: 1),
            CrewMember(id: "demo-2", name: "Karim", germs: 3, colorIndex: 2),
            CrewMember(id: "demo-3", name: "Jo", germs: 1, colorIndex: 3),
            CrewMember(id: "demo-4", name: "Elise", germs: 0, colorIndex: 4)
        ]
        let now = Date().timeIntervalSince1970 * 1000
        let hour = 3_600_000.0
        let feed = [
            FeedEvent(id: "demo-event-1", memberID: "demo-1", name: "Maude", colorIndex: 1, germID: "noro",
                      at: now - 3 * hour, reactions: ["soup": 2, "tissue": 1], mine: []),
            FeedEvent(id: "demo-event-4", memberID: "demo-2", name: "Karim", colorIndex: 2, germID: "rhino",
                      at: now - 5 * hour, reactions: ["heart": 2], mine: [], kind: "beat"),
            FeedEvent(id: "demo-event-2", memberID: "demo-2", name: "Karim", colorIndex: 2, germID: "rhino",
                      at: now - 26 * hour, reactions: ["tea": 1], mine: ["tea"]),
            FeedEvent(id: "demo-event-3", memberID: "demo-3", name: "Jo", colorIndex: 3, germID: "coxy",
                      at: now - 50 * hour, reactions: [:], mine: [])
        ]
        let radar = [RadarEntry(germID: "noro", families: 3), RadarEntry(germID: "rhino", families: 2)]
        let info = CrewInfo(id: "demo", name: crewName, emblem: emblem, code: "TEST4242", families: others.count + 1)
        return CrewState(crew: info, me: me, members: [me] + others, radar: radar, feed: feed)
    }

    private func demoUpdate(me: CrewMember? = nil, radar: [RadarEntry]? = nil, feed: [FeedEvent]? = nil) {
        guard let current = state else { return }
        let member = me ?? current.me
        state = CrewState(crew: current.crew, me: member,
                          members: current.members.map { $0.id == member.id ? member : $0 },
                          radar: radar ?? current.radar, feed: feed ?? current.feed)
    }

    private func demoReport(_ germID: String) {
        guard let current = state else { return }
        let me = CrewMember(id: current.me.id, name: current.me.name, germs: current.me.germs + 1,
                            colorIndex: current.me.colorIndex)
        var radar = current.radar
        if let index = radar.firstIndex(where: { $0.germID == germID }) {
            radar[index] = RadarEntry(germID: germID, families: radar[index].families + 1)
        } else {
            radar.append(RadarEntry(germID: germID, families: 2))
        }
        var feed = current.feed
        if sharesName {
            feed.insert(FeedEvent(id: UUID().uuidString, memberID: me.id, name: me.name, colorIndex: me.colorIndex,
                                  germID: germID, at: Date().timeIntervalSince1970 * 1000, reactions: [:], mine: []), at: 0)
        }
        demoUpdate(me: me, radar: radar, feed: feed)
    }

    private func demoWin(_ germID: String) {
        guard let current = state else { return }
        let win = FeedEvent(id: UUID().uuidString, memberID: current.me.id, name: current.me.name,
                            colorIndex: current.me.colorIndex, germID: germID, at: Date().timeIntervalSince1970 * 1000,
                            reactions: [:], mine: [], kind: "beat")
        demoUpdate(feed: [win] + current.feed)
    }

    private func demoReact(to eventID: String, kind: String) {
        guard let current = state else { return }
        let feed = current.feed.map { event -> FeedEvent in
            guard event.id == eventID else { return event }
            var reactions = event.reactions
            var mine = event.mine
            if let index = mine.firstIndex(of: kind) {
                mine.remove(at: index)
                reactions[kind] = max(0, (reactions[kind] ?? 1) - 1)
            } else {
                mine.append(kind)
                reactions[kind, default: 0] += 1
            }
            return FeedEvent(id: event.id, memberID: event.memberID, name: event.name, colorIndex: event.colorIndex,
                             germID: event.germID, at: event.at, reactions: reactions, mine: mine, kind: event.kind)
        }
        demoUpdate(feed: feed)
    }

    private func demoRename(_ displayName: String) {
        guard let current = state else { return }
        demoUpdate(me: CrewMember(id: current.me.id, name: displayName, germs: current.me.germs,
                                  colorIndex: current.me.colorIndex))
    }
}
#endif

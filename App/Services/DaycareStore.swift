import Foundation
import Observation

/// Daycare notices: the daycares this family follows, and the daycare this phone runs, if any.
@MainActor
@Observable
final class DaycareStore {
    static let shared = DaycareStore()

    /// One followed daycare, with the group each kid is in.
    struct Membership: Codable, Identifiable, Hashable {
        var feed: DaycareFeed
        /// Kid ID to group ID; an empty group ID means the whole daycare only.
        var kidGroups: [String: String]

        var id: String { feed.daycare.id }
    }

    /// Key used in place of a kid ID when the household has no kids yet.
    static let householdKey = "household"

    private(set) var memberships: [Membership]
    private(set) var director: DirectorState?
    private(set) var readIDs: Set<String>
    /// Kids being watched after a notice, as "noticeID/kidID", with the time Germily asks.
    private(set) var watches: [String: Date]
    var errorMessage: String?
    /// True when the last background refresh could not reach the server, so the notices may be out of date.
    private(set) var isStale = false
    /// A notice opened from a notification, waiting for the Crew tab to show it.
    var openedNoticeID: String?

    private var operations = 0

    @ObservationIgnored private var pushToken: String?
    /// Followed daycares that already have the current address for notifications.
    @ObservationIgnored private var pushDelivered: Set<String>

    private enum Keys {
        static let memberships = "daycare.memberships"
        static let director = "daycare.director"
        static let directorState = "daycare.directorState"
        static let read = "daycare.read"
        static let watches = "daycare.watches"
        static let pushToken = "daycare.pushToken"
        static let pushDelivered = "daycare.pushDelivered"

        static func parent(_ daycareID: String) -> String {
            "daycare.parent." + daycareID
        }
    }

    private struct JoinBody: Encodable {
        let code: String
        let groupIDs: [String]
        let pushToken: String?
        let language: String
    }

    private struct GroupsBody: Encodable {
        let groupIDs: [String]
    }

    private struct PushBody: Encodable {
        let pushToken: String
        let language: String
    }

    private struct ReportBody: Encodable {
        let noticeID: String
    }

    private struct GroupInput: Encodable {
        let id: String?
        let name: String
    }

    private struct CreateBody: Encodable {
        let name: String
        let groups: [GroupInput]
        let email: String?
        let language: String
    }

    private struct UpdateBody: Encodable {
        var name: String?
        var groups: [GroupInput]?
        var email: String?
        var language: String?
    }

    private struct NoticeBody: Encodable {
        let germID: String
        let groupID: String?
        let note: String
    }

    private struct EmptyBody: Encodable {}

    private struct Lookup: Decodable {
        let daycare: DaycareInfo
    }

    init() {
        let defaults = UserDefaults.standard
        let saved = defaults.data(forKey: Keys.memberships)
            .flatMap { try? JSONDecoder().decode([Membership].self, from: $0) } ?? []
        memberships = saved.filter { Keychain.get(Keys.parent($0.id)) != nil }
        director = Keychain.get(Keys.director) == nil ? nil : defaults.data(forKey: Keys.directorState)
            .flatMap { try? JSONDecoder().decode(DirectorState.self, from: $0) }
        readIDs = Set(defaults.stringArray(forKey: Keys.read) ?? [])
        watches = (defaults.dictionary(forKey: Keys.watches) as? [String: Date]) ?? [:]
        pushToken = defaults.string(forKey: Keys.pushToken)
        pushDelivered = Set(defaults.stringArray(forKey: Keys.pushDelivered) ?? [])
        #if GERMILY_SIDELOAD
        if AppConfig.serverURL == nil {
            memberships = [Self.demoMembership()]
            director = nil
        }
        #endif
    }

    var isConfigured: Bool { AppConfig.serverURL != nil }

    /// True in a test build without a server: the daycare is a sample that never leaves the phone.
    var isDemo: Bool {
        #if GERMILY_SIDELOAD
        return !isConfigured
        #else
        return false
        #endif
    }

    var isLoading: Bool { operations > 0 }

    /// True when this phone follows a daycare, so it needs the address for notifications.
    var needsPush: Bool { isConfigured && !memberships.isEmpty }

    private var language: String { AppLanguage.isFrench ? "fr" : "en" }

    // MARK: - Reading

    func membership(_ id: String) -> Membership? {
        memberships.first { $0.id == id }
    }

    /// The notice with its daycare, wherever this family received it.
    func notice(_ id: String) -> (notice: DaycareNotice, membership: Membership)? {
        for membership in memberships {
            if let notice = membership.feed.notices.first(where: { $0.id == id }) { return (notice, membership) }
        }
        return nil
    }

    func latest(in membership: Membership) -> DaycareNotice? {
        membership.feed.notices.max { $0.at < $1.at }
    }

    func isUnread(_ notice: DaycareNotice) -> Bool {
        !readIDs.contains(notice.id)
    }

    func markRead(_ notice: DaycareNotice) {
        guard !readIDs.contains(notice.id) else { return }
        readIDs.insert(notice.id)
        let known = Set(memberships.flatMap { $0.feed.notices.map { $0.id } })
        UserDefaults.standard.set(Array(readIDs.intersection(known)), forKey: Keys.read)
    }

    /// Kid IDs of a membership that a notice is about: those in its group, or all of them for the whole daycare.
    func kidIDs(for notice: DaycareNotice, in membership: Membership) -> [UUID] {
        membership.kidGroups.compactMap { kid, group -> UUID? in
            guard notice.groupID == nil || notice.groupID == group else { return nil }
            return UUID(uuidString: kid)
        }
    }

    func isWatching(_ notice: DaycareNotice, kidID: UUID) -> Bool {
        (watches[watchKey(notice.id, kidID)] ?? .distantPast) > Date()
    }

    private func watchKey(_ noticeID: String, _ kidID: UUID) -> String {
        noticeID + "/" + kidID.uuidString
    }

    // MARK: - Watching

    /// Asks later whether each kid caught it; asking again for the same kids stops it.
    func toggleWatch(_ notice: DaycareNotice, kids: [Kid], germ: Germ) {
        let watching = kids.allSatisfy { isWatching(notice, kidID: $0.id) }
        for kid in kids {
            let key = watchKey(notice.id, kid.id)
            NotificationManager.cancelDaycareWatch(noticeID: notice.id, kidID: kid.id)
            if watching {
                watches[key] = nil
            } else {
                let due = NotificationManager.daycareWatchDate(noticeDate: notice.date, germ: germ)
                NotificationManager.scheduleDaycareWatch(noticeID: notice.id, kid: kid, germ: germ, at: due)
                watches[key] = due
            }
        }
        saveWatches()
    }

    private func saveWatches() {
        watches = watches.filter { $0.value > Date() }
        UserDefaults.standard.set(watches, forKey: Keys.watches)
    }

    private func cancelWatches(of membership: Membership) {
        let noticeIDs = Set(membership.feed.notices.map { $0.id })
        for key in watches.keys {
            let parts = key.split(separator: "/").map(String.init)
            guard parts.count == 2, noticeIDs.contains(parts[0]), let kid = UUID(uuidString: parts[1]) else { continue }
            NotificationManager.cancelDaycareWatch(noticeID: parts[0], kidID: kid)
            watches[key] = nil
        }
        saveWatches()
    }

    // MARK: - Requests

    private func client(_ token: String?) throws -> CrewClient {
        guard let url = AppConfig.serverURL else { throw CrewAPIError(code: "offline") }
        return CrewClient(baseURL: url, token: token)
    }

    /// Runs one request; a quiet one keeps errors off the screen.
    private func run(quiet: Bool = false, onUnauthorized: () -> Void = {}, message: (CrewAPIError) -> String = { $0.daycareMessage },
                     _ work: () async throws -> Void) async -> Bool {
        operations += 1
        defer { operations -= 1 }
        do {
            try await work()
            if !quiet { errorMessage = nil }
            isStale = false
            return true
        } catch let error as CrewAPIError {
            if error.code == "unauthorized" { onUnauthorized() }
            if !quiet || error.code == "unauthorized" { errorMessage = message(error) }
            if quiet, error.code == "offline" { isStale = true }
            return false
        } catch {
            if !quiet { errorMessage = tr("Something went wrong. Try again.") }
            return false
        }
    }

    private func saveMemberships() {
        UserDefaults.standard.set(try? JSONEncoder().encode(memberships), forKey: Keys.memberships)
    }

    private func store(_ feed: DaycareFeed, kidGroups: [String: String]? = nil) {
        if let index = memberships.firstIndex(where: { $0.id == feed.daycare.id }) {
            memberships[index].feed = feed
            if let kidGroups { memberships[index].kidGroups = kidGroups }
        } else {
            memberships.append(Membership(feed: feed, kidGroups: kidGroups ?? [:]))
        }
        if !isDemo { saveMemberships() }
    }

    private func store(_ state: DirectorState) {
        director = state
        if !isDemo { UserDefaults.standard.set(try? JSONEncoder().encode(state), forKey: Keys.directorState) }
    }

    private func forget(_ membership: Membership) {
        cancelWatches(of: membership)
        Keychain.set(nil, for: Keys.parent(membership.id))
        memberships.removeAll { $0.id == membership.id }
        if !isDemo { saveMemberships() }
    }

    private func forgetDirector() {
        Keychain.set(nil, for: Keys.director)
        director = nil
        UserDefaults.standard.removeObject(forKey: Keys.directorState)
    }

    private static func groupIDs(_ kidGroups: [String: String]) -> [String] {
        Array(Set(kidGroups.values.filter { !$0.isEmpty })).sorted()
    }

    /// The daycare a code belongs to, before joining it.
    func lookup(code: String) async -> DaycareInfo? {
        #if GERMILY_SIDELOAD
        if isDemo { return Self.demoInfo }
        #endif
        var found: DaycareInfo?
        let encoded = code.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? code
        _ = await run {
            let result: Lookup = try await self.client(nil).get("v1/daycares/" + encoded)
            found = result.daycare
        }
        return found
    }

    func join(code: String, kidGroups: [String: String]) async -> Bool {
        #if GERMILY_SIDELOAD
        if isDemo {
            let info = Self.demoInfo
            let feed = DaycareFeed(daycare: info, groupIDs: Self.groupIDs(kidGroups), notices: Self.demoNotices)
            store(feed, kidGroups: kidGroups)
            return true
        }
        #endif
        let done = await run {
            let session: DaycareSession<DaycareFeed> = try await self.client(nil).send(
                "POST", "v1/daycare-subscriptions",
                JoinBody(code: code, groupIDs: Self.groupIDs(kidGroups), pushToken: self.pushToken, language: self.language))
            Keychain.set(session.token, for: Keys.parent(session.state.daycare.id))
            self.store(session.state, kidGroups: kidGroups)
            if self.pushToken != nil { self.markDelivered(session.state.daycare.id) }
        }
        if done { await PushRegistrar.register() }
        return done
    }

    func setGroups(_ membership: Membership, kidGroups: [String: String]) async -> Bool {
        #if GERMILY_SIDELOAD
        if isDemo {
            let feed = DaycareFeed(daycare: membership.feed.daycare, groupIDs: Self.groupIDs(kidGroups),
                                   notices: membership.feed.notices)
            store(feed, kidGroups: kidGroups)
            return true
        }
        #endif
        let token = Keychain.get(Keys.parent(membership.id))
        return await run(onUnauthorized: { self.forget(membership) }) {
            let feed: DaycareFeed = try await self.client(token).send(
                "POST", "v1/daycare-subscription", GroupsBody(groupIDs: Self.groupIDs(kidGroups)))
            self.store(feed, kidGroups: kidGroups)
        }
    }

    /// Stops the notices and deletes the subscription from the server.
    func leave(_ membership: Membership) async -> Bool {
        #if GERMILY_SIDELOAD
        if isDemo {
            forget(membership)
            return true
        }
        #endif
        let token = Keychain.get(Keys.parent(membership.id))
        let done = await run(onUnauthorized: { self.forget(membership) }) {
            try await self.client(token).delete("v1/daycare-subscription")
        }
        if done { forget(membership) }
        return done
    }

    func report(_ notice: DaycareNotice, in membership: Membership) async -> Bool {
        #if GERMILY_SIDELOAD
        if isDemo {
            let feed = DaycareFeed(daycare: membership.feed.daycare, groupIDs: membership.feed.groupIDs,
                                   notices: membership.feed.notices.filter { $0.id != notice.id })
            store(feed)
            return true
        }
        #endif
        let token = Keychain.get(Keys.parent(membership.id))
        return await run(onUnauthorized: { self.forget(membership) }) {
            let feed: DaycareFeed = try await self.client(token).send(
                "POST", "v1/daycare-subscription/reports", ReportBody(noticeID: notice.id))
            self.store(feed)
        }
    }

    func refresh() async {
        guard isConfigured else { return }
        for membership in memberships {
            let token = Keychain.get(Keys.parent(membership.id))
            _ = await run(quiet: true, onUnauthorized: { self.forget(membership) }) {
                let feed: DaycareFeed = try await self.client(token).get("v1/daycare-subscription")
                self.store(feed)
            }
        }
        if director != nil {
            let token = Keychain.get(Keys.director)
            _ = await run(quiet: true, onUnauthorized: { self.forgetDirector() }) {
                let state: DirectorState = try await self.client(token).get("v1/daycare")
                self.store(state)
            }
        }
        await deliverPush()
    }

    /// Keeps the address for notifications; a new one goes to every followed daycare again.
    func setPushToken(_ token: String) async {
        if token != pushToken {
            pushToken = token
            pushDelivered = []
            UserDefaults.standard.set(token, forKey: Keys.pushToken)
            UserDefaults.standard.set([String](), forKey: Keys.pushDelivered)
        }
        await deliverPush()
    }

    /// Sends the address to the followed daycares that don't have it yet; the rest wait for the next refresh.
    private func deliverPush() async {
        guard isConfigured, let token = pushToken else { return }
        for membership in memberships where !pushDelivered.contains(membership.id) {
            let session = Keychain.get(Keys.parent(membership.id))
            _ = await run(quiet: true, onUnauthorized: { self.forget(membership) }) {
                let feed: DaycareFeed = try await self.client(session).send(
                    "POST", "v1/daycare-subscription", PushBody(pushToken: token, language: self.language))
                self.store(feed)
                self.markDelivered(membership.id)
            }
        }
    }

    private func markDelivered(_ daycareID: String) {
        pushDelivered.insert(daycareID)
        UserDefaults.standard.set(Array(pushDelivered), forKey: Keys.pushDelivered)
    }

    /// Shows a notice opened from a notification, after fetching it if it is new.
    func open(noticeID: String) async {
        openedNoticeID = noticeID
        if notice(noticeID) == nil { await refresh() }
    }

    // MARK: - Running a daycare

    func create(name: String, groups: [String], email: String?) async -> Bool {
        #if GERMILY_SIDELOAD
        if isDemo {
            let made = groups.map { DaycareGroup(id: UUID().uuidString, name: $0, families: 0) }
            store(DirectorState(daycare: DirectorDaycare(id: "demo-daycare", name: name, code: "PTPO7K2Q", email: email,
                                                         inbox: nil, families: 0, groups: made), notices: []))
            return true
        }
        #endif
        return await run {
            let session: DaycareSession<DirectorState> = try await self.client(nil).send(
                "POST", "v1/daycares",
                CreateBody(name: name, groups: groups.map { GroupInput(id: nil, name: $0) }, email: email,
                           language: self.language))
            Keychain.set(session.token, for: Keys.director)
            self.store(session.state)
        }
    }

    /// Renames the daycare, replaces its groups or its sending address; a group keeps its ID when renamed,
    /// and an ID the server doesn't know makes a new group.
    func update(name: String? = nil, groups: [DaycareGroup]? = nil, email: String? = nil) async -> Bool {
        #if GERMILY_SIDELOAD
        if isDemo, let current = director {
            let daycare = current.daycare
            let kept = groups.map { list in
                list.map { DaycareGroup(id: $0.id, name: $0.name, families: $0.families ?? 0) }
            }
            store(DirectorState(daycare: DirectorDaycare(id: daycare.id, name: name ?? daycare.name, code: daycare.code,
                                                         email: email ?? daycare.email, inbox: daycare.inbox,
                                                         families: daycare.families, groups: kept ?? daycare.groups),
                                notices: current.notices))
            return true
        }
        #endif
        let token = Keychain.get(Keys.director)
        let body = UpdateBody(name: name,
                              groups: groups?.map { GroupInput(id: $0.id, name: $0.name) },
                              email: email, language: language)
        return await run(onUnauthorized: { self.forgetDirector() }) {
            let state: DirectorState = try await self.client(token).send("POST", "v1/daycare", body)
            self.store(state)
        }
    }

    func send(germID: String, groupID: String?, note: String) async -> Bool {
        #if GERMILY_SIDELOAD
        if isDemo, let current = director {
            let reached = groupID.flatMap { id in current.daycare.groups.first { $0.id == id }?.families } ?? current.daycare.families
            let notice = DaycareNotice(id: UUID().uuidString, groupID: groupID, germID: germID, note: note,
                                       at: Date().timeIntervalSince1970 * 1000, recipients: reached, reports: 0)
            store(DirectorState(daycare: current.daycare, notices: [notice] + current.notices))
            return true
        }
        #endif
        let token = Keychain.get(Keys.director)
        return await run(onUnauthorized: { self.forgetDirector() }, message: { error in
            error.code == "rate_limited" ? tr("Ten notices a day at most. Try again tomorrow.") : error.daycareMessage
        }) {
            let state: DirectorState = try await self.client(token).send(
                "POST", "v1/daycare/notices", NoticeBody(germID: germID, groupID: groupID, note: note))
            self.store(state)
        }
    }

    /// Replaces the daycare's code: the old code and poster stop working, families already in stay.
    func renewCode() async -> Bool {
        #if GERMILY_SIDELOAD
        if isDemo, let current = director {
            let daycare = current.daycare
            let code = String((0..<DaycareCode.length).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
            store(DirectorState(daycare: DirectorDaycare(id: daycare.id, name: daycare.name, code: code, email: daycare.email,
                                                         inbox: daycare.inbox, families: daycare.families, groups: daycare.groups),
                                notices: current.notices))
            return true
        }
        #endif
        let token = Keychain.get(Keys.director)
        return await run(onUnauthorized: { self.forgetDirector() }, message: { error in
            error.code == "rate_limited" ? tr("Five new codes a day at most. Try again tomorrow.") : error.daycareMessage
        }) {
            let state: DirectorState = try await self.client(token).send("POST", "v1/daycare/code", EmptyBody())
            self.store(state)
        }
    }

    /// Deletes the daycare, its notices and its families' subscriptions from the server.
    func close() async -> Bool {
        #if GERMILY_SIDELOAD
        if isDemo {
            forgetDirector()
            return true
        }
        #endif
        let token = Keychain.get(Keys.director)
        let done = await run(onUnauthorized: { self.forgetDirector() }) {
            try await self.client(token).delete("v1/daycare")
        }
        if done { forgetDirector() }
        return done
    }

    // MARK: - Delete everything

    /// Removes everything this phone put on the server; false when the server can't be reached.
    func eraseServerData() async -> Bool {
        guard isConfigured else { return true }
        for membership in memberships {
            let left = await leave(membership)
            if !left, Keychain.get(Keys.parent(membership.id)) != nil { return false }
        }
        if director != nil {
            let closed = await close()
            if !closed, director != nil { return false }
        }
        return true
    }

    /// Clears what daycare notices keep on this phone.
    func resetLocal() {
        for membership in memberships { forget(membership) }
        forgetDirector()
        readIDs = []
        watches = [:]
        errorMessage = nil
        openedNoticeID = nil
        pushDelivered = []
        for key in [Keys.memberships, Keys.read, Keys.watches, Keys.pushDelivered] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

#if GERMILY_SIDELOAD
/// The sample daycare of a test build without a server: made-up notices, kept in memory only.
extension DaycareStore {
    static let demoInfo = DaycareInfo(
        id: "demo-petits-pois", name: "CPE Les Petits Pois",
        groups: [DaycareGroup(id: "demo-g1", name: "Poupons"), DaycareGroup(id: "demo-g2", name: "Trottineurs"),
                 DaycareGroup(id: "demo-g3", name: "Grands")],
        families: 42)

    static var demoNotices: [DaycareNotice] {
        let now = Date().timeIntervalSince1970 * 1000
        let hour = 3_600_000.0
        return [
            DaycareNotice(id: "demo-notice-1", groupID: "demo-g2", germID: "noro",
                          note: tr("3 children went home sick this morning."),
                          at: now - 2 * hour),
            DaycareNotice(id: "demo-notice-2", groupID: nil, germID: "pinky", note: "", at: now - 9 * 24 * hour)
        ]
    }

    static func demoMembership() -> Membership {
        let kid = AppModel.shared.data.kids.first.map { [$0.id.uuidString: "demo-g2"] } ?? [householdKey: "demo-g2"]
        return Membership(feed: DaycareFeed(daycare: demoInfo, groupIDs: ["demo-g2"], notices: demoNotices), kidGroups: kid)
    }
}
#endif

import Foundation

/// What reading the journal file produced.
enum JournalLoad {
    case missing
    case loaded(AppData)
    /// The file exists but cannot be read right now, for example before the first unlock.
    case unavailable
    /// The file could not be decoded and was renamed so nothing overwrites it.
    case setAside
}

/// A backup file: the journal's keys, and the photos it lists as JPEG data keyed by photo id.
struct Backup: Codable {
    let data: AppData
    let photoFiles: [UUID: Data]

    private enum CodingKeys: String, CodingKey {
        case photoFiles
    }

    init(data: AppData, photoFiles: [UUID: Data]) {
        self.data = data
        self.photoFiles = photoFiles
    }

    init(from decoder: Decoder) throws {
        data = try AppData(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let stored = container.value(.photoFiles, default: [String: Data]())
        var files: [UUID: Data] = [:]
        for (key, value) in stored {
            if let id = UUID(uuidString: key) { files[id] = value }
        }
        photoFiles = files
    }

    func encode(to encoder: Encoder) throws {
        try data.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        let files = Dictionary(uniqueKeysWithValues: photoFiles.map { ($0.key.uuidString, $0.value) })
        try container.encode(files, forKey: .photoFiles)
    }
}

/// Reads and writes the journal as one protected JSON file on the device.
enum Persistence {
    private static let setAsidePrefix = "journal-unreadable-"

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Germigo", isDirectory: true)
    }

    private static var fileURL: URL {
        directory.appendingPathComponent("journal.json")
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    /// Reads the journal. A file that cannot be decoded is set aside, never overwritten.
    static func load() -> JournalLoad {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .missing }
        guard let raw = try? Data(contentsOf: fileURL) else { return .unavailable }
        if let data = try? decoder.decode(AppData.self, from: raw) { return .loaded(data) }
        let stamp = Int(Date().timeIntervalSince1970)
        let copy = directory.appendingPathComponent(setAsidePrefix + String(stamp) + ".json")
        guard (try? FileManager.default.moveItem(at: fileURL, to: copy)) != nil else { return .unavailable }
        return .setAside
    }

    @discardableResult
    static func save(_ data: AppData) -> Bool {
        do {
            let raw = try encoder.encode(data)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try raw.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    /// Journals that could not be read, most recent first.
    static var setAsideFiles: [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.filter { $0.hasPrefix(setAsidePrefix) }.sorted().reversed()
            .map { directory.appendingPathComponent($0) }
    }

    /// The journal as a backup file: the same format as on disk, plus the photo files under `photoFiles`.
    static func backupData(_ data: AppData, photos: [UUID: Data]) -> Data? {
        try? encoder.encode(Backup(data: data, photoFiles: photos))
    }

    /// Reads a backup; only a journal that went through onboarding counts as one.
    static func readBackup(_ raw: Data) -> Backup? {
        guard let backup = try? decoder.decode(Backup.self, from: raw), backup.data.onboardingDone else { return nil }
        return backup
    }

    static func erase() {
        try? FileManager.default.removeItem(at: fileURL)
        for url in setAsideFiles {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

/// The bundled germ catalog and articles, with the lessons of the online file.
struct GermCatalog {
    /// The germ that the Tissue Box icon counts.
    static let commonColdID = "rhino"
    /// The germ logged when nobody knows what it is yet.
    static let mysteryID = "mystery"

    let germs: [Germ]
    /// Lessons already out, in ladder order.
    let articles: [Article]
    /// Online lessons still waiting for their release day.
    let upcoming: [Article]
    private let bundled: [Article]
    private let byID: [String: Germ]

    init(germs: [Germ], articles: [Article], feed: [FeedLesson] = [], now: Date = Date()) {
        self.germs = germs.sorted { $0.number < $1.number }
        let all = LessonEngine.merge(bundled: articles, feed: feed).sorted { $0.unlockAtAnswers < $1.unlockAtAnswers }
        self.articles = all.filter { LessonEngine.isReleased($0, now: now) }
        self.upcoming = all.filter { !LessonEngine.isReleased($0, now: now) }
        self.bundled = articles
        self.byID = Dictionary(uniqueKeysWithValues: germs.map { ($0.id, $0) })
    }

    /// The same germs and bundled articles with another copy of the online file, as of a given time.
    func updated(feed: [FeedLesson], now: Date = Date()) -> GermCatalog {
        GermCatalog(germs: germs, articles: bundled, feed: feed, now: now)
    }

    func germ(_ id: String) -> Germ? {
        byID[id]
    }

    var quickPicks: [Germ] {
        germs.filter { $0.quickPick }
    }

    static func load(feed: [FeedLesson] = []) -> GermCatalog {
        GermCatalog(germs: decode("germs", as: [Germ].self) ?? [],
                    articles: decode("articles", as: [Article].self) ?? [], feed: feed)
    }

    private static func decode<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: raw)
    }
}

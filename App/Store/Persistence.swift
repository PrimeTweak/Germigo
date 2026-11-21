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

/// Reads and writes the journal as one protected JSON file on the device.
enum Persistence {
    private static let setAsidePrefix = "journal-unreadable-"

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Petri", isDirectory: true)
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

    /// The journal as a backup file, in the same format as on disk.
    static func backupData(_ data: AppData) -> Data? {
        try? encoder.encode(data)
    }

    /// Reads a backup; only a journal that went through onboarding counts as one.
    static func readBackup(_ raw: Data) -> AppData? {
        guard let data = try? decoder.decode(AppData.self, from: raw), data.onboardingDone else { return nil }
        return data
    }

    static func erase() {
        try? FileManager.default.removeItem(at: fileURL)
        for url in setAsideFiles {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

/// The bundled germ catalog and articles.
struct GermCatalog {
    /// The germ that the Tissue Box icon counts.
    static let commonColdID = "rhino"
    /// The germ logged when nobody knows what it is yet.
    static let mysteryID = "mystery"

    let germs: [Germ]
    let articles: [Article]
    private let byID: [String: Germ]

    init(germs: [Germ], articles: [Article]) {
        self.germs = germs.sorted { $0.number < $1.number }
        self.articles = articles.sorted { $0.unlockAtAnswers < $1.unlockAtAnswers }
        self.byID = Dictionary(uniqueKeysWithValues: germs.map { ($0.id, $0) })
    }

    func germ(_ id: String) -> Germ? {
        byID[id]
    }

    var quickPicks: [Germ] {
        germs.filter { $0.quickPick }
    }

    static func load() -> GermCatalog {
        GermCatalog(germs: decode("germs", as: [Germ].self) ?? [],
                    articles: decode("articles", as: [Article].self) ?? [])
    }

    private static func decode<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: raw)
    }
}

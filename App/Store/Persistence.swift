import Foundation

/// Reads and writes the journal as one protected JSON file on the device.
enum Persistence {
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

    static func load() -> AppData? {
        guard let raw = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(AppData.self, from: raw)
    }

    static func save(_ data: AppData) {
        guard let raw = try? encoder.encode(data) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? raw.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func erase() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

/// The bundled germ catalog and articles.
struct GermCatalog {
    let germs: [Germ]
    let articles: [Article]
    private let byID: [String: Germ]

    init(germs: [Germ], articles: [Article]) {
        self.germs = germs.sorted { $0.number < $1.number }
        self.articles = articles.sorted { $0.unlockAtGerms < $1.unlockAtGerms }
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

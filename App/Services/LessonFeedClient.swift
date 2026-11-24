import Foundation

/// Downloads the online Guide file and keeps the last copy that read correctly.
enum LessonFeedClient {
    /// A lesson file larger than this is ignored.
    private static let maxBytes = 1_000_000

    private enum Keys {
        static let checkedAt = "lessons.checkedAt"
        static let etag = "lessons.etag"
        static let modified = "lessons.lastModified"
    }

    private static var cacheURL: URL {
        Persistence.directory.appendingPathComponent("lessons.json")
    }

    /// The saved copy; empty while no address is set.
    static func cached() -> LessonFeed {
        guard AppConfig.lessonsURL != nil, let raw = try? Data(contentsOf: cacheURL) else { return .empty }
        return decode(raw) ?? .empty
    }

    /// Nil without an address or a network, when the file was checked within the hour or did not change,
    /// or when it does not read; the saved copy stays then.
    static func fetch(now: Date = Date()) async -> LessonFeed? {
        guard let url = AppConfig.lessonsURL else { return nil }
        let defaults = UserDefaults.standard
        let saved = FileManager.default.fileExists(atPath: cacheURL.path)
        guard !saved || LessonEngine.isCheckDue(lastCheck: defaults.object(forKey: Keys.checkedAt) as? Date, now: now) else {
            return nil
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        // With a saved copy, only a changed file is sent back; otherwise the host answers 304.
        if saved {
            request.setValue(defaults.string(forKey: Keys.etag), forHTTPHeaderField: "If-None-Match")
            request.setValue(defaults.string(forKey: Keys.modified), forHTTPHeaderField: "If-Modified-Since")
        }
        guard let result = try? await URLSession.shared.data(for: request),
              let http = result.1 as? HTTPURLResponse else { return nil }
        let data = result.0
        if http.statusCode == 304, saved {
            defaults.set(now, forKey: Keys.checkedAt)
            return nil
        }
        guard http.statusCode == 200, data.count <= maxBytes, let feed = decode(data) else { return nil }
        try? FileManager.default.createDirectory(at: Persistence.directory, withIntermediateDirectories: true)
        try? data.write(to: cacheURL, options: .atomic)
        defaults.set(now, forKey: Keys.checkedAt)
        defaults.set(http.value(forHTTPHeaderField: "ETag"), forKey: Keys.etag)
        defaults.set(http.value(forHTTPHeaderField: "Last-Modified"), forKey: Keys.modified)
        return feed
    }

    private static func decode(_ raw: Data) -> LessonFeed? {
        try? JSONDecoder().decode(LessonFeed.self, from: raw)
    }
}

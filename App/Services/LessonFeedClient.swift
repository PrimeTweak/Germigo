import Foundation

/// Downloads the online lesson file and keeps the last copy that read correctly.
enum LessonFeedClient {
    private static var cacheURL: URL {
        Persistence.directory.appendingPathComponent("lessons.json")
    }

    /// The saved copy; empty while no address is set.
    static func cached() -> [FeedLesson] {
        guard AppConfig.lessonsURL != nil, let raw = try? Data(contentsOf: cacheURL) else { return [] }
        return decode(raw) ?? []
    }

    /// Nil without an address, without a network, or when the file does not read; the saved copy stays then.
    static func fetch() async -> [FeedLesson]? {
        guard let url = AppConfig.lessonsURL else { return nil }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        guard let result = try? await URLSession.shared.data(for: request),
              (result.1 as? HTTPURLResponse)?.statusCode == 200,
              let lessons = decode(result.0) else { return nil }
        try? FileManager.default.createDirectory(at: Persistence.directory, withIntermediateDirectories: true)
        try? result.0.write(to: cacheURL, options: .atomic)
        return lessons
    }

    private static func decode(_ raw: Data) -> [FeedLesson]? {
        (try? JSONDecoder().decode(LessonFeed.self, from: raw))?.lessons
    }
}

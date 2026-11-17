import Foundation

/// The small slice of state the widgets need, written by the app.
struct WidgetSnapshot: Codable {
    struct Exposure: Codable {
        var kidName: String
        var germID: String
        var germName: String
        var illness: String
        var exposedAt: Date
        var windowOpens: Date
        var windowCloses: Date
    }

    var streakStart: Date?
    var recordDays: Int
    var sickGermID: String?
    var sickIllness: String?
    var sickSince: Date?
    var exposure: Exposure?
    var hasPass: Bool

    static let empty = WidgetSnapshot(streakStart: Date(), recordDays: 0, sickGermID: nil,
                                      sickIllness: nil, sickSince: nil, exposure: nil, hasPass: false)

    private static var fileURL: URL {
        AppGroup.containerURL.appendingPathComponent("widget-snapshot.json")
    }

    static func load() -> WidgetSnapshot {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? FileManager.default.createDirectory(at: AppGroup.containerURL, withIntermediateDirectories: true)
        try? data.write(to: Self.fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Whole days since the current streak started; zero while sick.
    func streakDays(at date: Date = Date()) -> Int {
        guard let start = streakStart else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        return max(0, days)
    }
}

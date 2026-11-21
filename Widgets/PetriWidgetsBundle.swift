import SwiftUI
import WidgetKit

@main
struct PetriWidgetsBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        IncubationWidget()
        ExposureLiveActivity()
    }
}

/// Colors shared by the widgets: the app's dark look and its one accent.
enum WidgetInk {
    static let ground = Color(hex: Swatch.navy)
    static let ink = Color(hex: Swatch.frost)
    static let accent = Color(hex: Swatch.irisSoft)
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads the snapshot the app wrote and schedules the moments the display changes.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: Date(), snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load()
        let calendar = Calendar.current
        let now = Date()
        var dates = [now]
        for offset in 1...3 {
            if let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) {
                dates.append(day)
            }
        }
        if let exposure = snapshot.exposure {
            dates.append(contentsOf: [exposure.windowOpens, exposure.windowCloses].filter { $0 > now })
        }
        let entries = dates.sorted().map { SnapshotEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

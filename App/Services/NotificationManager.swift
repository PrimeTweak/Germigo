import ActivityKit
import BackgroundTasks
import Foundation
import UserNotifications

/// Local notifications: incubation check-ins, the daily sick check-in, crew radar alerts.
enum NotificationManager {
    private static let sickID = "sick-checkin"

    private static var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func scheduleExposure(illness: KidIllness, kidName: String, germ: Germ, settings: AppSettings) {
        cancelExposure(id: illness.id)
        guard settings.checkInsOn, let window = germ.window(from: illness.startedAt) else { return }
        let now = Date()
        let opens = adjusted(window.opens, settings: settings)
        if opens > now {
            add(id: exposureKey(illness.id, "open"),
                title: tr("%@ watch", germ.name),
                body: tr("%1$@ has %2$@. Your window opens now. Still fine?", kidName, germ.illness.value),
                at: opens)
        }
        let closes = adjusted(window.closes, settings: settings)
        if closes > now {
            add(id: exposureKey(illness.id, "close"),
                title: tr("Window closed"),
                body: tr("The usual window for %@ has passed. Did you dodge it?", germ.illness.value),
                at: closes)
        }
    }

    static func cancelExposure(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [exposureKey(id, "open"), exposureKey(id, "close")])
    }

    static func scheduleSickCheckIn(settings: AppSettings) {
        cancelSickCheckIn()
        guard settings.checkInsOn else { return }
        var minute = 9 * 60
        if isQuiet(minute, settings: settings) { minute = settings.quietEndMinute }
        let content = UNMutableNotificationContent()
        content.title = tr("Still under the weather?")
        content.body = tr("Tap \"I'm better\" when the germ is gone. The counter is waiting.")
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: minute / 60, minute: minute % 60), repeats: true)
        center.add(UNNotificationRequest(identifier: sickID, content: content, trigger: trigger))
    }

    static func cancelSickCheckIn() {
        center.removePendingNotificationRequests(withIdentifiers: [sickID])
    }

    static func notifyRadar(illness: String, crewName: String, families: Int) {
        add(id: "radar-" + UUID().uuidString,
            title: tr("Going around %@", crewName),
            body: tr("%1$@: %2$lld families this week.", illness, families),
            at: Date().addingTimeInterval(2))
    }

    private static func exposureKey(_ id: UUID, _ suffix: String) -> String {
        "exposure-" + id.uuidString + "-" + suffix
    }

    private static func add(id: String, title: String, body: String, at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func isQuiet(_ minute: Int, settings: AppSettings) -> Bool {
        guard settings.quietHoursOn else { return false }
        let start = settings.quietStartMinute
        let end = settings.quietEndMinute
        if start == end { return false }
        return start < end ? (minute >= start && minute < end) : (minute >= start || minute < end)
    }

    /// Moves a date that falls inside quiet hours to the end of the quiet period.
    private static func adjusted(_ date: Date, settings: AppSettings) -> Date {
        let calendar = Calendar.current
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        guard isQuiet(minute, settings: settings) else { return date }
        let end = DateComponents(hour: settings.quietEndMinute / 60, minute: settings.quietEndMinute % 60)
        return calendar.nextDate(after: date, matching: end, matchingPolicy: .nextTime) ?? date
    }
}

/// Starts and stops the incubation Live Activity.
enum LiveActivityManager {
    static func start(illness: KidIllness, kidName: String, germ: Germ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let window = germ.window(from: illness.startedAt), window.closes > Date() else { return }
        let attributes = ExposureActivityAttributes(
            exposureID: illness.id.uuidString, kidName: kidName, germID: germ.id, germName: germ.name,
            illness: germ.illness.value, exposedAt: illness.startedAt,
            windowOpens: window.opens, windowCloses: window.closes)
        let content = ActivityContent(state: ExposureActivityAttributes.ContentState(), staleDate: window.closes)
        _ = try? Activity<ExposureActivityAttributes>.request(attributes: attributes, content: content, pushType: nil)
    }

    static func end(exposureID: UUID) {
        let key = exposureID.uuidString
        Task {
            for activity in Activity<ExposureActivityAttributes>.activities where activity.attributes.exposureID == key {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}

/// Asks iOS for occasional background time to check the crew radar.
enum BackgroundRefresh {
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: AppConfig.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}

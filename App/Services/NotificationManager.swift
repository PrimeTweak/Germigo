import ActivityKit
import BackgroundTasks
import Foundation
import UserNotifications

/// Local notifications: incubation check-ins, the daily sick check-in, new lessons, crew radar alerts, daycare watches.
enum NotificationManager {
    private static let sickID = "sick-checkin"
    private static let milestoneID = "streak-milestone"
    private static let wrappedID = "season-wrapped"
    private static let monthID = "month-recap"
    private static let trialID = "trial-ending"

    /// The morning check-in comes this many days in a row, then stops on its own.
    private static let sickCheckInDays = 7

    /// Lessons announced ahead, soonest first; the rest wait for the next refresh.
    private static let lessonLimit = 8

    /// How long a mystery germ waits before Germily asks about new symptoms.
    private static let symptomCheckDelay: TimeInterval = 2 * 24 * 3600
    private static let presenter = ForegroundPresenter()

    private static var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }

    /// Key of the exposure a check-in is about, in the reminder's user info.
    static let exposureInfoKey = "exposureID"

    /// Keys of a daycare watch and of a daycare notice sent by push, in the user info.
    static let kidInfoKey = "kidID"
    static let germInfoKey = "germID"
    static let noticeInfoKey = "noticeID"

    /// Lets reminders show as banners while the app is open, and gives them their buttons.
    /// A button that changes the journal needs the phone unlocked.
    static func install() {
        center.delegate = presenter
        let better = UNNotificationAction(identifier: ReminderAction.better, title: tr("I'm better"), options: [.authenticationRequired])
        let stillSick = UNNotificationAction(identifier: ReminderAction.stillSick, title: tr("Still sick"), options: [])
        let caught = UNNotificationAction(identifier: ReminderAction.caught, title: tr("It got me"), options: [.foreground])
        let stillFine = UNNotificationAction(identifier: ReminderAction.stillFine, title: tr("Still fine"),
                                             options: [.authenticationRequired])
        let dodged = UNNotificationAction(identifier: ReminderAction.dodged, title: tr("Dodged it"), options: [.authenticationRequired])
        let kidCaught = UNNotificationAction(identifier: ReminderAction.kidCaught, title: tr("Caught it"), options: [.foreground])
        let allGood = UNNotificationAction(identifier: ReminderAction.allGood, title: tr("All good"), options: [])
        let categories = [
            (ReminderCategory.sick, [better, stillSick]),
            (ReminderCategory.windowOpens, [caught, stillFine]),
            (ReminderCategory.windowCloses, [dodged, caught]),
            (ReminderCategory.daycareWatch, [kidCaught, allGood])
        ]
        center.setNotificationCategories(Set(categories.map { id, actions in
            UNNotificationCategory(identifier: id, actions: actions, intentIdentifiers: [], options: [])
        }))
    }

    static func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Asks once; afterwards reports what the parent decided.
    static func ensureAuthorization() async -> Bool {
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return await requestAuthorization()
        case .denied: return false
        default: return true
        }
    }

    static func isDenied() async -> Bool {
        await center.notificationSettings().authorizationStatus == .denied
    }

    static func scheduleExposure(illness: KidIllness, germ: Germ, settings: AppSettings) {
        cancelExposure(id: illness.id)
        guard settings.checkInsOn, let window = germ.window(from: illness.startedAt) else { return }
        let now = Date()
        let opens = adjusted(window.opens)
        let info = [exposureInfoKey: illness.id.uuidString]
        if opens > now {
            add(id: exposureKey(illness.id, "open"),
                title: tr("%@ watch", germ.name),
                body: tr("Your window for %@ opens now. Still fine?", germ.illness.value),
                at: opens, category: ReminderCategory.windowOpens, info: info)
        }
        let closes = adjusted(window.closes)
        if closes > now {
            add(id: exposureKey(illness.id, "close"),
                title: tr("Window closed"),
                body: tr("The usual window for %@ has passed. Did you dodge it?", germ.illness.value),
                at: closes, category: ReminderCategory.windowCloses, info: info)
        }
    }

    static func cancelExposure(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [exposureKey(id, "open"), exposureKey(id, "close")])
    }

    static func scheduleSickCheckIn(settings: AppSettings, germ: Germ?, startedAt: Date) {
        cancelSickCheckIn()
        guard settings.checkInsOn else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let firstDay = calendar.startOfDay(for: startedAt)
        for offset in 1...sickCheckInDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayNumber = (calendar.dateComponents([.day], from: firstDay, to: day).day ?? 0) + 1
            let content = UNMutableNotificationContent()
            content.title = tr("Still under the weather?")
            content.body = tr("Tap \"I'm better\" when the germ is gone. The counter is waiting.")
            if let germ {
                content.subtitle = tr("Day %1$lld · %2$@", dayNumber, germ.illness.value)
                content.body = dailyAdvice(germ: germ, day: dayNumber)
            }
            content.sound = .default
            content.categoryIdentifier = ReminderCategory.sick
            var parts = calendar.dateComponents([.year, .month, .day], from: day)
            parts.hour = 9
            parts.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            center.add(UNNotificationRequest(identifier: sickKey(offset), content: content, trigger: trigger))
        }
    }

    /// One piece of the germ's Field Notes per day: each tip in turn, then when to call.
    static func dailyAdvice(germ: Germ, day: Int) -> String {
        let items = germ.tips.map { tip -> String in
            let title = tip.title.value
            let joint = title.hasSuffix("?") || title.hasSuffix("!") || title.hasSuffix(".") ? " " : ". "
            return title + joint + tip.body.value
        } + [germ.doctor.value]
        return items[(max(1, day) - 1) % items.count]
    }

    static func scheduleMilestone(days: Int, on day: Date, settings: AppSettings) {
        cancelMilestone()
        guard settings.checkInsOn else { return }
        addMorning(id: milestoneID, on: day,
                   title: trCount(days, one: "%lld day without a germ", other: "%lld days without a germ"),
                   body: tr("Milestone reached. Open Germily to frame it."))
    }

    static func cancelMilestone() {
        center.removePendingNotificationRequests(withIdentifiers: [milestoneID])
    }

    /// The reminder promised on the offer: two days before a free trial ends, whatever the check-in settings.
    static func scheduleTrialReminder(endsAt: Date) {
        cancelTrialReminder()
        guard let date = TrialPlan.reminderDate(endsAt: endsAt, now: Date()) else { return }
        add(id: trialID, title: trCount(TrialPlan.notice, one: "Your free trial ends in %lld day", other: "Your free trial ends in %lld days"),
            body: tr("Keep the Season Pass, or cancel it in your App Store subscriptions."), at: adjusted(date))
    }

    static func cancelTrialReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [trialID])
    }

    static func scheduleWrapped(at date: Date, settings: AppSettings) {
        center.removePendingNotificationRequests(withIdentifiers: [wrappedID])
        guard settings.checkInsOn else { return }
        addMorning(id: wrappedID, on: date, title: tr("Your season recap"),
                   body: tr("The numbers are in. Brace yourself."))
    }

    /// On the first morning of the next month, when the month had something to tell.
    static func scheduleMonthRecap(month: String, on day: Date, settings: AppSettings) {
        cancelMonthRecap()
        guard settings.checkInsOn else { return }
        addMorning(id: monthID, on: day, title: tr("Your %@ recap", month), body: tr("Your month recap is ready in Season."))
    }

    static func cancelMonthRecap() {
        center.removePendingNotificationRequests(withIdentifiers: [monthID])
    }

    static func cancelStreakReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [milestoneID, wrappedID, monthID])
    }

    static func cancelSickCheckIn() {
        center.removePendingNotificationRequests(withIdentifiers: [sickID] + (1...sickCheckInDays).map(sickKey))
    }

    private static func sickKey(_ offset: Int) -> String {
        sickID + "-" + String(offset)
    }

    /// One question two days into a mystery germ: a new sign could name it.
    static func scheduleSymptomCheck(id: UUID, name: String?, startedAt: Date, settings: AppSettings) {
        cancelSymptomCheck(id: id)
        let due = adjusted(startedAt.addingTimeInterval(symptomCheckDelay))
        guard settings.checkInsOn, due > Date() else { return }
        let body = name.map { tr("%@'s mystery bug is 2 days old. A new sign could name it.", $0) }
            ?? tr("Your mystery bug is 2 days old. A new sign could name it.")
        add(id: symptomKey(id), title: tr("Any new symptoms?"), body: body, at: due)
    }

    static func cancelSymptomCheck(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [symptomKey(id)])
    }

    private static func symptomKey(_ id: UUID) -> String {
        "symptoms-" + id.uuidString
    }

    /// One announcement at 10 AM on each upcoming lesson's release day.
    static func scheduleLessons(_ upcoming: [Article], known: [String], settings: AppSettings) {
        center.removePendingNotificationRequests(withIdentifiers: known.map(lessonKey))
        guard settings.lessonAlertsOn else { return }
        let dated = upcoming.compactMap { article in article.releasedOn.map { (article, $0) } }
            .sorted { $0.1 < $1.1 }
        for (article, day) in dated.prefix(lessonLimit) {
            let title = article.title.value
            let joint = title.hasSuffix("?") || title.hasSuffix("!") || title.hasSuffix(".") ? " " : ". "
            addMorning(id: lessonKey(article.id), on: day, title: tr("New lesson in the Guide"),
                       body: title + joint + tr("Open to everyone this week."))
        }
    }

    private static func lessonKey(_ id: String) -> String {
        "lesson-" + id
    }

    /// When the usual window after a daycare notice closes, or two days after it for a germ without one.
    static func daycareWatchDate(noticeDate: Date, germ: Germ) -> Date {
        let closes = germ.window(from: noticeDate)?.closes ?? noticeDate.addingTimeInterval(2 * 24 * 3600)
        return adjusted(max(closes, Date().addingTimeInterval(3600)))
    }

    /// One question about a kid after a daycare notice: caught it or not.
    static func scheduleDaycareWatch(noticeID: String, kid: Kid, germ: Germ, at date: Date) {
        add(id: daycareWatchKey(noticeID, kid.id),
            title: tr("Did %@ catch it?", kid.name),
            body: tr("%1$@ was going around the daycare. Tap Caught it to add it to %2$@'s history.", germ.illness.value, kid.name),
            at: date, category: ReminderCategory.daycareWatch,
            info: [kidInfoKey: kid.id.uuidString, germInfoKey: germ.id])
    }

    static func cancelDaycareWatch(noticeID: String, kidID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [daycareWatchKey(noticeID, kidID)])
    }

    private static func daycareWatchKey(_ noticeID: String, _ kidID: UUID) -> String {
        "daycare-" + noticeID + "-" + kidID.uuidString
    }

    static func notifyRadar(illness: String, crewName: String, families: Int) {
        add(id: "radar-" + UUID().uuidString,
            title: tr("Going around %@", crewName),
            body: tr("%1$@: %2$lld families this week.", illness, families),
            at: Date().addingTimeInterval(2))
    }

    /// A reminder at 10 AM on the given day.
    private static func addMorning(id: String, on day: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: day)
        parts.hour = 10
        parts.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func exposureKey(_ id: UUID, _ suffix: String) -> String {
        "exposure-" + id.uuidString + "-" + suffix
    }

    private static func add(id: String, title: String, body: String, at date: Date, category: String? = nil,
                            info: [String: String] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = info
        if let category {
            content.categoryIdentifier = category
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Moves a date that falls in the quiet hours to the next morning.
    private static func adjusted(_ date: Date) -> Date {
        guard QuietHours.contains(date) else { return date }
        let morning = DateComponents(hour: QuietHours.endMinute / 60, minute: QuietHours.endMinute % 60)
        return Calendar.current.nextDate(after: date, matching: morning, matchingPolicy: .nextTime) ?? date
    }
}

enum ReminderCategory {
    static let sick = "sick-day"
    static let windowOpens = "window-opens"
    static let windowCloses = "window-closes"
    static let daycareWatch = "daycare-watch"
}

enum ReminderAction {
    static let better = "better"
    static let stillSick = "still-sick"
    static let caught = "caught"
    static let stillFine = "still-fine"
    static let dodged = "dodged"
    static let kidCaught = "kid-caught"
    static let allGood = "all-good"
}

/// Shows a reminder as a banner while the app is on screen, and runs the buttons under it.
final class ForegroundPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.content.userInfo[NotificationManager.noticeInfoKey] is String {
            Task { @MainActor in
                await DaycareStore.shared.refresh()
            }
        }
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let noticeID = info[NotificationManager.noticeInfoKey] as? String {
            Task { @MainActor in
                AppModel.shared.selectedTab = .crew
                await DaycareStore.shared.open(noticeID: noticeID)
                completionHandler()
            }
            return
        }
        let exposureID = info[NotificationManager.exposureInfoKey] as? String
        let action: IntentAction?
        switch response.actionIdentifier {
        case ReminderAction.better: action = .better
        case ReminderAction.caught: action = exposureID.map { IntentAction.caught(exposureID: $0) }
        case ReminderAction.stillFine: action = exposureID.map { IntentAction.stillFine(exposureID: $0) }
        case ReminderAction.dodged: action = exposureID.map { IntentAction.dodged(exposureID: $0) }
        case ReminderAction.kidCaught:
            if let kidID = info[NotificationManager.kidInfoKey] as? String,
               let germID = info[NotificationManager.germInfoKey] as? String {
                action = .kidCaught(kidID: kidID, germID: germID)
            } else {
                action = nil
            }
        default: action = nil
        }
        guard let action else {
            completionHandler()
            return
        }
        Task { @MainActor in
            await IntentRelay.handler?(action)
            completionHandler()
        }
    }
}

/// Starts and stops the incubation Live Activity.
enum LiveActivityManager {
    /// iOS ends a Live Activity after eight hours, so it only covers the end of a window.
    static let maximumLead: TimeInterval = 8 * 3600

    static func start(illness: KidIllness, kidName: String, germ: Germ) {
        let key = illness.id.uuidString
        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let window = germ.window(from: illness.startedAt),
              window.closes > Date(), window.closes.timeIntervalSinceNow <= maximumLead,
              !Activity<ExposureActivityAttributes>.activities.contains(where: { $0.attributes.exposureID == key })
        else { return }
        let attributes = ExposureActivityAttributes(
            exposureID: key, kidName: kidName, germID: germ.id, germName: germ.name,
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

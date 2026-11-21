import UIKit

/// Gets the address Apple gives this phone for daycare notices, and hands it to the daycare store.
@MainActor
final class PushRegistrar: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if DaycareStore.shared.needsPush {
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task {
            await DaycareStore.shared.setPushToken(token)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    /// Asks for notification permission once, then for the address. The address is asked for either way,
    /// so notices arrive as soon as notifications are turned on.
    static func register() async {
        guard DaycareStore.shared.isConfigured else { return }
        _ = await NotificationManager.ensureAuthorization()
        UIApplication.shared.registerForRemoteNotifications()
    }
}

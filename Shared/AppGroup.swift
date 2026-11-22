import Foundation

/// Storage shared between the app and its widget extension.
enum AppGroup {
    static let identifier = "group.ca.germily.app"

    /// Falls back to the local container when the group entitlement is missing.
    static var containerURL: URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return url
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}

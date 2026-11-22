import Foundation
import Security

/// Build-time configuration read from Info.plist.
enum AppConfig {
    static let refreshTaskID = "ca.germily.app.refresh"

    private static func string(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.contains(".invalid") else { return nil }
        return value
    }

    /// Nil until a real server address replaces the placeholder.
    static var serverURL: URL? {
        guard let raw = string("GermilyServerURL") else { return nil }
        return URL(string: raw)
    }

    /// Where the QR code of a share card leads; nil until a real https address replaces the placeholder.
    static var shareURL: URL? {
        guard let raw = string("GermilyShareURL"), raw.hasPrefix("https://") else { return nil }
        return URL(string: raw)
    }

    /// The online lesson file; nil until a real https address replaces the placeholder.
    static var lessonsURL: URL? {
        guard let raw = string("GermilyLessonsURL"), raw.hasPrefix("https://") else { return nil }
        return URL(string: raw)
    }

    static var supportEmail: String? {
        string("GermilySupportEmail")
    }

    /// Instagram requires a Meta app ID to open its Stories composer; nil hides that button.
    static var metaAppID: String? {
        string("GermilyMetaAppID")
    }

    /// The person or company that publishes the app, named in the legal pages.
    static var publisherName: String? {
        string("GermilyPublisherName")
    }

    static var crewEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "GermilyCrewEnabled") as? Bool) ?? true
    }

    /// Shows notices by email to directors; turn it on only once the server has an inbound address.
    static var emailNoticesEnabled: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "GermilyEmailNoticesEnabled") as? Bool) ?? false
    }

    static var privacyURL: URL? {
        serverURL?.appendingPathComponent("privacy")
    }

    static var termsURL: URL? {
        serverURL?.appendingPathComponent("terms")
    }

    static var healthDataURL: URL? {
        serverURL?.appendingPathComponent("health-data")
    }

    static var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "\(version) (\(build))"
    }
}

/// Keychain storage for the crew and daycare session tokens.
enum Keychain {
    private static let service = "ca.germily.app"

    private static func baseQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    static func set(_ value: String?, for key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
        guard let value, let data = value.data(using: .utf8) else { return }
        var query = baseQuery(key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

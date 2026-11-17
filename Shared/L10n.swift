import Foundation

/// Looks up a user-facing string; the key is the English text.
func tr(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, comment: "")
    if args.isEmpty { return format }
    return String(format: format, locale: Locale.current, arguments: args)
}

/// Picks the singular or plural key for a count.
func trCount(_ count: Int, one: String, other: String) -> String {
    let singular = AppLanguage.isFrench ? count < 2 : count == 1
    return tr(singular ? one : other, count)
}

enum AppLanguage {
    static var isFrench: Bool {
        Bundle.main.preferredLocalizations.first?.hasPrefix("fr") ?? false
    }
}

/// A string stored in both languages inside bundled content.
struct LocalizedText: Codable, Hashable {
    let en: String
    let fr: String

    var value: String { AppLanguage.isFrench ? fr : en }
}

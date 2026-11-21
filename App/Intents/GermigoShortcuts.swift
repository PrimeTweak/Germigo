import AppIntents

/// Opens Germigo on the log sheet.
struct LogGermIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a germ"
    static let description = IntentDescription("Opens Germigo so you can log the germ you caught.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let model = AppModel.shared
        if model.data.onboardingDone {
            model.selectedTab = .today
            model.logRequest = LogRequest()
        }
        return .result()
    }
}

/// Says how long the household has gone without a germ.
struct GermFreeDaysIntent: AppIntent {
    static let title: LocalizedStringResource = "Days without a germ"
    static let description = IntentDescription("Tells you how long your household has gone without a germ.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let days = AppModel.shared.streakDays()
        let text = trCount(days, one: "%lld day without a germ.", other: "%lld days without a germ.")
        return .result(dialog: IntentDialog(stringLiteral: text))
    }
}

struct GermigoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogGermIntent(),
                    phrases: ["Log a germ in \(.applicationName)", "I'm sick in \(.applicationName)"],
                    shortTitle: "Log a germ",
                    systemImageName: "thermometer.medium")
        AppShortcut(intent: GermFreeDaysIntent(),
                    phrases: ["Days without a germ in \(.applicationName)"],
                    shortTitle: "Days without a germ",
                    systemImageName: "calendar")
    }
}

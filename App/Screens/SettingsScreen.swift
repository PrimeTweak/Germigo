import StoreKit
import SwiftUI

/// A settings row label.
struct SettingsLabel: View {
    let title: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(title)
            .foregroundStyle(palette.ink)
    }
}

/// The trailing arrow of a row that opens something but is not a navigation link.
struct RowChevron: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.inkTertiary)
            .accessibilityHidden(true)
    }
}

/// The gear in the top-right corner of every tab; it opens Settings.
struct SettingsButton: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            model.showSettings = true
        } label: {
            Image(systemName: "gearshape")
        }
        .accessibilityLabel(tr("Settings"))
    }
}

/// Settings, opened from any tab: the pass, the look, notifications and the rest.
struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.palette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var notificationsDenied = false
    @State private var restoreMessage: String?
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            List {
                Group {
                    passSection
                    lookSection
                    notificationSection
                    moreSection
                }
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(palette.background.ignoresSafeArea())
            .tint(palette.accent)
            .navigationTitle(tr("Settings"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(tr("Done"))
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .manageSubscriptionsSheet(isPresented: $showManage)
            .alert(tr("Restore Purchases"), isPresented: restoreBinding) {
                Button(tr("OK"), role: .cancel) {}
            } message: {
                Text(restoreMessage ?? "")
            }
            .onChange(of: model.data.settings.checkInsOn) { _, isOn in
                if isOn { askForReminders() }
            }
            .onChange(of: model.data.settings.crewAlertsOn) { _, isOn in
                if isOn { askForReminders() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refreshNotificationStatus() }
            }
            .task {
                notificationsDenied = await NotificationManager.isDenied()
            }
        }
    }

    private var restoreBinding: Binding<Bool> {
        Binding(get: { restoreMessage != nil }, set: { shown in
            if !shown { restoreMessage = nil }
        })
    }

    private func refreshNotificationStatus() {
        Task {
            notificationsDenied = await NotificationManager.isDenied()
        }
    }

    private func askForReminders() {
        Task {
            await model.enableReminders()
            notificationsDenied = await NotificationManager.isDenied()
        }
    }

    private func restore() {
        guard !isRestoring else { return }
        isRestoring = true
        Task {
            let failure = await purchases.restore()
            isRestoring = false
            if let failure {
                restoreMessage = failure
            } else if model.hasPass {
                restoreMessage = tr("Your Season Pass is active on this phone.")
            } else {
                restoreMessage = tr("No Season Pass was found for this Apple Account.")
            }
        }
    }

    // MARK: - Bindings

    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { model.data.settings[keyPath: keyPath] },
                set: { value in model.updateSettings { $0[keyPath: keyPath] = value } })
    }

    // MARK: - Sections

    private func valueWithChevron(_ value: String) -> some View {
        HStack(spacing: 8) {
            Text(value)
            RowChevron()
        }
    }

    private var planLabel: String {
        if purchases.activeProductID == PassProduct.yearlyID { return tr("Yearly") }
        if purchases.activeProductID == PassProduct.monthlyID { return tr("Monthly") }
        return model.hasPass ? tr("Active") : tr("Not active")
    }

    private var passSection: some View {
        Section(tr("Season Pass")) {
            Button {
                if purchases.storePass {
                    showManage = true
                } else {
                    showPaywall = true
                }
            } label: {
                LabeledContent {
                    valueWithChevron(planLabel)
                } label: {
                    SettingsLabel(title: tr("Plan"))
                }
            }
            Button {
                restore()
            } label: {
                SettingsLabel(title: tr("Restore Purchases"))
            }
            .disabled(isRestoring)
            #if PETRI_SIDELOAD
            Toggle(isOn: setting(\.sideloadPass)) {
                SettingsLabel(title: tr("Pass (test build)"))
            }
            #endif
        }
    }

    private var lookSection: some View {
        Section {
            NavigationLink {
                AppIconScreen()
            } label: {
                SettingsLabel(title: tr("Icon and Theme"))
            }
            Picker(selection: setting(\.appearance)) {
                Text(tr("Automatic")).tag(AppearanceMode.system)
                Text(tr("Light")).tag(AppearanceMode.light)
                Text(tr("Dark")).tag(AppearanceMode.dark)
            } label: {
                SettingsLabel(title: tr("Appearance"))
            }
            .tint(palette.inkSecondary)
            Toggle(isOn: setting(\.soundsOn)) {
                SettingsLabel(title: tr("Sounds and Haptics"))
            }
        } header: {
            Text(tr("Look"))
        } footer: {
            Text(tr("Sounds stay off from 10 PM to 7 AM, so nobody wakes up."))
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle(isOn: setting(\.checkInsOn)) {
                SettingsLabel(title: tr("Check-ins"))
            }
            if AppConfig.crewEnabled {
                Toggle(isOn: setting(\.crewAlertsOn)) {
                    SettingsLabel(title: tr("Crew Alerts"))
                }
            }
            if notificationsDenied, let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                Link(destination: url) {
                    LabeledContent {
                        RowChevron()
                    } label: {
                        SettingsLabel(title: tr("Turn On in iOS Settings"))
                    }
                }
            }
        } header: {
            Text(tr("Notifications"))
        } footer: {
            Text(notificationsDenied
                 ? tr("Notifications are off for Petri, so no reminder can reach you.")
                 : tr("A reminder due between 10 PM and 7 AM waits until morning."))
        }
    }

    private var moreSection: some View {
        Section {
            NavigationLink {
                HelpLinesScreen()
            } label: {
                SettingsLabel(title: tr("Help Lines"))
            }
            NavigationLink {
                DataScreen()
            } label: {
                SettingsLabel(title: tr("Data and Privacy"))
            }
            NavigationLink {
                AboutScreen()
            } label: {
                SettingsLabel(title: tr("About Petri"))
            }
        } footer: {
            Text(tr("Petri %@ · Made in Montréal", AppConfig.versionLabel))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }
}

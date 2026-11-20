import StoreKit
import SwiftUI

/// A settings row label: a pale tile with a night glyph, one tile color per section.
struct SettingsLabel: View {
    let symbol: String
    let tint: Color
    let title: String
    @Environment(\.palette) private var palette

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(palette.ink)
        } icon: {
            IconTile(symbol: symbol, background: tint, foreground: Color(hex: Swatch.night), size: 30)
        }
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

/// Tile colors of the settings sections.
enum SettingsTint {
    static let family = Color(hex: Swatch.skyPale)
    static let pass = Color(hex: Swatch.limeLight)
    static let look = Color(hex: Swatch.lilacPale)
    static let notifications = Color(hex: Swatch.butter)
    static let help = Color(hex: Swatch.lime)
    static let data = Color(hex: Swatch.skyPale)
    static let about = Color(hex: Swatch.agarAlt)
}

struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(PurchaseManager.self) private var purchases
    @Environment(CrewStore.self) private var crew
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var editingName = false
    @State private var editingPartner = false
    @State private var nameDraft = ""
    @State private var notificationsDenied = false
    @State private var restoreMessage: String?
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            List {
                profileSection
                familySection
                passSection
                lookSection
                notificationSection
                moreSection
            }
            .scrollContentBackground(.hidden)
            .background(palette.background.ignoresSafeArea())
            .tint(.green)
            .navigationTitle(tr("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .tint(palette.ink)
                    .accessibilityLabel(tr("Done"))
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .manageSubscriptionsSheet(isPresented: $showManage)
            .alert(tr("Your name"), isPresented: $editingName) {
                TextField(tr("Name"), text: $nameDraft)
                Button(tr("Save")) {
                    model.setProfileName(nameDraft)
                }
                Button(tr("Cancel"), role: .cancel) {}
            }
            .alert(tr("Partner"), isPresented: $editingPartner) {
                TextField(tr("Name"), text: $nameDraft)
                Button(tr("Save")) {
                    model.setPartnerName(nameDraft)
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(tr("Used for the couple duel, the nap coupon and Tag Team. Leave it empty to remove."))
            }
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

    private var profileSection: some View {
        Section {
            Button {
                nameDraft = model.data.profileName
                editingName = true
            } label: {
                HStack(spacing: 14) {
                    AvatarView(name: model.displayName, gradient: AvatarColors.you, size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.ink)
                        Text(tr("Level %1$lld · %2$@", model.level.number, model.displayTitle))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                        if model.hasPass {
                            PillLabel(text: tr("Season Pass").uppercased(), foreground: palette.night, background: palette.lime)
                                .padding(.top, 2)
                        }
                    }
                    Spacer(minLength: 4)
                    Text(tr("Edit"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(palette.ink.opacity(0.07), in: Capsule())
                }
                .padding(.vertical, 4)
            }
            .accessibilityHint(tr("Edit your name"))
        }
    }

    private func valueWithChevron(_ value: String) -> some View {
        HStack(spacing: 8) {
            Text(value)
            RowChevron()
        }
    }

    private var familySection: some View {
        Section(tr("Family")) {
            NavigationLink {
                KidsScreen()
            } label: {
                LabeledContent {
                    Text(model.data.kids.map { $0.name }.joined(separator: ", "))
                } label: {
                    SettingsLabel(symbol: "face.smiling.inverse", tint: SettingsTint.family, title: tr("Kids"))
                }
            }
            Button {
                nameDraft = model.data.partnerName ?? ""
                editingPartner = true
            } label: {
                LabeledContent {
                    valueWithChevron(model.data.partnerName ?? tr("Add"))
                } label: {
                    SettingsLabel(symbol: "person.2.fill", tint: SettingsTint.family, title: tr("Partner"))
                }
            }
            if AppConfig.crewEnabled {
                Button {
                    dismiss()
                    model.selectedTab = .crew
                } label: {
                    LabeledContent {
                        valueWithChevron(crew.state?.crew.name ?? tr("None"))
                    } label: {
                        SettingsLabel(symbol: "dot.radiowaves.left.and.right", tint: SettingsTint.family, title: tr("Crew"))
                    }
                }
            }
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
                    SettingsLabel(symbol: "ticket.fill", tint: SettingsTint.pass, title: tr("Plan"))
                }
            }
            Button {
                restore()
            } label: {
                SettingsLabel(symbol: "arrow.clockwise", tint: SettingsTint.pass, title: tr("Restore Purchases"))
            }
            .disabled(isRestoring)
            #if PETRI_SIDELOAD
            Toggle(isOn: setting(\.sideloadPass)) {
                SettingsLabel(symbol: "hammer.fill", tint: SettingsTint.pass, title: tr("Pass (test build)"))
            }
            #endif
        }
    }

    private var lookSection: some View {
        Section(tr("Look")) {
            NavigationLink {
                AppIconScreen()
            } label: {
                SettingsLabel(symbol: "app.badge.fill", tint: SettingsTint.look, title: tr("Icon and Theme"))
            }
            Picker(selection: setting(\.appearance)) {
                Text(tr("Automatic")).tag(AppearanceMode.system)
                Text(tr("Light")).tag(AppearanceMode.light)
                Text(tr("Dark")).tag(AppearanceMode.dark)
            } label: {
                SettingsLabel(symbol: "circle.lefthalf.filled", tint: SettingsTint.look, title: tr("Appearance"))
            }
            .tint(palette.inkSecondary)
            Toggle(isOn: setting(\.soundsOn)) {
                SettingsLabel(symbol: "speaker.wave.2.fill", tint: SettingsTint.look, title: tr("Sounds and Haptics"))
            }
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle(isOn: setting(\.checkInsOn)) {
                SettingsLabel(symbol: "bell.fill", tint: SettingsTint.notifications, title: tr("Check-ins"))
            }
            if AppConfig.crewEnabled {
                Toggle(isOn: setting(\.crewAlertsOn)) {
                    SettingsLabel(symbol: "dot.radiowaves.left.and.right", tint: SettingsTint.notifications, title: tr("Crew Alerts"))
                }
            }
            if notificationsDenied, let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                Link(destination: url) {
                    LabeledContent {
                        RowChevron()
                    } label: {
                        SettingsLabel(symbol: "bell.slash.fill", tint: SettingsTint.notifications, title: tr("Turn On in iOS Settings"))
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
                SettingsLabel(symbol: "phone.fill", tint: SettingsTint.help, title: tr("Help Lines"))
            }
            NavigationLink {
                DataScreen {
                    dismiss()
                }
            } label: {
                SettingsLabel(symbol: "hand.raised.fill", tint: SettingsTint.data, title: tr("Data and Privacy"))
            }
            NavigationLink {
                AboutScreen()
            } label: {
                SettingsLabel(symbol: "info.circle.fill", tint: SettingsTint.about, title: tr("About Petri"))
            }
        } footer: {
            Text(tr("Petri %@ · Made in Montréal", AppConfig.versionLabel))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }
}

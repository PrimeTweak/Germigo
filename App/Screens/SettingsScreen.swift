import StoreKit
import SwiftUI

/// A settings row label with the app's rounded icon tile.
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
            IconTile(symbol: symbol, background: tint, size: 30)
        }
    }
}

struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(PurchaseManager.self) private var purchases
    @Environment(CrewStore.self) private var crew
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var editingName = false
    @State private var editingPartner = false
    @State private var nameDraft = ""
    @State private var confirmErase = false
    @State private var eraseFailed = false
    @State private var exportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                profileSection
                familySection
                passSection
                lookSection
                notificationSection
                healthSection
                privacySection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(palette.background.ignoresSafeArea())
            .tint(Color(hex: 0x34C759))
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
                Text(tr("Used for the nap coupon and for Tag Team. Leave it empty to remove."))
            }
            .confirmationDialog(tr("Delete everything?"), isPresented: $confirmErase, titleVisibility: .visible) {
                Button(tr("Delete everything"), role: .destructive) {
                    eraseEverything()
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(tr("Erases your journal, kids, badges and settings from this phone, and your crew data from the server. This can't be undone."))
            }
            .alert(tr("Nothing was deleted"), isPresented: $eraseFailed) {
                Button(tr("OK"), role: .cancel) {}
            } message: {
                Text(tr("The crew server can't be reached, so your crew data can't be removed yet. Try again when you're online."))
            }
            .onChange(of: model.data.settings.checkInsOn) { _, isOn in
                guard isOn else { return }
                Task {
                    _ = await NotificationManager.requestAuthorization()
                }
            }
            .task {
                exportURL = CSVExporter.export(logs: model.data.logs, catalog: model.catalog) { source in
                    model.sourceName(source)
                }
            }
        }
    }

    // MARK: - Bindings

    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { model.data.settings[keyPath: keyPath] },
                set: { value in model.updateSettings { $0[keyPath: keyPath] = value } })
    }

    private func clock(_ keyPath: WritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        Binding(get: {
            let minute = model.data.settings[keyPath: keyPath]
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            model.updateSettings { $0[keyPath: keyPath] = minute }
        })
    }

    private func eraseEverything() {
        Task {
            if crew.isMember {
                let left = await crew.leave()
                if !left {
                    eraseFailed = true
                    return
                }
            }
            model.eraseEverything()
            dismiss()
        }
    }

    // MARK: - Sections

    private var profileSection: some View {
        Section {
            Button {
                nameDraft = model.data.profileName
                editingName = true
            } label: {
                HStack(spacing: 14) {
                    AvatarView(name: model.displayName, gradient: AvatarColors.you, size: 56, darkText: true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.ink)
                        Text(tr("Level %1$lld · %2$@", model.level.number, model.level.title))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    Spacer(minLength: 4)
                    if model.hasPass {
                        PillLabel(text: tr("Season Pass").uppercased(), foreground: palette.night, background: palette.lime)
                    }
                }
                .padding(.vertical, 4)
            }
            .accessibilityHint(tr("Edit your name"))
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
                    SettingsLabel(symbol: "face.smiling.inverse", tint: palette.sky, title: tr("Kids"))
                }
            }
            Button {
                nameDraft = model.data.partnerName ?? ""
                editingPartner = true
            } label: {
                LabeledContent {
                    Text(model.data.partnerName ?? tr("Add"))
                } label: {
                    SettingsLabel(symbol: "person.2.fill", tint: Color(hex: 0xF26AA8), title: tr("Partner"))
                }
            }
            if AppConfig.crewEnabled {
                Button {
                    dismiss()
                    model.selectedTab = .crew
                } label: {
                    LabeledContent {
                        Text(crew.state?.crew.name ?? tr("None"))
                    } label: {
                        SettingsLabel(symbol: "dot.radiowaves.left.and.right", tint: palette.coral, title: tr("Crew"))
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
                    Text(planLabel)
                } label: {
                    SettingsLabel(symbol: "ticket.fill", tint: palette.limeDeep, title: tr("Plan"))
                }
            }
            Button {
                Task {
                    await purchases.restore()
                }
            } label: {
                SettingsLabel(symbol: "arrow.clockwise", tint: Color(hex: 0x8A93A6), title: tr("Restore Purchases"))
            }
            #if PETRI_SIDELOAD
            Toggle(isOn: setting(\.sideloadPass)) {
                SettingsLabel(symbol: "hammer.fill", tint: Color(hex: 0x8A93A6), title: tr("Pass (test build)"))
            }
            #endif
        }
    }

    private var lookSection: some View {
        Section(tr("Look")) {
            NavigationLink {
                AppIconScreen()
            } label: {
                SettingsLabel(symbol: "app.badge.fill", tint: palette.lilac, title: tr("App Icon"))
            }
            Picker(selection: setting(\.appearance)) {
                Text(tr("Automatic")).tag(AppearanceMode.system)
                Text(tr("Light")).tag(AppearanceMode.light)
                Text(tr("Dark")).tag(AppearanceMode.dark)
            } label: {
                SettingsLabel(symbol: "circle.lefthalf.filled", tint: palette.night, title: tr("Appearance"))
            }
            .tint(palette.inkSecondary)
            Toggle(isOn: setting(\.soundsOn)) {
                SettingsLabel(symbol: "speaker.wave.2.fill", tint: Color(hex: 0xFF8A3D), title: tr("Sounds and Haptics"))
            }
        }
    }

    private var notificationSection: some View {
        Section(tr("Notifications")) {
            Toggle(isOn: setting(\.checkInsOn)) {
                SettingsLabel(symbol: "bell.fill", tint: palette.coral, title: tr("Check-ins"))
            }
            if AppConfig.crewEnabled {
                Toggle(isOn: setting(\.crewAlertsOn)) {
                    SettingsLabel(symbol: "dot.radiowaves.left.and.right", tint: palette.coral, title: tr("Crew Alerts"))
                }
            }
            Toggle(isOn: setting(\.quietHoursOn)) {
                SettingsLabel(symbol: "moon.fill", tint: Color(hex: 0x5B4FE0), title: tr("Quiet Hours"))
            }
            if model.data.settings.quietHoursOn {
                DatePicker(tr("From"), selection: clock(\.quietStartMinute), displayedComponents: .hourAndMinute)
                    .foregroundStyle(palette.ink)
                DatePicker(tr("To"), selection: clock(\.quietEndMinute), displayedComponents: .hourAndMinute)
                    .foregroundStyle(palette.ink)
            }
        }
    }

    private var healthSection: some View {
        Section {
            NavigationLink {
                HelpLinesScreen()
            } label: {
                SettingsLabel(symbol: "phone.fill", tint: Color(hex: 0x34C759), title: tr("Help Lines"))
            }
        } header: {
            Text(tr("Health"))
        } footer: {
            Text(tr("Petri is for fun and general information. It doesn't diagnose. When in doubt, call a health professional."))
        }
    }

    private var privacySection: some View {
        Section {
            NavigationLink {
                DataScreen()
            } label: {
                SettingsLabel(symbol: "hand.raised.fill", tint: Color(hex: 0x3D7BFA), title: tr("Your Data"))
            }
            if let exportURL, !model.data.logs.isEmpty {
                ShareLink(item: exportURL) {
                    LabeledContent {
                        Text(verbatim: "CSV")
                    } label: {
                        SettingsLabel(symbol: "square.and.arrow.up", tint: Color(hex: 0x8A93A6), title: tr("Export"))
                    }
                }
            }
            Button {
                confirmErase = true
            } label: {
                SettingsLabel(symbol: "trash.fill", tint: palette.coralDeep, title: tr("Delete Everything"))
            }
        } header: {
            Text(tr("Privacy"))
        } footer: {
            Text(tr("No ads, no trackers, no third-party analytics. Your journal stays on this phone. Crew sharing is your choice."))
        }
    }

    private var aboutSection: some View {
        Section {
            NavigationLink {
                SourcesScreen()
            } label: {
                SettingsLabel(symbol: "book.closed.fill", tint: palette.lilac, title: tr("Sources"))
            }
            NavigationLink {
                LegalScreen(kind: .terms)
            } label: {
                SettingsLabel(symbol: "doc.text.fill", tint: Color(hex: 0x8A93A6), title: tr("Terms of Use"))
            }
            NavigationLink {
                LegalScreen(kind: .privacy)
            } label: {
                SettingsLabel(symbol: "lock.fill", tint: Color(hex: 0x8A93A6), title: tr("Privacy Policy"))
            }
            if let email = AppConfig.supportEmail, let url = URL(string: "mailto:" + email) {
                Link(destination: url) {
                    SettingsLabel(symbol: "envelope.fill", tint: Color(hex: 0x3D7BFA), title: tr("Contact Support"))
                }
            }
        } header: {
            Text(tr("About"))
        } footer: {
            Text(tr("Petri %@ · Made in Montréal", AppConfig.versionLabel))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
    }
}

import StoreKit
import SwiftUI
import UniformTypeIdentifiers

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
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPaywall = false
    @State private var showManage = false
    @State private var editingName = false
    @State private var editingPartner = false
    @State private var nameDraft = ""
    @State private var confirmErase = false
    @State private var eraseFailed = false
    @State private var notificationsDenied = false
    @State private var restoreMessage: String?
    @State private var isRestoring = false
    @State private var importingBackup = false
    @State private var pendingBackup: AppData?
    @State private var backupUnreadable = false

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
            .confirmationDialog(tr("Delete everything?"), isPresented: $confirmErase, titleVisibility: .visible) {
                Button(tr("Delete everything"), role: .destructive) {
                    eraseEverything()
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(tr("Erases your journal, kids, badges and settings from this phone, and your crew data from the server. This can't be undone."))
            }
            .alert(tr("Nothing was deleted"), isPresented: $eraseFailed) {
                Button(tr("Erase this phone only"), role: .destructive) {
                    eraseEverything(skippingServer: true)
                }
                Button(tr("Try later"), role: .cancel) {}
            } message: {
                Text(tr("The crew server can't be reached, so your crew data can't be removed from it yet. You can try again later, or erase this phone now and write to support to have your crew data removed."))
            }
            .fileImporter(isPresented: $importingBackup, allowedContentTypes: [.json]) { result in
                if case .success(let url) = result {
                    readBackup(url)
                }
            }
            .confirmationDialog(tr("Replace your journal?"), isPresented: backupBinding, titleVisibility: .visible) {
                Button(tr("Replace with the backup"), role: .destructive) {
                    if let backup = pendingBackup {
                        model.restore(backup)
                        Haptics.success()
                    }
                    pendingBackup = nil
                }
                Button(tr("Cancel"), role: .cancel) {
                    pendingBackup = nil
                }
            } message: {
                Text(backupSummary)
            }
            .alert(tr("This file isn't a Petri backup"), isPresented: $backupUnreadable) {
                Button(tr("OK"), role: .cancel) {}
            } message: {
                Text(tr("Pick a file made with Back Up, in Settings."))
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

    private var backupBinding: Binding<Bool> {
        Binding(get: { pendingBackup != nil }, set: { shown in
            if !shown { pendingBackup = nil }
        })
    }

    private var backupSummary: String {
        guard let backup = pendingBackup else { return "" }
        let started = backup.installedAt.formatted(date: .abbreviated, time: .omitted)
        return tr("The journal on this phone is replaced by the backup: %1$lld germs logged since %2$@.",
                  backup.logs.count, started)
    }

    /// Opens a file picked in Files and keeps it only if it is a Petri journal.
    private func readBackup(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        if let raw = try? Data(contentsOf: url), let backup = Persistence.readBackup(raw) {
            pendingBackup = backup
        } else {
            backupUnreadable = true
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

    private func eraseEverything(skippingServer: Bool = false) {
        Task {
            if crew.isMember, !skippingServer {
                let left = await crew.leave()
                if !left {
                    eraseFailed = true
                    return
                }
            }
            crew.resetLocal()
            model.eraseEverything()
            if AppIconManager.current != .petri {
                _ = await AppIconManager.apply(.petri)
            }
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
                    AvatarView(name: model.displayName, gradient: AvatarColors.you, size: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(palette.ink)
                        Text(tr("Level %1$lld · %2$@", model.level.number, model.displayTitle))
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
                    SettingsLabel(symbol: "person.2.fill", tint: Color(hex: Swatch.pink), title: tr("Partner"))
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
                restore()
            } label: {
                SettingsLabel(symbol: "arrow.clockwise", tint: Color(hex: Swatch.slate), title: tr("Restore Purchases"))
            }
            .disabled(isRestoring)
            #if PETRI_SIDELOAD
            Toggle(isOn: setting(\.sideloadPass)) {
                SettingsLabel(symbol: "hammer.fill", tint: Color(hex: Swatch.slate), title: tr("Pass (test build)"))
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
                SettingsLabel(symbol: "speaker.wave.2.fill", tint: Color(hex: Swatch.orange), title: tr("Sounds and Haptics"))
            }
        }
    }

    private var notificationSection: some View {
        Section {
            Toggle(isOn: setting(\.checkInsOn)) {
                SettingsLabel(symbol: "bell.fill", tint: palette.coral, title: tr("Check-ins"))
            }
            if AppConfig.crewEnabled {
                Toggle(isOn: setting(\.crewAlertsOn)) {
                    SettingsLabel(symbol: "dot.radiowaves.left.and.right", tint: palette.coral, title: tr("Crew Alerts"))
                }
            }
            if notificationsDenied, let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                Link(destination: url) {
                    SettingsLabel(symbol: "bell.slash.fill", tint: Color(hex: Swatch.slate), title: tr("Turn On in iOS Settings"))
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

    private var healthSection: some View {
        Section {
            NavigationLink {
                HelpLinesScreen()
            } label: {
                SettingsLabel(symbol: "phone.fill", tint: .green, title: tr("Help Lines"))
            }
        } header: {
            Text(tr("Health"))
        } footer: {
            Text(HealthNotice.text)
        }
    }

    private var privacySection: some View {
        Section {
            NavigationLink {
                DataScreen()
            } label: {
                SettingsLabel(symbol: "hand.raised.fill", tint: Color(hex: Swatch.azure), title: tr("Your Data"))
            }
            if !model.data.logs.isEmpty {
                ShareLink(item: journalExport, preview: SharePreview(tr("Petri journal"))) {
                    LabeledContent {
                        Text(verbatim: "CSV")
                    } label: {
                        SettingsLabel(symbol: "square.and.arrow.up", tint: Color(hex: Swatch.slate), title: tr("Export"))
                    }
                }
            }
            ShareLink(item: JournalBackup(data: model.data), preview: SharePreview(tr("Petri backup"))) {
                LabeledContent {
                    Text(verbatim: "JSON")
                } label: {
                    SettingsLabel(symbol: "externaldrive.fill", tint: Color(hex: Swatch.azure), title: tr("Back Up"))
                }
            }
            Button {
                importingBackup = true
            } label: {
                SettingsLabel(symbol: "arrow.down.doc.fill", tint: Color(hex: Swatch.azure), title: tr("Restore"))
            }
            Button {
                confirmErase = true
            } label: {
                SettingsLabel(symbol: "trash.fill", tint: palette.coralDeep, title: tr("Delete Everything"))
            }
        } header: {
            Text(tr("Privacy"))
        } footer: {
            Text(tr("No ads, no trackers, no third-party analytics. Your journal stays on this phone, and a backup goes where you save it. Crew sharing is your choice."))
        }
    }

    /// Built from the journal only when the share sheet asks for it.
    private var journalExport: JournalExport {
        let logs = model.data.logs
        let catalog = model.catalog
        let names = Dictionary(uniqueKeysWithValues: logs.map { ($0.id, model.sourceName($0.source)) })
        return JournalExport(logs: logs, catalog: catalog, sourceNames: names)
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
                SettingsLabel(symbol: "doc.text.fill", tint: Color(hex: Swatch.slate), title: tr("Terms of Use"))
            }
            NavigationLink {
                LegalScreen(kind: .privacy)
            } label: {
                SettingsLabel(symbol: "lock.fill", tint: Color(hex: Swatch.slate), title: tr("Privacy Policy"))
            }
            if let email = AppConfig.supportEmail, let url = URL(string: "mailto:" + email) {
                Link(destination: url) {
                    SettingsLabel(symbol: "envelope.fill", tint: Color(hex: Swatch.azure), title: tr("Contact Support"))
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

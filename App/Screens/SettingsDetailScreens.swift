import SwiftUI
import UniformTypeIdentifiers

/// Home screen icons and color themes, unlocked by playing.
struct AppIconScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var current = AppIconOption.petri
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(tr("New icons unlock as the season goes."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                    ForEach(AppIconOption.allCases) { option in
                        iconCell(option)
                    }
                }
                SectionHeader(title: tr("Themes"))
                HStack(spacing: 12) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        themeCell(theme)
                    }
                }
                Text(tr("Night Shift unlocks with its badge. Mint unlocks after 30 days without a germ. Good luck with that."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Icon and Theme"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            current = AppIconManager.current
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func iconCell(_ option: AppIconOption) -> some View {
        let unlocked = model.isIconUnlocked(option)
        let inUse = current == option
        return Button {
            guard unlocked else {
                if option == .soupBowl { showPaywall = true }
                return
            }
            Task {
                if await AppIconManager.apply(option) {
                    current = option
                    Haptics.success()
                }
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    Image(option.previewAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .saturation(unlocked ? 1 : 0.15)
                        .opacity(unlocked ? 1 : 0.55)
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(inUse ? palette.ink : Color.clear, lineWidth: 3)
                        }
                    if !unlocked {
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.background)
                            .frame(width: 24, height: 24)
                            .background(palette.ink, in: Circle())
                            .offset(x: 6, y: 6)
                    }
                }
                Text(option.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(inUse ? tr("In use") : (unlocked ? tr("Unlocked") : option.requirement))
                    .font(.caption)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 30, alignment: .top)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(inUse ? .isSelected : [])
    }

    private func themeTitle(_ theme: Theme) -> String {
        switch theme {
        case .agar: return tr("Standard")
        case .nightShift: return tr("Night Shift")
        case .mint: return tr("Mint")
        }
    }

    private func themeCell(_ theme: Theme) -> some View {
        let unlocked = model.isThemeUnlocked(theme)
        let inUse = model.data.settings.theme == theme
        let sample = Palette.make(theme: theme, scheme: .light)
        return Button {
            guard unlocked else { return }
            model.updateSettings { $0.theme = theme }
        } label: {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(sample.background)
                    .frame(height: 72)
                    .overlay {
                        HStack(spacing: 6) {
                            Circle().fill(sample.accent).frame(width: 18, height: 18)
                            Circle().fill(sample.ink).frame(width: 18, height: 18)
                        }
                        .opacity(unlocked ? 1 : 0.3)
                    }
                    .overlay {
                        if !unlocked {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(sample.ink.opacity(0.6))
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(inUse ? palette.ink : palette.hairline, lineWidth: inUse ? 3 : 1)
                    }
                Text(themeTitle(theme))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.ink)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(themeTitle(theme))
        .accessibilityValue(unlocked ? (inUse ? tr("In use") : tr("Unlocked")) : tr("Locked"))
    }
}

/// Phone numbers worth having, picked for the phone's region.
struct HelpLinesScreen: View {
    private struct HelpLine: Identifiable {
        let id: String
        let title: String
        let detail: String
        let display: String
    }

    @Environment(\.palette) private var palette

    private var lines: [HelpLine] {
        switch Locale.current.region?.identifier ?? "" {
        case "CA":
            return [
                HelpLine(id: "911", title: tr("Emergency"), detail: tr("Trouble breathing, a seizure, or a child who won't wake up."), display: "911"),
                HelpLine(id: "811", title: tr("Health line"), detail: tr("A nurse answers day and night in most provinces. In Québec it's Info-Santé."), display: "811"),
                HelpLine(id: "18447647669", title: tr("Poison centre"), detail: tr("Everywhere in Canada except Québec and Nunavut."), display: "1-844-764-7669"),
                HelpLine(id: "18004635060", title: tr("Poison centre, Québec"), detail: tr("Centre antipoison du Québec."), display: "1-800-463-5060")
            ]
        case "US":
            return [
                HelpLine(id: "911", title: tr("Emergency"), detail: tr("Trouble breathing, a seizure, or a child who won't wake up."), display: "911"),
                HelpLine(id: "18002221222", title: tr("Poison Help"), detail: tr("Free and confidential, day and night."), display: "1-800-222-1222")
            ]
        default:
            return []
        }
    }

    var body: some View {
        List {
            Group {
                Section {
                    if lines.isEmpty {
                        Text(tr("In an emergency, call your local emergency number. For advice, call your doctor or your local health line."))
                            .foregroundStyle(palette.ink)
                    }
                    ForEach(lines) { line in
                        if let url = URL(string: "tel:" + line.id) {
                            Link(destination: url) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(line.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(palette.ink)
                                        Text(line.detail)
                                            .font(.footnote)
                                            .foregroundStyle(palette.inkSecondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 8)
                                    Text(line.display)
                                        .font(.callout.weight(.bold).monospacedDigit())
                                        .foregroundStyle(palette.ink)
                                }
                            }
                        }
                    }
                } footer: {
                    Text(HealthNotice.text)
                }
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Help Lines"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// What is stored and where, and what can be done with the journal: export, back up, restore, delete.
struct DataScreen: View {
    private struct Item {
        let symbol: String
        let title: String
        let detail: String
    }

    @Environment(AppModel.self) private var model
    @Environment(CrewStore.self) private var crew
    @Environment(\.palette) private var palette
    @State private var showAll = false
    @State private var confirmErase = false
    @State private var eraseFailed = false
    @State private var importingBackup = false
    @State private var pendingBackup: AppData?
    @State private var backupUnreadable = false

    private let shortList = 3

    private var items: [Item] {
        [
            Item(symbol: "iphone", title: tr("On this phone"),
                 detail: tr("Your journal, your kids' first names, your badges and your settings live in a protected file on this phone. It is part of your device backup if you use one.")),
            Item(symbol: "dot.radiowaves.left.and.right", title: tr("In a crew"),
                 detail: tr("Only if you join one: the crew name, the name you pick, and the germs you choose to share. Your kids' names and your journal are never sent.")),
            Item(symbol: "eye.slash", title: tr("No tracking"),
                 detail: tr("No ads, no trackers, no third-party analytics, no data sold.")),
            Item(symbol: "creditcard", title: tr("Purchases"),
                 detail: tr("The Season Pass is handled by Apple. Petri never sees your payment details.")),
            Item(symbol: "externaldrive", title: tr("Backups"),
                 detail: tr("Back Up saves your whole journal as a file, where you choose. Restore a Backup reads it back on this phone or a new one. Petri never uploads it.")),
            Item(symbol: "trash", title: tr("Your call"),
                 detail: tr("Export your journal or delete everything from here at any time. Leaving a crew deletes your data from the server."))
        ]
    }

    var body: some View {
        List {
            Group {
                infoSection
                journalSection
                Section {
                    Button(role: .destructive) {
                        confirmErase = true
                    } label: {
                        Label {
                            Text(tr("Delete Everything"))
                                .fontWeight(.semibold)
                                .foregroundStyle(palette.ink)
                        } icon: {
                            IconTile(symbol: "trash.fill", size: 30)
                        }
                    }
                } footer: {
                    Text(tr("Erases your journal, kids, badges and settings from this phone, and your crew data from the server."))
                }
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
        .tint(palette.ink)
        .navigationTitle(tr("Data and Privacy"))
        .navigationBarTitleDisplayMode(.inline)
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
    }

    private var infoSection: some View {
        Section {
            ForEach(Array(items.prefix(showAll ? items.count : shortList).enumerated()), id: \.offset) { item in
                HStack(alignment: .top, spacing: 13) {
                    IconTile(symbol: item.element.symbol, size: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.element.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Text(item.element.detail)
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 4)
            }
            if !showAll {
                Button {
                    withAnimation(.snappy) {
                        showAll = true
                    }
                } label: {
                    Text(tr("Show %lld more", items.count - shortList))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.ink)
                }
            }
            if let kept = Persistence.setAsideFiles.first {
                ShareLink(item: kept) {
                    SettingsLabel(title: tr("Export the journal that couldn't be read"))
                }
            }
            NavigationLink {
                LegalScreen(kind: .privacy)
            } label: {
                SettingsLabel(title: tr("Privacy Policy"))
            }
        }
    }

    private var journalSection: some View {
        Section {
            if !model.data.logs.isEmpty {
                ShareLink(item: journalExport, preview: SharePreview(tr("Petri journal"))) {
                    LabeledContent {
                        Text(verbatim: "CSV")
                    } label: {
                        SettingsLabel(title: tr("Export"))
                    }
                }
            }
            ShareLink(item: JournalBackup(data: model.data), preview: SharePreview(tr("Petri backup"))) {
                LabeledContent {
                    Text(verbatim: "JSON")
                } label: {
                    SettingsLabel(title: tr("Back Up"))
                }
            }
            Button {
                importingBackup = true
            } label: {
                SettingsLabel(title: tr("Restore a Backup"))
            }
        } header: {
            Text(tr("Your journal"))
        } footer: {
            Text(tr("A backup goes where you save it. Petri never uploads it."))
        }
    }

    /// Built from the journal only when the share sheet asks for it.
    private var journalExport: JournalExport {
        let logs = model.data.logs
        let names = Dictionary(uniqueKeysWithValues: logs.map { ($0.id, model.sourceName($0.source)) })
        return JournalExport(logs: logs, catalog: model.catalog, sourceNames: names)
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
        }
    }
}

/// Sources, legal pages and support, with the health notice.
struct AboutScreen: View {
    @Environment(\.palette) private var palette

    var body: some View {
        List {
            Group {
                Section {
                    NavigationLink {
                        SourcesScreen()
                    } label: {
                        SettingsLabel(title: tr("Sources"))
                    }
                    NavigationLink {
                        LegalScreen(kind: .terms)
                    } label: {
                        SettingsLabel(title: tr("Terms of Use"))
                    }
                    NavigationLink {
                        LegalScreen(kind: .privacy)
                    } label: {
                        SettingsLabel(title: tr("Privacy Policy"))
                    }
                    if let email = AppConfig.supportEmail, let url = URL(string: "mailto:" + email) {
                        Link(destination: url) {
                            LabeledContent {
                                RowChevron()
                            } label: {
                                SettingsLabel(title: tr("Contact Support"))
                            }
                        }
                    }
                } footer: {
                    Text(HealthNotice.text)
                }
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("About Petri"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Every reference used by the case files and the lessons.
struct SourcesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    private var references: [GermReference] {
        var seen = Set<String>()
        var result: [GermReference] = []
        let all = model.catalog.germs.flatMap { $0.sources } + model.catalog.articles.flatMap { $0.sources }
        for reference in all where seen.insert(reference.url).inserted {
            result.append(reference)
        }
        return result.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(tr("The case files summarize guidance published by public health agencies and pediatric societies. They are general information, not medical advice, and they are not a substitute for a health professional who knows you."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
                SourceList(references: references)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Sources"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

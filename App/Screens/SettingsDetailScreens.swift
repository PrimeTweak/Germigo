import SwiftUI

/// The kids in the household. The first one is free; more need the Season Pass.
struct KidsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var editing: Kid?
    @State private var pendingDelete: Kid?
    @State private var showPaywall = false

    var body: some View {
        List {
            Section {
                ForEach(model.data.kids) { kid in
                    Button {
                        editing = kid
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(name: kid.name, gradient: AvatarColors.gradient(kid.colorIndex), size: 40)
                            Text(kid.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(palette.ink)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            pendingDelete = kid
                        } label: {
                            Label(tr("Delete"), systemImage: "trash")
                        }
                        .tint(Color.red)
                    }
                }
                Button {
                    if model.canAddKid {
                        editing = Kid(name: "", colorIndex: model.data.kids.count)
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Label(tr("Add a kid"), systemImage: model.canAddKid ? "plus" : "lock.fill")
                        .foregroundStyle(palette.ink)
                }
            } footer: {
                Text(tr("Only first names, and they never leave this phone. One kid is free; the Season Pass covers the whole household."))
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Kids"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { kid in
            KidEditSheet(kid: kid)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .confirmationDialog(tr("Remove %@?", pendingDelete?.name ?? ""), isPresented: deleteBinding,
                            titleVisibility: .visible) {
            Button(tr("Remove"), role: .destructive) {
                if let kid = pendingDelete { model.removeKid(kid.id) }
                pendingDelete = nil
            }
            Button(tr("Cancel"), role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(tr("Their germs and countdowns are removed too. Your own journal stays."))
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { shown in
            if !shown { pendingDelete = nil }
        })
    }
}

private struct KidEditSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Kid

    init(kid: Kid) {
        _draft = State(initialValue: kid)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(tr("Name"), text: $draft.name)
                        .textInputAutocapitalization(.words)
                }
                Section(tr("Color")) {
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { index in
                            Button {
                                draft.colorIndex = index
                            } label: {
                                Circle()
                                    .fill(AvatarColors.gradient(index))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Circle().strokeBorder(draft.colorIndex % 6 == index ? palette.ink : Color.clear, lineWidth: 3)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tr("Color %lld", index + 1))
                            .accessibilityAddTraits(draft.colorIndex % 6 == index ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(draft.name.isEmpty ? tr("New kid") : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Save")) {
                        var kid = draft
                        kid.name = draft.name.trimmingCharacters(in: .whitespaces)
                        model.saveKid(kid)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

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
        .navigationTitle(tr("App Icon"))
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
                            .foregroundStyle(Color.white)
                            .frame(width: 24, height: 24)
                            .background(palette.night, in: Circle())
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
        case .agar: return tr("Agar")
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
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Help Lines"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Plain-language summary of what is stored and where.
struct DataScreen: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                item("iphone", tr("On this phone"),
                     tr("Your journal, your kids' first names, your badges and your settings live in a protected file on this phone. It is part of your device backup if you use one."))
                item("dot.radiowaves.left.and.right", tr("In a crew"),
                     tr("Only if you join one: the crew name, the name you pick, and the germs you choose to share. Your kids' names and your journal are never sent."))
                item("creditcard", tr("Purchases"),
                     tr("The Season Pass is handled by Apple. Petri never sees your payment details."))
                item("eye.slash", tr("No tracking"),
                     tr("No ads, no trackers, no third-party analytics, no data sold."))
                item("externaldrive", tr("Backups"),
                     tr("Back Up saves your whole journal as a file, where you choose. Restore reads it back on this phone or a new one. Petri never uploads it."))
                item("trash", tr("Your call"),
                     tr("Export your journal or delete everything from Settings at any time. Leaving a crew deletes your data from the server."))
                if let kept = Persistence.setAsideFiles.first {
                    ShareLink(item: kept) {
                        Text(tr("Export the journal that couldn't be read"))
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost, height: 50))
                    .padding(.top, 6)
                }
                NavigationLink {
                    LegalScreen(kind: .privacy)
                } label: {
                    Text(tr("Read the Privacy Policy"))
                }
                .buttonStyle(PillButtonStyle(kind: .ghost, height: 50))
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Your Data"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func item(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            IconTile(symbol: symbol, background: palette.surfaceAlt, foreground: palette.ink, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .petriCard(radius: 22, padding: 14)
    }
}

/// Every reference used by the Field Notes and the reads.
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
                Text(tr("The Field Notes summarize guidance published by public health agencies and pediatric societies. They are general information, not medical advice, and they are not a substitute for a health professional who knows you."))
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

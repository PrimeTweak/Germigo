import SwiftUI

/// Signs a daycare up: its name, its groups, and the address it may send notices from.
struct DaycareSetupSheet: View {
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var groups: [String] = []
    @State private var newGroup = ""
    @State private var email = ""
    @State private var authorized = false
    @State private var showTerms = false
    @State private var submitting = false

    private var suggestions: [String] {
        let names = AppLanguage.isFrench ? ["Poupons", "Trottineurs", "Grands"] : ["Infants", "Toddlers", "Preschool"]
        return names.filter { suggestion in !groups.contains { $0.lowercased() == suggestion.lowercased() } }
    }

    private var canSubmit: Bool {
        name.trimmingCharacters(in: .whitespaces).count >= 2 && authorized && !submitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(tr("Tell families when an illness is going around, from the app or by email. Free for daycares."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                    TextField(tr("Daycare name"), text: $name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 16)
                        .frame(height: 54)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .onChange(of: name) { _, value in
                            if value.count > 40 { name = String(value.prefix(40)) }
                        }
                    GroupsEditor(groups: $groups, newGroup: $newGroup, suggestions: suggestions)
                    VStack(alignment: .leading, spacing: 6) {
                        TextField(tr("Email (optional)"), text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        Text(tr("To send notices by email from this address. You can add it later."))
                            .font(.footnote)
                            .foregroundStyle(palette.inkTertiary)
                            .padding(.horizontal, 4)
                    }
                    Toggle(isOn: $authorized) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("I may send this daycare's notices"))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(palette.ink)
                            Text(tr("Notices are for illnesses only. Never a child's name."))
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                        }
                    }
                    .tint(palette.accent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .germigoCard(padding: 0)
                    Button(tr("Read the Terms of Use")) {
                        showTerms = true
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, 4)
                    if let message = daycare.errorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 4)
                    }
                    Button {
                        submit()
                    } label: {
                        if submitting {
                            ProgressView()
                        } else {
                            Text(tr("Create the daycare"))
                        }
                    }
                    .buttonStyle(PillButtonStyle(kind: .ink))
                    .disabled(!canSubmit)
                }
                .padding(20)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("I run a daycare"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Cancel"))
                }
            }
            .sheet(isPresented: $showTerms) {
                NavigationStack {
                    LegalScreen(kind: .terms)
                }
            }
            .onAppear {
                daycare.errorMessage = nil
            }
        }
        .tint(palette.ink)
    }

    private func submit() {
        var list = groups
        let pending = newGroup.trimmingCharacters(in: .whitespaces)
        if !pending.isEmpty, list.count < DirectorLimits.groups { list.append(pending) }
        let address = email.trimmingCharacters(in: .whitespaces)
        submitting = true
        Task {
            let done = await daycare.create(name: name.trimmingCharacters(in: .whitespaces), groups: list,
                                            email: address.isEmpty ? nil : address)
            submitting = false
            if done { dismiss() }
        }
    }
}

enum DirectorLimits {
    static let groups = 12
    static let groupName = 24
    static let note = 280
}

/// The list of group names with a field to add one, and a few names to start from.
private struct GroupsEditor: View {
    @Binding var groups: [String]
    @Binding var newGroup: String
    let suggestions: [String]
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("Groups"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.inkSecondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) {
                ForEach(Array(groups.enumerated()), id: \.offset) { item in
                    HStack {
                        Text(item.element)
                            .foregroundStyle(palette.ink)
                        Spacer()
                        Button {
                            groups.remove(at: item.offset)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(palette.inkTertiary)
                                .frame(width: 44, height: 44, alignment: .trailing)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(tr("Remove %@", item.element))
                    }
                    .frame(minHeight: 48)
                    Divider()
                }
                if groups.count < DirectorLimits.groups {
                    HStack {
                        TextField(tr("Add a group"), text: $newGroup)
                            .foregroundStyle(palette.ink)
                            .onSubmit(add)
                            .onChange(of: newGroup) { _, value in
                                if value.count > DirectorLimits.groupName { newGroup = String(value.prefix(DirectorLimits.groupName)) }
                            }
                        Button(action: add) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(palette.ink)
                                .frame(width: 44, height: 44, alignment: .trailing)
                                .contentShape(Rectangle())
                        }
                        .disabled(newGroup.trimmingCharacters(in: .whitespaces).count < 2)
                        .accessibilityLabel(tr("Add a group"))
                    }
                    .frame(minHeight: 48)
                }
            }
            .padding(.horizontal, 16)
            .germigoCard(padding: 0)
            if !suggestions.isEmpty, groups.count < DirectorLimits.groups {
                ChipRows {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            groups.append(suggestion)
                        } label: {
                            Label(suggestion, systemImage: "plus")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(palette.ink)
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(palette.ink.opacity(0.07), in: Capsule())
                                .hitTarget(height: 34)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            Text(tr("Parents pick their child's group. Up to 12 groups, and you can change them later."))
                .font(.footnote)
                .foregroundStyle(palette.inkTertiary)
                .padding(.horizontal, 4)
        }
    }

    private func add() {
        let name = newGroup.trimmingCharacters(in: .whitespaces)
        guard name.count >= 2, groups.count < DirectorLimits.groups,
              !groups.contains(where: { $0.lowercased() == name.lowercased() }) else { return }
        groups.append(name)
        newGroup = ""
    }
}

/// Daycare mode: send a notice, invite families, groups, email, and the notices sent.
struct DirectorScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @State private var composing = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if let state = daycare.director {
                content(state)
            } else {
                ContentUnavailableView(tr("This daycare was closed."), systemImage: "house")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CharacterWash(tint: TabWash.crew))
        .navigationTitle(tr("Daycare mode"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if daycare.director != nil {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel(tr("Daycare settings"))
                }
            }
        }
        .sheet(isPresented: $composing) {
            NoticeComposer()
        }
        .sheet(isPresented: $showSettings) {
            DirectorSettingsSheet()
        }
    }

    private func content(_ state: DirectorState) -> some View {
        let info = state.daycare
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 8) {
                    DaycareBadge(size: 64)
                    Text(info.name)
                        .font(.title.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.center)
                    Text(trCount(info.families, one: "%lld family", other: "%lld families") + " · "
                         + trCount(info.groups.count, one: "%lld group", other: "%lld groups"))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                Button {
                    composing = true
                } label: {
                    Label(tr("Send a notice"), systemImage: "bell.fill")
                }
                .buttonStyle(PillButtonStyle(kind: .ink))
                VStack(spacing: 0) {
                    NavigationLink {
                        InviteScreen()
                    } label: {
                        row("square.and.arrow.up", tr("Invite families"), tr("Code and poster"))
                    }
                    Divider()
                    NavigationLink {
                        DaycareGroupsScreen()
                    } label: {
                        row("person.3.fill", tr("Groups"), String(info.groups.count))
                    }
                    Divider()
                    NavigationLink {
                        EmailNoticesScreen()
                    } label: {
                        row("envelope.fill", tr("Send by email"), info.email == nil ? tr("Set up") : tr("On"))
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .germigoCard(padding: 0)
                SectionHeader(title: tr("Sent"))
                if daycare.isStale {
                    StaleFeedNote()
                }
                if state.notices.isEmpty {
                    Text(tr("No notices sent yet."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .germigoCard()
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(state.notices.enumerated()), id: \.element.id) { item in
                            if item.offset > 0 {
                                Divider()
                            }
                            if let germ = model.catalog.germ(item.element.germID) {
                                NoticeRow(notice: item.element, germ: germ,
                                          title: DaycareText.sent(item.element, germ: germ, groups: info.groups),
                                          trailing: reach(item.element))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .germigoCard(padding: 0)
                }
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .refreshable {
            await daycare.refresh()
        }
    }

    private var footnote: String {
        var text = tr("Families see the illness, the group, your note and what to watch for. Never a child's name.")
        if daycare.isDemo {
            text = tr("A sample daycare for this test build. Nothing leaves this phone.") + " " + text
        }
        if let email = AppConfig.supportEmail {
            text += " " + tr("Contact: %@", email)
        }
        return text
    }

    private func reach(_ notice: DaycareNotice) -> String {
        var text = trCount(notice.recipients ?? 0, one: "%lld family", other: "%lld families")
        if let reports = notice.reports, reports > 0 {
            text += " · " + trCount(reports, one: "%lld report", other: "%lld reports")
        }
        return text
    }

    private func row(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.callout.weight(.semibold))
                .foregroundStyle(palette.ink)
                .frame(width: 24)
                .accessibilityHidden(true)
            ValueRow(title: title, value: value)
        }
    }
}

/// A new notice in three choices: the illness, who gets it, an optional note.
struct NoticeComposer: View {
    @Environment(AppModel.self) private var model
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var germID: String?
    /// The group that gets the notice; empty for the whole daycare.
    @State private var scope = ""
    @State private var note = ""
    @State private var showAll = false
    @State private var sending = false

    /// The illnesses daycares announce most, shown first.
    private static let common = ["noro", "rhino", "flu", "coxy", "pinky", "lousy", "poxy", "strep"]

    private var germs: [Germ] {
        let all = model.catalog.germs.filter { $0.id != "mystery" }
        let first = Self.common.compactMap { id in all.first { $0.id == id } }
        return showAll ? first + all.filter { !Self.common.contains($0.id) } : first
    }

    private var recipients: Int {
        guard let info = daycare.director?.daycare else { return 0 }
        if scope.isEmpty { return info.families }
        return info.groups.first { $0.id == scope }?.families ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    label(tr("Illness"))
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(germs) { germ in
                            tile(germ)
                        }
                    }
                    Button(showAll ? tr("Fewer illnesses") : tr("All illnesses")) {
                        withAnimation(Tempo.quick) {
                            showAll.toggle()
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, 4)
                    label(tr("Who gets it"))
                    ChipRows {
                        chip(tr("Whole daycare"), id: "")
                        ForEach(daycare.director?.daycare.groups ?? []) { group in
                            chip(group.name, id: group.id)
                        }
                    }
                    label(tr("Note (optional)"))
                    VStack(alignment: .trailing, spacing: 6) {
                        TextField(tr("What families should know"), text: $note, axis: .vertical)
                            .lineLimit(3...6)
                            .foregroundStyle(palette.ink)
                            .onChange(of: note) { _, value in
                                if value.count > DirectorLimits.note { note = String(value.prefix(DirectorLimits.note)) }
                            }
                        Text(verbatim: "\(note.count) / \(DirectorLimits.note)")
                            .font(.caption)
                            .foregroundStyle(palette.inkTertiary)
                    }
                    .germigoCard()
                    if let message = daycare.errorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 4)
                    }
                    Button {
                        send()
                    } label: {
                        if sending {
                            ProgressView()
                        } else {
                            Label(trCount(recipients, one: "Send to %lld family", other: "Send to %lld families"),
                                  systemImage: "bell.fill")
                        }
                    }
                    .buttonStyle(PillButtonStyle(kind: .ink))
                    .disabled(germID == nil || sending)
                    Text(tr("Families see the illness, the group, your note and what to watch for. Never a child's name."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkTertiary)
                        .padding(.horizontal, 4)
                }
                .padding(20)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("New notice"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Cancel"))
                }
            }
            .onAppear {
                daycare.errorMessage = nil
            }
        }
        .tint(palette.ink)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(palette.inkSecondary)
            .padding(.horizontal, 4)
    }

    private func tile(_ germ: Germ) -> some View {
        let selected = germID == germ.id
        return Button {
            withAnimation(Tempo.quick) {
                germID = germ.id
            }
        } label: {
            VStack(spacing: 4) {
                GermImage(germ: germ, size: 36)
                Text(germ.illness.value)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(4)
            .background(germ.lightTint.opacity(palette.isDark ? 0.22 : 0.4),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(palette.ink, lineWidth: selected ? 2.5 : 0)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(germ.illness.value)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func chip(_ title: String, id: String) -> some View {
        let selected = scope == id
        return Button {
            withAnimation(Tempo.quick) {
                scope = id
            }
        } label: {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(selected ? palette.background : palette.ink)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(selected ? palette.ink : palette.ink.opacity(0.07), in: Capsule())
                .hitTarget(height: 40)
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func send() {
        guard let germID else { return }
        sending = true
        let reached = recipients
        Task {
            let done = await daycare.send(germID: germID, groupID: scope.isEmpty ? nil : scope,
                                          note: note.trimmingCharacters(in: .whitespacesAndNewlines))
            sending = false
            if done {
                model.toast = trCount(reached, one: "Sent to %lld family.", other: "Sent to %lld families.")
                dismiss()
            }
        }
    }
}

/// The daycare's code as a QR code, to share or print on a poster.
struct InviteScreen: View {
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @State private var poster: Image?

    var body: some View {
        ScrollView {
            if let info = daycare.director?.daycare {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(spacing: 10) {
                        if let image = QRCode.image(for: DaycareCode.link(info.code)) {
                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 170, height: 170)
                                .padding(10)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .accessibilityLabel(tr("QR code of the daycare"))
                        }
                        Text(tr("Daycare code"))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                        Text(verbatim: DaycareCode.display(info.code))
                            .font(.title.monospaced().weight(.heavy))
                            .kerning(3)
                            .foregroundStyle(palette.ink)
                            .textSelection(.enabled)
                        HStack(spacing: 10) {
                            ShareLink(item: inviteText(info)) {
                                Label(tr("Share"), systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(PillButtonStyle(kind: .ghost, height: 48))
                            if let poster {
                                ShareLink(item: poster, preview: SharePreview(info.name, image: poster)) {
                                    Label(tr("Poster"), systemImage: "printer.fill")
                                }
                                .buttonStyle(PillButtonStyle(kind: .ghost, height: 48))
                            }
                        }
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .germigoCard(radius: 28, padding: 18)
                    Text(tr("Parents open Germigo, then Crew, tap Join a daycare and scan this code or type it. They choose their child's group; you only see how many families each group has."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkTertiary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .task(id: info.code) {
                    poster = Self.renderPoster(name: info.name, code: info.code)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CharacterWash(tint: TabWash.crew))
        .navigationTitle(tr("Invite families"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func inviteText(_ info: DirectorDaycare) -> String {
        tr("Get %1$@'s illness notices on Germigo, free: open Crew, tap Join a daycare and enter the code %2$@.",
           info.name, DaycareCode.display(info.code)) + (AppConfig.serverURL == nil ? "" : " " + DaycareCode.link(info.code))
    }

    @MainActor
    private static func renderPoster(name: String, code: String) -> Image? {
        let renderer = ImageRenderer(content: DaycarePoster(name: name, code: code))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}

/// A letter-size page for the daycare's door: its name, its QR code and how to join.
private struct DaycarePoster: View {
    let name: String
    let code: String

    private let ink = Color(hex: Swatch.ink)

    var body: some View {
        VStack(spacing: 22) {
            Text(verbatim: "germigo")
                .font(.system(size: 34, weight: .black))
                .kerning(-1.4)
            VStack(spacing: 6) {
                Text(tr("Illness notices from"))
                    .font(.system(size: 20, weight: .semibold))
                    .opacity(0.7)
                Text(name)
                    .font(.system(size: 38, weight: .bold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .lineLimit(2)
            }
            if let image = QRCode.image(for: DaycareCode.link(code)) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 250, height: 250)
            }
            Text(verbatim: DaycareCode.display(code))
                .font(.system(size: 40, weight: .heavy, design: .monospaced))
                .kerning(6)
            VStack(alignment: .leading, spacing: 10) {
                step(1, tr("Get Germigo, free on the App Store."))
                step(2, tr("Open Crew, then tap Join a daycare."))
                step(3, tr("Scan this code or type it, then pick your child's group."))
            }
            Spacer(minLength: 0)
            Text(tr("Free for families. No names, no photos, no journal leave your phone."))
                .font(.system(size: 13, weight: .semibold))
                .opacity(0.6)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(ink)
        .padding(44)
        .frame(width: 612, height: 792)
        .background(Color.white)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: String(number))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 30, height: 30)
                .background(Color(hex: Swatch.green), in: Circle())
            Text(text)
                .font(.system(size: 18, weight: .medium))
        }
    }
}

/// The daycare's groups: rename, remove, add; families keep a group that is only renamed.
struct DaycareGroupsScreen: View {
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @State private var groups: [DaycareGroup] = []
    @State private var newGroup = ""
    @State private var loaded = false

    private var changed: Bool {
        loaded && groups.map { [$0.id, $0.name] } != (daycare.director?.daycare.groups ?? []).map { [$0.id, $0.name] }
    }

    var body: some View {
        List {
            Group {
                Section {
                    ForEach($groups) { $group in
                        HStack {
                            TextField(tr("Group name"), text: $group.name)
                                .foregroundStyle(palette.ink)
                                .onChange(of: group.name) { _, value in
                                    if value.count > DirectorLimits.groupName {
                                        group.name = String(value.prefix(DirectorLimits.groupName))
                                    }
                                }
                            if let families = group.families {
                                Text(trCount(families, one: "%lld family", other: "%lld families"))
                                    .font(.footnote)
                                    .foregroundStyle(palette.inkSecondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        groups.remove(atOffsets: offsets)
                    }
                    if groups.count < DirectorLimits.groups {
                        HStack {
                            TextField(tr("Add a group"), text: $newGroup)
                                .onSubmit(add)
                            Button(action: add) {
                                Image(systemName: "plus.circle.fill")
                                    .frame(width: 44, height: 44, alignment: .trailing)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .disabled(newGroup.trimmingCharacters(in: .whitespaces).count < 2)
                            .accessibilityLabel(tr("Add a group"))
                        }
                    }
                } footer: {
                    Text(tr("Renaming keeps the families in the group. Removing one moves its families to whole-daycare notices only."))
                }
                if let message = daycare.errorMessage {
                    Section {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                    }
                }
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Groups"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(tr("Save")) {
                    Task {
                        _ = await daycare.update(groups: groups.filter { $0.name.trimmingCharacters(in: .whitespaces).count >= 2 })
                        groups = daycare.director?.daycare.groups ?? groups
                    }
                }
                .disabled(!changed || daycare.isLoading)
            }
        }
        .onAppear {
            guard !loaded else { return }
            groups = daycare.director?.daycare.groups ?? []
            loaded = true
            daycare.errorMessage = nil
        }
    }

    private func add() {
        let name = newGroup.trimmingCharacters(in: .whitespaces)
        guard name.count >= 2, groups.count < DirectorLimits.groups,
              !groups.contains(where: { $0.name.lowercased() == name.lowercased() }) else { return }
        groups.append(DaycareGroup(id: "new-" + UUID().uuidString, name: String(name.prefix(DirectorLimits.groupName)),
                                   families: nil))
        newGroup = ""
    }
}

/// Notices by email: the address the daycare writes from, and the private address it writes to.
struct EmailNoticesScreen: View {
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @State private var email = ""
    @State private var copied = false

    var body: some View {
        ScrollView {
            if let info = daycare.director?.daycare {
                VStack(alignment: .leading, spacing: 14) {
                    if let inbox = info.inbox {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(tr("Your address"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.inkSecondary)
                            TextField(tr("director@daycare.ca"), text: $email)
                                .keyboardType(.emailAddress)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .foregroundStyle(palette.ink)
                                .padding(.horizontal, 14)
                                .frame(height: 50)
                                .background(palette.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Button(tr("Save")) {
                                Task {
                                    _ = await daycare.update(email: email.trimmingCharacters(in: .whitespaces))
                                }
                            }
                            .buttonStyle(PillButtonStyle(kind: .ink, height: 46))
                            .disabled(email.trimmingCharacters(in: .whitespaces) == (info.email ?? "") || daycare.isLoading)
                            Text(tr("Only emails from this address become notices."))
                                .font(.footnote)
                                .foregroundStyle(palette.inkTertiary)
                        }
                        .germigoCard()
                        if let sender = info.email {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(tr("Write to this private address from %@:", sender))
                                    .font(.subheadline)
                                    .foregroundStyle(palette.inkSecondary)
                                Button {
                                    UIPasteboard.general.string = inbox
                                    copied = true
                                } label: {
                                    HStack {
                                        Text(verbatim: inbox)
                                            .font(.callout.weight(.semibold))
                                            .foregroundStyle(palette.ink)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                        Spacer(minLength: 8)
                                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                            .foregroundStyle(palette.inkSecondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(height: 50)
                                    .background(palette.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .accessibilityLabel(tr("Copy the address"))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tr("Example"))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(palette.inkSecondary)
                                    Text(labeled(tr("Subject:"), example(info)))
                                        .font(.footnote)
                                        .foregroundStyle(palette.ink)
                                    Text(labeled(tr("Message:"), tr("3 children went home sick this morning.")))
                                        .font(.footnote)
                                        .foregroundStyle(palette.ink)
                                }
                                .padding(.leading, 10)
                                .overlay(alignment: .leading) {
                                    Rectangle()
                                        .fill(palette.ink.opacity(0.15))
                                        .frame(width: 2)
                                }
                                Label(tr("Germigo replies to confirm how many families got it. If the illness or the group is unclear, it asks instead of sending. Leave the group out to reach the whole daycare."),
                                      systemImage: "checkmark")
                                    .font(.footnote)
                                    .foregroundStyle(palette.inkSecondary)
                            }
                            .germigoCard()
                        }
                    } else {
                        Text(tr("Notices by email aren't set up on this server yet. Send them from the app in the meantime."))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .germigoCard()
                    }
                    if let message = daycare.errorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .onAppear {
                    email = info.email ?? ""
                    daycare.errorMessage = nil
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CharacterWash(tint: TabWash.crew))
        .navigationTitle(tr("Send by email"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func labeled(_ label: String, _ value: String) -> AttributedString {
        var head = AttributedString(label + " ")
        head.inlinePresentationIntent = .stronglyEmphasized
        return head + AttributedString(value)
    }

    private func example(_ info: DirectorDaycare) -> String {
        let illness = AppLanguage.isFrench ? "Gastro" : "Stomach bug"
        guard let group = info.groups.first else { return illness }
        return illness + " - " + group.name
    }
}

/// Renames the daycare, or closes it for good.
private struct DirectorSettingsSheet: View {
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmClose = false

    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        TextField(tr("Daycare name"), text: $name)
                            .onChange(of: name) { _, value in
                                if value.count > 40 { name = String(value.prefix(40)) }
                            }
                        Button(tr("Rename")) {
                            Task {
                                if await daycare.update(name: name.trimmingCharacters(in: .whitespaces)) { dismiss() }
                            }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).count < 2
                                  || name == daycare.director?.daycare.name || daycare.isLoading)
                    } header: {
                        Text(tr("Name"))
                    }
                    Section {
                        NavigationLink {
                            LegalScreen(kind: .terms)
                        } label: {
                            SettingsLabel(title: tr("Terms of Use"))
                        }
                    }
                    Section {
                        Button(tr("Close the daycare"), role: .destructive) {
                            confirmClose = true
                        }
                    } footer: {
                        Text(tr("Deletes its groups, its notices and its families' subscriptions from the server. Families stop getting notices."))
                    }
                    if let message = daycare.errorMessage {
                        Section {
                            Text(message)
                                .font(.footnote.weight(.semibold))
                        }
                    }
                }
                .listRowBackground(palette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("Daycare settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Done")) {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(tr("Close the daycare?"), isPresented: $confirmClose, titleVisibility: .visible) {
                Button(tr("Close for good"), role: .destructive) {
                    Task {
                        if await daycare.close() { dismiss() }
                    }
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(tr("Families stop getting notices. This can't be undone."))
            }
            .onAppear {
                name = daycare.director?.daycare.name ?? ""
                daycare.errorMessage = nil
            }
        }
        .tint(palette.ink)
    }
}

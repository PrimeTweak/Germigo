import SwiftUI

enum CrewEmblem {
    static let symbols = ["ladybug.fill", "leaf.fill", "star.fill", "sun.max.fill", "moon.stars.fill", "pawprint.fill"]

    static func symbol(_ index: Int) -> String {
        symbols[abs(index) % symbols.count]
    }
}

/// The Crew tab: daycare notices first, then the crew's offer, sign-up, or the crew itself.
struct CrewScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(CrewStore.self) private var crew
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @State private var showPaywall = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if !model.hasPass {
                    CrewTeaser(showPaywall: $showPaywall)
                } else if !crew.isConfigured, !crew.isDemo {
                    notice(symbol: "wifi.slash", title: tr("Crew is offline"),
                           detail: tr("The crew server isn't set up for this build yet."))
                } else if crew.isMember, let state = crew.state {
                    CrewHome(state: state)
                } else if crew.isMember {
                    waiting
                } else {
                    CrewJoinView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollEdgeEffectStyle(.hard, for: .top)
            .background(CharacterWash(tint: TabWash.crew))
            .navigationTitle(tr("Crew"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsButton()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: .crew)
            }
            .navigationDestination(for: DaycareRoute.self) { route in
                switch route {
                case .daycare(let id): DaycareScreen(id: id)
                case .notice(let id): NoticeScreen(id: id)
                case .director: DirectorScreen()
                }
            }
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
            }
            .task {
                await crew.refresh()
            }
            .task {
                await daycare.refresh()
            }
            .onChange(of: daycare.openedNoticeID, initial: true) { _, id in
                guard let id else { return }
                path.append(DaycareRoute.notice(id))
                daycare.openedNoticeID = nil
            }
        }
    }

    private var waiting: some View {
        VStack(spacing: 14) {
            if crew.isLoading {
                ProgressView()
            } else {
                Text(crew.errorMessage ?? tr("The crew server can't be reached right now."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                Button(tr("Try again")) {
                    Task {
                        await crew.refresh()
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .ink, height: 46))
                .frame(maxWidth: 220)
            }
        }
        .padding(32)
    }

    private func notice(symbol: String, title: String, detail: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(palette.inkTertiary)
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.ink)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

/// What the crew offers, shown until the Season Pass is active.
private struct CrewTeaser: View {
    @Binding var showPaywall: Bool
    @State private var confirmLeave = false
    @Environment(CrewStore.self) private var crew
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                DaycareSection()
                SectionHeader(title: tr("Crew"))
                ZStack {
                    Circle()
                        .fill(palette.accent.opacity(0.14))
                        .frame(width: 150, height: 150)
                    Circle()
                        .fill(palette.accent.opacity(0.2))
                        .frame(width: 104, height: 104)
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
                .padding(.top, 12)
                .accessibilityHidden(true)
                Text(crew.isMember ? tr("Your crew is waiting") : tr("Know what's going around"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                Text(tr("Start a private crew with the parents from your daycare group. See which germs are going around before they reach your couch."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 0) {
                    row("dot.radiowaves.left.and.right", tr("Going around"), tr("A germ shows up once 3 families report it. No names."))
                    Divider()
                    row("hand.thumbsup.fill", tr("Soup, tissues, tea"), tr("Send a little support when someone goes down."))
                    Divider()
                    row("trophy.fill", tr("Most valuable patient"), tr("A leaderboard nobody wants to win."))
                }
                .padding(.horizontal, 16)
                .germilyCard(padding: 0)
                Button(PurchaseManager.shared.offerLabel) {
                    showPaywall = true
                }
                .buttonStyle(PillButtonStyle(kind: .ink))
                if crew.isMember {
                    Button(tr("Leave crew and delete my data")) {
                        confirmLeave = true
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost, height: 46))
                    .disabled(crew.isLoading)
                    if let message = crew.errorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 28)
        }
        .confirmationDialog(tr("Leave this crew?"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(tr("Leave and delete"), role: .destructive) {
                Task {
                    _ = await crew.leave()
                }
            }
            Button(tr("Cancel"), role: .cancel) {}
        } message: {
            Text(tr("Removes your name, your reactions and the germs you shared from the server. Your journal stays on this phone."))
        }
    }

    private func row(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            IconTile(symbol: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
    }
}

/// How to start in a crew: join one with a code, or start one.
private enum CrewJoinMode: String, Identifiable {
    case join
    case create

    var id: String { rawValue }
}

/// The way into a crew: what a crew is for, and the two ways in, each opening its own sheet.
private struct CrewJoinView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var mode: CrewJoinMode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DaycareSection()
                SectionHeader(title: tr("Crew"))
                VStack(spacing: 6) {
                    faces
                        .padding(.bottom, 4)
                    Text(tr("Your parent crew"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.ink)
                    Text(tr("A private group with the parents you know. See what's going around, and send soup when a family goes down."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        choice(.join, symbol: "key.fill", title: tr("Join a crew"), detail: tr("I have a code"))
                        choice(.create, symbol: "flag.fill", title: tr("Start a crew"), detail: tr("Invite the others"))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
                Label(tr("Private · invite only"), systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 28)
        }
        .sheet(item: $mode) { mode in
            CrewJoinSheet(mode: mode)
        }
    }

    /// The parent among four others, leaning in like a group photo.
    private var faces: some View {
        let seats: [(look: Int, size: CGFloat, turn: Double, drop: CGFloat)] = [
            (1, 50, -8, 6), (2, 56, -3, 0), (model.data.hostLook, 64, 0, -4), (3, 56, 4, 0), (4, 50, 9, 6)
        ]
        return HStack(alignment: .bottom, spacing: -10) {
            ForEach(Array(seats.enumerated()), id: \.offset) { item in
                BuddyView(look: item.element.look, size: item.element.size)
                    .rotationEffect(.degrees(item.element.turn))
                    .offset(y: item.element.drop)
            }
        }
        .frame(height: 74)
        .accessibilityHidden(true)
    }

    private func choice(_ choice: CrewJoinMode, symbol: String, title: String, detail: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
        let sky = Color(hex: Swatch.skyLight)
        return Button {
            mode = choice
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(hex: palette.isDark ? Swatch.skyLight : Swatch.azureInk))
                    .frame(width: 48, height: 48)
                    .background(sky.opacity(palette.isDark ? 0.24 : 0.42), in: Circle())
                    .padding(.bottom, 8)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background, in: shape)
            .overlay(shape.strokeBorder(sky.opacity(0.6), lineWidth: 1.5))
            .contentShape(shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .combine)
    }
}

/// Joining with an invite code, or starting a crew with its emblem and name. Both ask for the name shown
/// to the crew and the rules, then send only that.
private struct CrewJoinSheet: View {
    let mode: CrewJoinMode
    @Environment(AppModel.self) private var model
    @Environment(CrewStore.self) private var crew
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var crewName = ""
    @State private var code = ""
    @State private var emblem = 0
    @State private var accepted = false
    @State private var legal: LegalKind?
    @State private var submitting = false

    private var canSubmit: Bool {
        let nameOK = displayName.trimmingCharacters(in: .whitespaces).count >= 2
        let detailOK = mode == .create
            ? crewName.trimmingCharacters(in: .whitespaces).count >= 2
            : code.count == CrewStore.codeLength
        return nameOK && detailOK && accepted && !crew.isLoading && !submitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if mode == .create {
                        preview
                        emblemPicker
                        field(tr("Crew name"), text: $crewName, limit: 24)
                    } else {
                        codeCard
                    }
                    field(tr("Your name in the crew"), text: $displayName, limit: 20)
                    rules
                    if let message = crew.errorMessage {
                        Text(message)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 4)
                    }
                    Button {
                        submit()
                    } label: {
                        if crew.isLoading || submitting {
                            ProgressView()
                        } else {
                            Text(mode == .create ? tr("Start the crew") : tr("Join the crew"))
                        }
                    }
                    .buttonStyle(PillButtonStyle(kind: .ink))
                    .disabled(!canSubmit)
                    .padding(.top, 6)
                    Text(tr("Crews are private and invite only. The server stores your crew name, the name you pick here and the germs you choose to share. Nothing else leaves your phone."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, Spacing.page)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(mode == .create ? tr("Start a crew") : tr("Join a crew"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Cancel"))
                }
            }
        }
        .onAppear {
            if displayName.isEmpty { displayName = model.data.profileName }
        }
        .sheet(item: $legal) { kind in
            NavigationStack {
                LegalScreen(kind: kind)
            }
        }
    }

    /// The eight boxes of the invite code, with the system's paste button for a code received by text.
    private var codeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(tr("Invite code"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.inkSecondary)
                Spacer(minLength: 8)
                PasteButton(payloadType: String.self) { strings in
                    code = CodeBoxes.clean(strings.first ?? "")
                }
                .labelStyle(.titleAndIcon)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(palette.accent)
            }
            CodeBoxes(code: $code)
        }
        .padding(14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    /// The crew's card as the others will see it, while its emblem and name are picked.
    private var preview: some View {
        HStack(spacing: 14) {
            Image(systemName: CrewEmblem.symbol(emblem))
                .font(.title2)
                .foregroundStyle(Color.white)
                .frame(width: 54, height: 54)
                .background(LinearGradient(colors: [Color(hex: Swatch.coralLight), Color(hex: Swatch.coralDeep)],
                                           startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(crewName.isEmpty ? tr("Crew name") : crewName)
                    .font(.headline)
                    .foregroundStyle(crewName.isEmpty ? palette.inkTertiary : palette.ink)
                    .lineLimit(1)
                Text(tr("Just you, for now"))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(palette.background, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                .strokeBorder(Color(hex: Swatch.skyLight).opacity(0.6), lineWidth: 1.5)
        }
        .accessibilityElement(children: .combine)
    }

    private func field(_ title: String, text: Binding<String>, limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.inkSecondary)
            TextField(title, text: text, prompt: Text(""))
                .textInputAutocapitalization(.words)
                .font(.body)
                .foregroundStyle(palette.ink)
                .frame(minHeight: 30)
                .onChange(of: text.wrappedValue) { _, newValue in
                    if newValue.count > limit { text.wrappedValue = String(newValue.prefix(limit)) }
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    private var rules: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $accepted) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("I agree to the crew rules"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Text(tr("Be kind. No offensive names, no harassment. Offenders are removed."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
            }
            .tint(palette.accent)
            Divider()
            HStack(spacing: 18) {
                Button(tr("Terms of Use")) {
                    legal = .terms
                }
                Button(tr("Health data policy")) {
                    legal = .health
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.accent)
        }
        .padding(14)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    private var emblemPicker: some View {
        HStack(spacing: 8) {
            ForEach(Array(CrewEmblem.symbols.enumerated()), id: \.offset) { item in
                Button {
                    emblem = item.offset
                } label: {
                    Image(systemName: item.element)
                        .font(.title3)
                        .foregroundStyle(emblem == item.offset ? palette.background : palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(emblem == item.offset ? palette.ink : palette.surface,
                                    in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Emblem %lld", item.offset + 1))
                .accessibilityAddTraits(emblem == item.offset ? .isSelected : [])
            }
        }
    }

    private func submit() {
        guard !submitting else { return }
        submitting = true
        let name = displayName.trimmingCharacters(in: .whitespaces)
        Task {
            let joined: Bool
            if mode == .create {
                joined = await crew.create(name: crewName.trimmingCharacters(in: .whitespaces), displayName: name, emblem: emblem)
            } else {
                joined = await crew.join(code: code, displayName: name)
            }
            submitting = false
            if joined {
                if model.data.settings.crewAlertsOn {
                    await model.enableReminders()
                }
                dismiss()
            }
        }
    }
}

/// The invite code as eight boxes over a hidden field: letters and digits only, in capitals.
private struct CodeBoxes: View {
    @Binding var code: String
    @FocusState private var focused: Bool
    @Environment(\.palette) private var palette

    static func clean(_ text: String) -> String {
        String(text.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(CrewStore.codeLength))
    }

    var body: some View {
        let characters = Array(code)
        ZStack {
            TextField(tr("Invite code"), text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .focused($focused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 6) {
                ForEach(0..<CrewStore.codeLength, id: \.self) { index in
                    let current = focused && index == min(characters.count, CrewStore.codeLength - 1)
                    Text(index < characters.count ? String(characters[index]) : " ")
                        .font(.title3.monospaced().weight(.bold))
                        .foregroundStyle(palette.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(palette.background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(current ? palette.accent : palette.ink.opacity(0.12), lineWidth: current ? 2.5 : 1.5)
                        }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .frame(height: 46)
        .contentShape(Rectangle())
        .onTapGesture {
            focused = true
        }
        .onChange(of: code) { _, value in
            let cleaned = Self.clean(value)
            if cleaned != value { code = cleaned }
        }
    }
}

private struct ReportTarget: Identifiable {
    let id: String
    let name: String
}

/// The crew itself: who is in it, what is going around, the feed, the leaderboard and the members.
private struct CrewHome: View {
    let state: CrewState
    @Environment(AppModel.self) private var model
    @Environment(CrewStore.self) private var crew
    @Environment(DaycareStore.self) private var daycare
    @Environment(\.palette) private var palette
    @State private var reportTarget: ReportTarget?
    @State private var showReported = false
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DaycareSection()
                SectionHeader(title: tr("Crew"))
                header
                radar
                feed
                leaderboard
                members
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 28)
        }
        .refreshable {
            await crew.refresh()
            await daycare.refresh()
        }
        .confirmationDialog(tr("Report"), isPresented: reportBinding, titleVisibility: .visible,
                            presenting: reportTarget) { target in
            Button(tr("Offensive name")) {
                send(target, reason: "name")
            }
            Button(tr("Harassment or spam")) {
                send(target, reason: "abuse")
            }
            Button(tr("Something else")) {
                send(target, reason: "other")
            }
            Button(tr("Cancel"), role: .cancel) {}
        } message: { target in
            Text(tr("What's wrong with %@? Every report is reviewed within 24 hours.", target.name))
        }
        .alert(tr("Report sent"), isPresented: $showReported) {
            Button(tr("OK"), role: .cancel) {}
        } message: {
            Text(tr("Thanks. This member is now hidden on your phone, and the report is reviewed within 24 hours."))
        }
        .sheet(isPresented: $showSettings) {
            CrewSettingsSheet()
        }
    }

    private var footnote: String {
        var text = tr("Report or block anyone from the menu next to their name. Reports are reviewed within 24 hours.")
        if crew.isDemo {
            text = tr("A sample crew for this test build. Nothing leaves this phone.") + " " + text
        }
        if let email = AppConfig.supportEmail {
            text += " " + tr("Contact: %@", email)
        }
        return text
    }

    private var reportBinding: Binding<Bool> {
        Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } })
    }

    private func send(_ target: ReportTarget, reason: String) {
        Task {
            if await crew.report(memberID: target.id, reason: reason) {
                crew.block(target.id)
                showReported = true
            }
        }
    }

    /// A member's character: the parent's own look for them, the crew's color for the others.
    private func look(of member: CrewMember) -> Int {
        member.id == state.me.id ? model.data.hostLook : member.colorIndex
    }

    private var header: some View {
        let faces = state.members.filter { !crew.blockedIDs.contains($0.id) }.prefix(6)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: CrewEmblem.symbol(state.crew.emblem))
                    .font(.title2)
                    .foregroundStyle(Color.white)
                    .frame(width: 60, height: 60)
                    .background(LinearGradient(colors: [Color(hex: Swatch.coralLight), Color(hex: Swatch.coralDeep)],
                                               startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.crew.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    Text(tr("Crew") + " · " + trCount(state.crew.families, one: "%lld family", other: "%lld families"))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            Rectangle()
                .fill(palette.ink.opacity(0.1))
                .frame(height: 1)
                .padding(.vertical, 12)
            HStack(spacing: 8) {
                HStack(spacing: -6) {
                    ForEach(Array(faces.enumerated()), id: \.element.id) { item in
                        BuddyView(look: look(of: item.element), size: 40)
                            .cascadeIn(item.offset)
                    }
                }
                Spacer(minLength: 8)
                Label(tr("Private · invite only"), systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    actions
                }
                VStack(spacing: 10) {
                    actions
                }
            }
            .padding(.top, 14)
        }
        .padding(16)
        .background(LinearGradient(colors: [Color(hex: Swatch.coralPale).opacity(palette.isDark ? 0.25 : 0.45), palette.surface],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    /// Invite and crew settings, side by side, or stacked when the labels don't fit.
    @ViewBuilder
    private var actions: some View {
        ShareLink(item: tr("Join my Germily crew \"%1$@\" with the code %2$@.", state.crew.name, state.crew.code)) {
            Label(tr("Invite parents"), systemImage: "person.badge.plus")
                .fixedSize()
        }
        .buttonStyle(PillButtonStyle(kind: .ink, height: 44))
        Button {
            showSettings = true
        } label: {
            Label(tr("Crew settings"), systemImage: "gearshape")
                .fixedSize()
        }
        .buttonStyle(PillButtonStyle(kind: .ghost, height: 44))
    }

    @ViewBuilder
    private var feed: some View {
        SectionHeader(title: tr("Feed"))
        if crew.visibleFeed.isEmpty {
            Text(tr("Quiet week. Suspicious."))
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
                .germilyCard()
        } else {
            ForEach(crew.visibleFeed.prefix(20)) { event in
                let isMine = event.memberID == state.me.id
                FeedRow(event: event, isMine: isMine, look: isMine ? model.data.hostLook : event.colorIndex) {
                    reportTarget = ReportTarget(id: event.memberID, name: event.name)
                }
            }
        }
    }

    private var radar: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: tr("Going around"), trailing: tr("This week"))
            if state.radar.isEmpty {
                Text(tr("All clear. For now."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
            }
            ForEach(Array(state.radar.enumerated()), id: \.element.id) { item in
                RadarRow(entry: item.element, families: state.crew.families)
                    .cascadeIn(item.offset)
            }
            Label(tr("A germ shows up once 3 families report it. No names."), systemImage: "shield.lefthalf.filled")
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
        }
        .germilyCard()
    }

    @ViewBuilder
    private var leaderboard: some View {
        let board = Array(crew.leaderboard.prefix(5))
        if !board.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: tr("Most valuable patient"), trailing: tr("Season"))
                Text(tr("A leaderboard nobody wants to win."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.top, 2)
                Podium(places: board.map { member in
                    PodiumPlace(id: member.id, look: look(of: member), sick: true,
                                name: member.id == state.me.id ? tr("You") : member.name,
                                detail: trCount(member.germs, one: "%lld germ", other: "%lld germs"),
                                rank: board.filter { $0.germs > member.germs }.count + 1)
                })
                .padding(.top, 14)
            }
            .germilyCard()
        }
    }

    @ViewBuilder
    private var members: some View {
        let others = state.members.filter { $0.id != state.me.id && !crew.blockedIDs.contains($0.id) }
        if !others.isEmpty {
            SectionHeader(title: tr("Members"))
            VStack(spacing: 0) {
                ForEach(Array(others.enumerated()), id: \.element.id) { item in
                    if item.offset > 0 {
                        Divider()
                    }
                    HStack(spacing: 12) {
                        BuddyView(look: look(of: item.element), size: 36)
                        Text(item.element.name)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Spacer()
                        MemberMenu {
                            reportTarget = ReportTarget(id: item.element.id, name: item.element.name)
                        } onBlock: {
                            crew.block(item.element.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
            .germilyCard(padding: 0)
        }
    }
}

/// The report and block menu attached to another member.
private struct MemberMenu: View {
    let onReport: () -> Void
    let onBlock: () -> Void
    @Environment(\.palette) private var palette

    init(onReport: @escaping () -> Void, onBlock: @escaping () -> Void) {
        self.onReport = onReport
        self.onBlock = onBlock
    }

    var body: some View {
        Menu {
            Button {
                onReport()
            } label: {
                Label(tr("Report"), systemImage: "flag")
            }
            Button(role: .destructive) {
                onBlock()
            } label: {
                Label(tr("Block"), systemImage: "hand.raised")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.bold))
                .foregroundStyle(palette.inkSecondary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(tr("More"))
    }
}

/// One post of the feed: who caught or beat which germ, and the stickers sent back.
private struct FeedRow: View {
    let event: FeedEvent
    let isMine: Bool
    let look: Int
    let onReport: () -> Void
    @Environment(AppModel.self) private var model
    @Environment(CrewStore.self) private var crew
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How many times each sticker was just sent, to replay its flight.
    @State private var flights: [String: Int] = [:]
    /// The stamp's lettering, following the text size set in iOS up to a cap.
    @ScaledMetric(relativeTo: .caption2) private var stampSize: CGFloat = 11

    private struct Flight {
        var rise: CGFloat = 0
        var scale: CGFloat = 0.6
        var opacity: Double = 0
    }

    var body: some View {
        if let germ = model.catalog.germ(event.germID) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    BuddyView(look: look, sick: !event.isWin, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(headline(germ))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(event.date.formatted(.relative(presentation: .named)))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    Spacer(minLength: 4)
                    germTile(germ)
                    if !isMine {
                        MemberMenu {
                            onReport()
                        } onBlock: {
                            crew.block(event.memberID)
                        }
                    }
                }
                HStack(spacing: 8) {
                    ForEach(CrewStore.reactionKinds, id: \.self) { kind in
                        reaction(kind)
                    }
                }
            }
            .padding(14)
            .background(event.isWin ? Color(hex: Swatch.lime).opacity(palette.isDark ? 0.16 : 0.24) : palette.surface,
                        in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
    }

    private func headline(_ germ: Germ) -> String {
        if event.isWin {
            return isMine ? tr("You beat %@", germ.phrase.value) : tr("%1$@ beat %2$@", event.name, germ.phrase.value)
        }
        return isMine ? tr("You caught %@", germ.phrase.value) : tr("%1$@ caught %2$@", event.name, germ.phrase.value)
    }

    /// The germ on its tint; once beaten, faded, tilted and stamped.
    private func germTile(_ germ: Germ) -> some View {
        GermImage(germ: germ, size: 42, silhouette: !event.isWin && model.count(of: germ.id) == 0)
            .foregroundStyle(palette.ink.opacity(0.3))
            .saturation(event.isWin ? 0.35 : 1)
            .rotationEffect(.degrees(event.isWin ? -14 : 0))
            .frame(width: 52, height: 52)
            .background(germ.tileTint(palette), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if event.isWin {
                    Text(verbatim: "K.O.")
                        .font(.system(size: min(stampSize, 17), weight: .black))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: Swatch.coral), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                        .rotationEffect(.degrees(8))
                        .offset(x: 7, y: -7)
                }
            }
            .accessibilityHidden(true)
    }

    private func reaction(_ kind: String) -> some View {
        let count = event.reactions[kind] ?? 0
        let mine = event.mine.contains(kind)
        return Button {
            Haptics.tap()
            if !mine && !reduceMotion { flights[kind, default: 0] += 1 }
            Task {
                await crew.react(to: event.id, kind: kind)
            }
        } label: {
            HStack(spacing: 5) {
                Image("sticker-" + kind)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                if count > 0 {
                    Text(String(count))
                        .font(.footnote.weight(.bold).monospacedDigit())
                        .foregroundStyle(palette.ink)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 42)
            .frame(minWidth: 54)
            .background(mine ? palette.accent.opacity(0.35) : palette.ink.opacity(0.06), in: Capsule())
            .overlay {
                Capsule().strokeBorder(mine ? palette.ink : Color.clear, lineWidth: 2)
            }
            .hitTarget(height: 42)
            .animation(Tempo.quick, value: count)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            flight(kind)
        }
        .accessibilityLabel(reactionName(kind))
        .accessibilityValue(String(count))
        .accessibilityAddTraits(mine ? .isSelected : [])
    }

    /// The sticker leaving the button when it is sent.
    private func flight(_ kind: String) -> some View {
        Image("sticker-" + kind)
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40)
            .keyframeAnimator(initialValue: Flight(), trigger: flights[kind] ?? 0) { content, value in
                content
                    .scaleEffect(value.scale)
                    .offset(y: value.rise)
                    .opacity(value.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.rise) {
                    CubicKeyframe(-8, duration: 0.05)
                    CubicKeyframe(-84, duration: 0.75)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(1.3, duration: 0.25)
                    CubicKeyframe(1, duration: 0.55)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.05)
                    LinearKeyframe(1, duration: 0.45)
                    LinearKeyframe(0, duration: 0.3)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func reactionName(_ kind: String) -> String {
        switch kind {
        case "soup": return tr("Send soup")
        case "tissue": return tr("Send tissues")
        case "tea": return tr("Send tea")
        default: return tr("Send love")
        }
    }
}

/// The parent's place in the crew: the crew and its code, what is shared, the name shown, and leaving.
private struct CrewSettingsSheet: View {
    @Environment(CrewStore.self) private var crew
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var renamed = false
    @State private var copied = false
    @State private var confirmLeave = false

    private static let nameLimit = 20

    private var sharesName: Binding<Bool> {
        Binding(get: { crew.sharesName }, set: { crew.setSharesName($0) })
    }

    private var typedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let state = crew.state {
                        crewCard(state)
                    }
                    SectionHeader(title: tr("Sharing"))
                    Toggle(isOn: sharesName) {
                        SettingsRowLabel(symbol: crew.sharesName ? "eye.fill" : "eye.slash.fill", title: tr("Show my germs"),
                                         detail: tr("In the feed and the leaderboard, with your name"), trigger: crew.sharesName)
                    }
                    .frame(minHeight: 54)
                    .padding(.horizontal, 14)
                    .germilyCard(padding: 0)
                    caption(tr("Off, they still count on the radar, without your name."))
                    SectionHeader(title: tr("Your name"))
                    nameCard
                    nameStatus
                    if !crew.blockedIDs.isEmpty {
                        Button {
                            crew.unblockAll()
                        } label: {
                            SettingsRow(symbol: "person.crop.circle.badge.checkmark",
                                        title: tr("Unblock everyone (%lld)", crew.blockedIDs.count)) {}
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 14)
                        .germilyCard(padding: 0)
                        .padding(.top, 12)
                    }
                    Button {
                        confirmLeave = true
                    } label: {
                        SettingsRow(symbol: "rectangle.portrait.and.arrow.right", title: tr("Leave the crew"), tint: .red) {}
                    }
                    .buttonStyle(.plain)
                    .disabled(crew.isLoading)
                    .padding(.horizontal, 14)
                    .germilyCard(padding: 0)
                    .padding(.top, 12)
                    caption(tr("Removes your name, your reactions and the germs you shared from the server. Your journal stays on this phone."))
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 28)
            }
            .background(palette.background.ignoresSafeArea())
            .tint(palette.accent)
            .navigationTitle(tr("Crew settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            if await saveName() { dismiss() }
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(tr("Done"))
                    .tint(palette.ink)
                }
            }
            .onAppear {
                name = crew.state?.me.name ?? ""
            }
            .confirmationDialog(tr("Leave this crew?"), isPresented: $confirmLeave, titleVisibility: .visible) {
                Button(tr("Leave and delete"), role: .destructive) {
                    Task {
                        if await crew.leave() { dismiss() }
                    }
                }
                Button(tr("Cancel"), role: .cancel) {}
            }
        }
    }

    /// The crew's emblem, name and size, and its invite code, copied with a touch.
    private func crewCard(_ state: CrewState) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: CrewEmblem.symbol(state.crew.emblem))
                    .font(.title3)
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(LinearGradient(colors: [Color(hex: Swatch.coralLight), Color(hex: Swatch.coralDeep)],
                                               startPoint: .top, endPoint: .bottom),
                                in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.crew.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    Text(trCount(state.crew.families, one: "%lld family", other: "%lld families"))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 62)
            .accessibilityElement(children: .combine)
            Divider()
                .padding(.leading, 44)
            Button {
                Clipboard.copy(state.crew.code)
                Haptics.tap()
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    copied = false
                }
            } label: {
                SettingsRow(symbol: "number", title: tr("Invite code")) {
                    HStack(spacing: 8) {
                        Text(verbatim: state.crew.code)
                            .font(.callout.weight(.semibold))
                            .tracking(1.5)
                            .foregroundStyle(palette.ink)
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityValue(copied ? tr("Copied") : state.crew.code)
        }
        .padding(.horizontal, 14)
        .germilyCard(padding: 0)
    }

    private var nameCard: some View {
        HStack(spacing: 12) {
            SettingsTile(symbol: "person.fill")
            TextField(tr("Your name in the crew"), text: $name)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .foregroundStyle(palette.ink)
                .onSubmit {
                    Task {
                        _ = await saveName()
                    }
                }
                .onChange(of: name) { _, newValue in
                    renamed = false
                    if newValue.count > Self.nameLimit { name = String(newValue.prefix(Self.nameLimit)) }
                }
        }
        .frame(minHeight: 54)
        .padding(.horizontal, 14)
        .germilyCard(padding: 0)
    }

    /// Who sees the name, then whether it was saved or what went wrong.
    @ViewBuilder
    private var nameStatus: some View {
        if let message = crew.errorMessage {
            caption(message)
        } else if renamed {
            Label(tr("Name saved."), systemImage: "checkmark")
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .padding(.horizontal, 8)
        } else {
            caption(tr("The crew sees it in the feed, the leaderboard and the members."))
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(palette.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
    }

    /// Saves a changed name of two letters or more; true when there was nothing to save or it was saved.
    private func saveName() async -> Bool {
        let current = crew.state?.me.name ?? ""
        guard typedName.count >= 2, typedName != current else { return true }
        renamed = await crew.rename(typedName)
        return renamed
    }
}

/// One germ going around: its face, how many families reported it this week, out of the whole crew.
struct RadarRow: View {
    let entry: RadarEntry
    let families: Int
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        if let germ = model.catalog.germ(entry.germID) {
            let total = max(families, entry.families, 1)
            HStack(spacing: 12) {
                GermImage(germ: germ, size: 42)
                    .frame(width: 54, height: 54)
                    .background(germ.tileTint(palette), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(germ.name)
                            .font(.body.weight(.bold))
                            .foregroundStyle(palette.ink)
                        Text(germ.illness.value)
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(tr("%1$lld of %2$lld", entry.families, total))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(palette.ink)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(palette.ink.opacity(0.09))
                            Capsule()
                                .fill(germ.deepTint)
                                .frame(width: proxy.size.width * CGFloat(entry.families) / CGFloat(total))
                        }
                    }
                    .frame(height: 10)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(germ.name + ", " + germ.illness.value)
            .accessibilityValue(trCount(entry.families, one: "%lld family", other: "%lld families"))
        }
    }
}

import SwiftUI

/// Who the symptom pages are about.
enum Patient: Hashable {
    case kid(UUID)
    case newKid
    case me
    case partner

    /// Who the parent's log is for when this patient is one of the parents.
    var sufferer: Sufferer {
        self == .partner ? .partner : .me
    }
}

/// What opens the symptom pages: the parent, someone else newly sick, or an entry whose signs changed.
enum SymptomFlow: Identifiable {
    case me
    case someone
    case kidIllness(UUID)
    case log(UUID)

    var id: String {
        switch self {
        case .me: return "me"
        case .someone: return "someone"
        case .kidIllness(let illnessID): return "illness-" + illnessID.uuidString
        case .log(let logID): return "log-" + logID.uuidString
        }
    }

    var isNew: Bool {
        switch self {
        case .me, .someone: return true
        case .kidIllness, .log: return false
        }
    }
}

/// Where the symptom pages hand over: closing, the parent's log sheet, or a kid's new illness.
struct FlowExits {
    let close: () -> Void
    let onLog: (LogRequest) -> Void
    let onAdded: (KidIllness) -> Void
}

/// What the kid's illness form starts with when it follows the symptom pages.
struct KidFormSeed: Hashable {
    var kidID: UUID?
    var germID: String?
    var symptoms: [String] = []
}

/// The symptom pages: who is sick when it is someone else, then the signs, the suspects, and a pick.
struct SymptomFlowSheet: View {
    let flow: SymptomFlow
    /// Receives the request for the log sheet, which opens once this sheet has closed.
    let onLog: (LogRequest) -> Void
    /// Receives a kid's illness added from these pages.
    let onAdded: (KidIllness) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let exits = FlowExits(close: { dismiss() }, onLog: onLog, onAdded: onAdded)
        NavigationStack {
            Group {
                if case .someone = flow {
                    WhoPage(exits: exits)
                } else {
                    SymptomPicker(flow: flow, start: .me, exits: exits)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Close"))
                }
            }
        }
    }
}

/// "Someone's sick": the kids and the partner as big characters, and a new kid.
private struct WhoPage: View {
    /// One person to pick, with a line about their record.
    private struct Choice: Identifiable {
        let patient: Patient
        let name: String
        let look: Int
        let line: String
        let locked: Bool

        var id: Patient { patient }
    }

    let exits: FlowExits
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var picked: Patient?
    @State private var showPaywall = false

    private var choices: [Choice] {
        let now = Date()
        var list = model.data.kids.map { kid in
            Choice(patient: .kid(kid.id), name: kid.name, look: kid.colorIndex, line: kidLine(kid, now: now),
                   locked: !model.isKidOpen(kid.id))
        }
        if model.data.partnerName != nil {
            list.append(Choice(patient: .partner, name: model.partnerDisplayName, look: model.data.partnerLook,
                               line: partnerLine(now: now), locked: !model.hasPass))
        }
        return list
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(tr("Who's sick?"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(tr("Tap the patient."))
                    .font(.callout)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.top, 6)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(Array(choices.enumerated()), id: \.element.id) { item in
                        card(item.element)
                            .cascadeIn(item.offset)
                    }
                    addCard
                        .cascadeIn(choices.count)
                }
                .padding(.top, 18)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $picked) { patient in
            SymptomPicker(flow: .someone, start: patient, exits: exits)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func card(_ choice: Choice) -> some View {
        Button {
            Haptics.tap()
            if choice.locked {
                showPaywall = true
            } else {
                picked = choice.patient
            }
        } label: {
            VStack(spacing: 4) {
                BuddyView(look: choice.look, sick: true, size: 92, lively: true)
                    .overlay(alignment: .topTrailing) {
                        if choice.locked { PassLock() }
                    }
                    .padding(.bottom, 6)
                Text(choice.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                Text(choice.line)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private var addCard: some View {
        Button {
            Haptics.tap()
            if model.canAddKid {
                picked = .newKid
            } else {
                showPaywall = true
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 92, height: 92)
                    .background(palette.surface, in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if !model.canAddKid { PassLock() }
                    }
                    .padding(.bottom, 6)
                Text(tr("A new kid"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(tr("Add them in one step"))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(palette.ink.opacity(0.18), style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
            }
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func kidLine(_ kid: Kid, now: Date) -> String {
        let illnesses = model.data.kidIllnesses.filter { $0.kidID == kid.id }
        if illnesses.contains(where: { DayEngine.isGoingOn($0, catalog: model.catalog, now: now) }) {
            return tr("Sick right now")
        }
        if illnesses.isEmpty { return tr("Clean record so far") }
        return trCount(illnesses.count, one: "Brought home %lld germ", other: "Brought home %lld germs")
    }

    private func partnerLine(now: Date) -> String {
        let logs = model.data.logs.filter { $0.sufferer.includesPartner }
        if logs.contains(where: { $0.endedAt == nil }) { return tr("Sick right now") }
        guard let last = logs.compactMap({ $0.endedAt }).max() else { return tr("Clean record so far") }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
        return trCount(max(0, days), one: "Clean for %lld day", other: "Clean for %lld days")
    }
}

/// Tick what you see or feel, meet the suspects, pick one or keep it a mystery.
private struct SymptomPicker: View {
    let flow: SymptomFlow
    /// Who the pages are about on a new entry; an existing entry brings its own.
    let start: Patient
    let exits: FlowExits

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var patient = Patient.me
    @State private var chosen: Set<String> = []
    @State private var newKidName = ""
    @State private var showSuspects = false
    @State private var showUrgent = false
    @State private var direct: KidFormSeed?
    @State private var didPrefill = false

    private var needsName: Bool {
        patient == .newKid && newKidName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var canProceed: Bool {
        !chosen.isEmpty && !needsName
    }

    private var orderedIDs: [String] {
        Symptom.ordered(chosen).map { $0.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                patientRow
                Text(patient == .me ? tr("What do you feel?") : tr("What do you see?"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(tr("Tap everything that fits. You can change it later."))
                    .font(.callout)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.top, 6)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3), spacing: 9) {
                    ForEach(Array(Symptom.all.enumerated()), id: \.element.id) { item in
                        SymptomTile(symptom: item.element, isOn: chosen.contains(item.element.id)) {
                            toggle(item.element.id)
                        }
                        .cascadeIn(item.offset / 3)
                    }
                }
                .padding(.top, 18)
                urgentRow
                    .padding(.top, 9)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Symptoms"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .navigationDestination(isPresented: $showSuspects) {
            SuspectsPage(flow: flow, patient: patient, chosen: chosen, exits: exits)
        }
        .navigationDestination(isPresented: $showUrgent) {
            UrgentPage(flow: flow, patient: patient, chosen: chosen, exits: exits)
        }
        .navigationDestination(item: $direct) { seed in
            KidIllnessForm(seed: seed, onDone: exits.close, onAdded: exits.onAdded)
        }
        .onAppear(perform: prefill)
    }

    /// The patient's name over the signs; the parent needs none, a new kid needs one typed.
    @ViewBuilder
    private var patientRow: some View {
        switch patient {
        case .me:
            EmptyView()
        case .newKid:
            VStack(alignment: .leading, spacing: 10) {
                patientChip(tr("A new kid"), look: model.nextKidLook)
                TextField(tr("Kid's name"), text: $newKidName)
                    .textInputAutocapitalization(.words)
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .padding(.bottom, 18)
        case .kid(let kidID):
            patientChip(model.name(for: .kid(kidID)), look: model.look(of: .kid(kidID)))
                .padding(.bottom, 18)
        case .partner:
            patientChip(model.partnerDisplayName, look: model.data.partnerLook)
                .padding(.bottom, 18)
        }
    }

    private func patientChip(_ name: String, look: Int) -> some View {
        HStack(spacing: 8) {
            BuddyView(look: look, sick: true, size: 30)
            Text(name)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(palette.background)
        .padding(.leading, 9)
        .padding(.trailing, 18)
        .frame(height: 46)
        .background(palette.ink, in: Capsule())
        .padding(.top, 6)
    }

    private var urgentRow: some View {
        let isOn = chosen.contains(Symptom.urgentID)
        return Button {
            Haptics.tap()
            toggle(Symptom.urgentID)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: Symptom.urgent.symbol)
                    .font(.title3)
                    .foregroundStyle(isOn ? palette.accent : palette.inkSecondary)
                    .symbolEffect(.bounce, value: isOn)
                Text(Symptom.urgent.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Spacer(minLength: 8)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isOn ? palette.accent : palette.inkTertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 56)
            .background(isOn ? palette.accent.opacity(palette.isDark ? 0.2 : 0.13) : palette.surface,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(isOn ? palette.accent : Color.clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            Button {
                proceed()
            } label: {
                HStack(spacing: 10) {
                    Text(chosen.isEmpty ? tr("Tap a symptom first") : tr("See the suspects"))
                    if !chosen.isEmpty {
                        Text(verbatim: String(chosen.count))
                            .font(.footnote.weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .padding(.horizontal, 9)
                            .frame(minWidth: 26, minHeight: 26)
                            .background(palette.background.opacity(0.22), in: Capsule())
                    }
                }
            }
            .buttonStyle(PillButtonStyle(kind: .ink, height: 56))
            .disabled(!canProceed)
            if flow.isNew {
                Button {
                    skipToPicker()
                } label: {
                    HStack(spacing: 4) {
                        Text(tr("I know what it is"))
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                    }
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(minHeight: 30)
                    .hitTarget(height: 30)
                }
                .buttonStyle(.plain)
                .disabled(needsName)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .animation(Tempo.quick, value: chosen.count)
    }

    private func toggle(_ id: String) {
        if chosen.contains(id) {
            chosen.remove(id)
        } else {
            chosen.insert(id)
        }
    }

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        switch flow {
        case .me, .someone:
            patient = start
        case .kidIllness(let illnessID):
            if let illness = model.data.kidIllnesses.first(where: { $0.id == illnessID }) {
                patient = .kid(illness.kidID)
                chosen = Set(illness.symptoms)
            }
        case .log(let logID):
            let log = model.data.logs.first { $0.id == logID }
            patient = log?.sufferer == .partner ? .partner : .me
            chosen = Set(log?.symptoms ?? [])
        }
    }

    /// A first kid typed on this page joins the household before the next one opens.
    private func ensureKid() {
        guard patient == .newKid else { return }
        let kid = Kid(name: newKidName.trimmingCharacters(in: .whitespaces), colorIndex: model.nextKidLook)
        model.saveKid(kid)
        patient = .kid(kid.id)
    }

    private func proceed() {
        guard canProceed else { return }
        ensureKid()
        if chosen.contains(Symptom.urgentID) {
            showUrgent = true
        } else {
            showSuspects = true
        }
    }

    /// The classic way in: the germ list, with the ticked signs kept.
    private func skipToPicker() {
        guard !needsName else { return }
        ensureKid()
        switch patient {
        case .kid(let kidID):
            direct = KidFormSeed(kidID: kidID, germID: nil, symptoms: orderedIDs)
        case .newKid:
            break
        case .me, .partner:
            exits.onLog(LogRequest(symptoms: orderedIDs, sufferer: patient.sufferer))
            exits.close()
        }
    }
}

/// One sign of the picker: its symbol, its name, and a check once ticked.
private struct SymptomTile: View {
    let symptom: Symptom
    let isOn: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Image(systemName: symptom.symbol)
                        .font(.title3)
                        .foregroundStyle(isOn ? palette.accent : palette.inkSecondary)
                        .symbolEffect(.bounce, value: isOn)
                        .frame(height: 26)
                    Spacer(minLength: 0)
                    if isOn {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(palette.accent)
                            .motionTransition(.scale.combined(with: .opacity))
                    }
                }
                Spacer(minLength: 6)
                Text(symptom.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 88)
            .background(isOn ? palette.accent.opacity(palette.isDark ? 0.2 : 0.13) : palette.surface,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(isOn ? palette.accent : Color.clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .animation(Tempo.pop, value: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Trouble breathing was ticked: the help lines come before any guess.
private struct UrgentPage: View {
    let flow: SymptomFlow
    let patient: Patient
    let chosen: Set<String>
    let exits: FlowExits
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: Symptom.urgent.symbol)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(palette.ink)
                    .symbolEffect(.pulse)
                    .frame(width: 108, height: 108)
                    .background(palette.surface, in: Circle())
                    .padding(.top, 20)
                    .accessibilityHidden(true)
                Text(tr("Trouble breathing can't wait"))
                    .font(.title.weight(.bold))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                Text(tr("Germigo doesn't guess on this one. Call a health line now, or the emergency number if it looks serious."))
                    .font(.body)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                NavigationLink {
                    HelpLinesScreen()
                } label: {
                    Text(tr("Help lines"))
                }
                .buttonStyle(PillButtonStyle(kind: .ink))
                .padding(.top, 10)
                if chosen.count > 1 {
                    NavigationLink {
                        SuspectsPage(flow: flow, patient: patient, chosen: chosen, exits: exits)
                    } label: {
                        Text(tr("See the suspects anyway"))
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
                }
                Text(HealthNotice.text)
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The germs that fit the ticked signs, best fits first. A guess for the logbook, never a diagnosis.
private struct SuspectsPage: View {
    let flow: SymptomFlow
    let patient: Patient
    let chosen: Set<String>
    let exits: FlowExits

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var selected: String?
    @State private var showAll = false
    @State private var seed: KidFormSeed?

    /// The germ the entry has now, when the pages reopen one that exists.
    private var currentGermID: String? {
        switch flow {
        case .me, .someone: return nil
        case .kidIllness(let illnessID): return model.data.kidIllnesses.first(where: { $0.id == illnessID })?.germID
        case .log(let logID): return model.data.logs.first(where: { $0.id == logID })?.germID
        }
    }

    var body: some View {
        let lineup = SymptomEngine.lineup(for: chosen, in: model.catalog.germs)
        let few = !lineup.top.isEmpty && lineup.top.count <= 3
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title(lineup))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(subtitle(lineup))
                    .font(.callout)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                signs
                    .padding(.top, 14)
                VStack(spacing: 8) {
                    if few {
                        ForEach(Array(lineup.top.enumerated()), id: \.element.id) { item in
                            card(item.element, index: item.offset)
                        }
                        if !lineup.others.isEmpty {
                            moreRow(trCount(lineup.others.count, one: "%lld other fits less well",
                                            other: "%lld others fit less well"))
                            if showAll {
                                ForEach(lineup.others) { suspect in
                                    row(suspect, index: 0)
                                }
                            }
                        }
                    } else {
                        let shown = showAll ? lineup.top : Array(lineup.top.prefix(4))
                        ForEach(Array(shown.enumerated()), id: \.element.id) { item in
                            row(item.element, index: item.offset)
                        }
                        if lineup.top.count > 4, !showAll {
                            moreRow(trCount(lineup.top.count - 4, one: "%lld more suspect", other: "%lld more suspects"))
                        }
                    }
                }
                .padding(.top, 14)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 16)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            bottomBar(quiet: few)
        }
        .navigationDestination(item: $seed) { seed in
            KidIllnessForm(seed: seed, onDone: exits.close, onAdded: exits.onAdded)
        }
    }

    private func title(_ lineup: Lineup) -> String {
        let count = lineup.top.count
        if count == 0 { return tr("No suspect") }
        if !lineup.isFull { return tr("No perfect match") }
        if count == 1 { return tr("One suspect") }
        if count <= 3 { return tr("Down to %lld", count) }
        return tr("%lld suspects", count)
    }

    private func subtitle(_ lineup: Lineup) -> String {
        guard let best = lineup.top.first else {
            return tr("Nothing in the guide fits these signs yet.")
        }
        if !lineup.isFull {
            return tr("The closest ones fit %1$lld of your %2$lld signs.", best.matched, lineup.chosen)
        }
        if lineup.top.count > 3 {
            return tr("Lots of germs start like this. Too early to tell them apart.")
        }
        return lineup.top.count == 1 ? tr("It fits everything you ticked.") : tr("They fit everything you ticked.")
    }

    private var signs: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(Symptom.ordered(chosen)) { symptom in
                    Text(symptom.title)
                        .font(.footnote)
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(palette.surface, in: Capsule())
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func clueText(_ clue: SuspectClue) -> String {
        clue.isTelltale ? tr("Telltale sign: %@", clue.text) : tr("Watch for: %@", clue.text)
    }

    /// One of a few suspects: big, moving, with its own button.
    private func card(_ suspect: Suspect, index: Int) -> some View {
        let germ = suspect.germ
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                LivelyCharacter(mood: .stalking, phase: Double(index) * 0.9) {
                    GermImage(germ: germ, size: 84)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(germ.name)
                        .font(.title3.weight(.bold))
                    Text(germ.illness.value)
                        .font(.subheadline)
                        .opacity(0.75)
                    if let clue = SymptomEngine.clue(for: germ, chosen: chosen) {
                        Text(clueText(clue))
                            .font(.subheadline)
                            .opacity(0.85)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            Button(tr("That's it")) {
                pick(germ.id)
            }
            .buttonStyle(PillButtonStyle(kind: .ink, height: 46))
        }
        .padding(14)
        .background(germ.tileTint(palette), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .cascadeIn(index)
    }

    /// One of many suspects: a row to select.
    private func row(_ suspect: Suspect, index: Int) -> some View {
        let germ = suspect.germ
        let isOn = selected == germ.id
        return Button {
            Haptics.tap()
            selected = isOn ? nil : germ.id
        } label: {
            HStack(spacing: 12) {
                GermImage(germ: germ, size: 50)
                    .frame(width: 62, height: 62)
                    .background(germ.tileTint(palette), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text(germ.name)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Text(germ.illness.value)
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .lineLimit(1)
                    }
                    if let clue = SymptomEngine.clue(for: germ, chosen: chosen) {
                        Text(clueText(clue))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isOn ? palette.accent : palette.inkTertiary)
                    .symbolEffect(.bounce, value: isOn)
            }
            .padding(.vertical, 10)
            .padding(.leading, 10)
            .padding(.trailing, 14)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(isOn ? palette.accent : Color.clear, lineWidth: 2)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .cascadeIn(index)
    }

    private func moreRow(_ title: String) -> some View {
        Button {
            withAnimation(Tempo.quick) {
                showAll.toggle()
            }
        } label: {
            HStack {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(palette.inkSecondary)
                Spacer()
                Image(systemName: showAll ? "chevron.up" : "chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.inkTertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var keepTitle: String {
        guard let current = currentGermID, current != GermCatalog.mysteryID,
              let germ = model.catalog.germ(current) else {
            return flow.isNew ? tr("Keep it a mystery for now") : tr("Still a mystery")
        }
        return tr("Keep %@", germ.name)
    }

    private var footnote: String {
        let guess = tr("A guess for your logbook, not a diagnosis.")
        guard flow.isNew, model.data.settings.checkInsOn else { return guess }
        return tr("Germigo asks again in 2 days.") + " " + guess
    }

    private func bottomBar(quiet: Bool) -> some View {
        VStack(spacing: 10) {
            if let selected, let germ = model.catalog.germ(selected) {
                Button(tr("It's %@", germ.name)) {
                    pick(germ.id)
                }
                .buttonStyle(PillButtonStyle(kind: .ink, height: 56))
                Button(keepTitle) {
                    keep()
                }
                .buttonStyle(PillButtonStyle(kind: .ghost, height: 46))
            } else {
                Button(keepTitle) {
                    keep()
                }
                .buttonStyle(PillButtonStyle(kind: quiet ? .ghost : .ink, height: 56))
            }
            Text(footnote)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .animation(Tempo.quick, value: selected)
    }

    /// No germ picked: a new entry becomes a mystery, an existing one keeps its germ.
    private func keep() {
        pick(currentGermID ?? GermCatalog.mysteryID)
    }

    private func pick(_ germID: String) {
        let ids = Symptom.ordered(chosen).map { $0.id }
        let changed = currentGermID.map { $0 != germID } ?? false
        Haptics.success()
        switch flow {
        case .me, .someone:
            switch patient {
            case .kid(let kidID):
                seed = KidFormSeed(kidID: kidID, germID: germID, symptoms: ids)
            case .newKid:
                break
            case .me, .partner:
                exits.onLog(LogRequest(germID: germID, symptoms: ids, sufferer: patient.sufferer))
                exits.close()
            }
        case .kidIllness(let illnessID):
            model.reassignKidIllness(illnessID, germID: germID, symptoms: ids)
            announce(germID, changed: changed)
            exits.close()
        case .log(let logID):
            model.reassignLog(logID, germID: germID, symptoms: ids)
            announce(germID, changed: changed)
            exits.close()
        }
    }

    private func announce(_ germID: String, changed: Bool) {
        guard changed, let germ = model.catalog.germ(germID) else {
            model.toast = tr("Symptoms updated.")
            return
        }
        model.toast = tr("Now it's %@.", germ.name)
    }
}

import SwiftUI

/// The quick-pick germ grid with a door to the full list.
struct GermPicker: View {
    @Binding var selection: String?
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showAll = false

    private var tiles: [Germ] {
        var germs = model.catalog.quickPicks
        if let id = selection, let chosen = model.catalog.germ(id), !germs.contains(chosen) {
            germs.insert(chosen, at: 0)
        }
        return germs
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(tiles) { germ in
                Button {
                    Haptics.tap()
                    selection = germ.id
                } label: {
                    tile(germ: germ, selected: selection == germ.id)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(germ.illness.value)
                .accessibilityAddTraits(selection == germ.id ? .isSelected : [])
            }
            Button {
                showAll = true
            } label: {
                VStack(spacing: 6) {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.bold))
                        .frame(width: 40, height: 40)
                        .background(palette.ink.opacity(0.06), in: Circle())
                    Text(tr("%lld more", max(0, model.catalog.germs.count - model.catalog.quickPicks.count)))
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(palette.inkSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 88)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showAll) {
            AllGermsList(selection: $selection)
        }
    }

    private func tile(germ: Germ, selected: Bool) -> some View {
        VStack(spacing: 4) {
            GermImage(germ: germ, size: 44, silhouette: model.count(of: germ.id) == 0)
                .foregroundStyle(germ.deepTint)
            Text(germ.illness.value)
                .font(.caption.weight(selected ? .bold : .semibold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(selected ? germ.lightTint : palette.surface,
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(selected ? germ.deepTint : Color.clear, lineWidth: 2)
        }
        .scaleEffect(selected ? 1.04 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selected)
    }
}

private struct AllGermsList: View {
    @Binding var selection: String?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(model.catalog.germs.sorted { $0.illness.value < $1.illness.value }) { germ in
                Button {
                    selection = germ.id
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        GermImage(germ: germ, size: 36, silhouette: model.count(of: germ.id) == 0)
                            .foregroundStyle(germ.deepTint)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(germ.illness.value)
                                .font(.body)
                            Text(germ.scientific.value)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selection == germ.id {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle(tr("All germs"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Collects what the parent caught, from whom, and how bad it is.
struct LogSheet: View {
    let request: LogRequest
    let onLogged: (RewardResult) -> Void

    @Environment(AppModel.self) private var model
    @Environment(CrewStore.self) private var crew
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var germID: String?
    @State private var source = GermSource.unknown
    @State private var severity = 3
    @State private var startedAt = Date()
    @State private var sufferer = Sufferer.me
    @State private var tellCrew = true
    @State private var linkedIllnessID: UUID?
    @State private var didPrefill = false
    @State private var submitted = false

    private var severityNames: [String] {
        [tr("Sniffles"), tr("Meh"), tr("Couch day"), tr("Bathroom floor"), tr("Send soup")]
    }

    private var suggestion: KidIllness? {
        if let id = request.kidIllnessID {
            return model.data.kidIllnesses.first { $0.id == id }
        }
        return model.openExposures.first
    }

    private var draft: LogDraft? {
        guard let germID else { return nil }
        return LogDraft(germID: germID, source: source, severity: severity, startedAt: startedAt,
                        sufferer: sufferer, kidIllnessID: linkedIllnessID, symptoms: request.symptoms)
    }

    private var previewPoints: Int {
        guard let draft, let germ = model.catalog.germ(draft.germID) else { return 0 }
        return RewardEngine.bonuses(for: draft, germ: germ).reduce(0) { $0 + $1.points }
    }

    private var isNightShift: Bool {
        let hour = Calendar.current.component(.hour, from: startedAt)
        return hour >= 1 && hour < 5
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let illness = suggestion, let germ = model.catalog.germ(illness.germID) {
                        suggestionCard(illness: illness, germ: germ)
                    }
                    group(tr("What is it?")) {
                        GermPicker(selection: $germID)
                    }
                    group(tr("Who gave it to you?")) {
                        sourceRow
                    }
                    group(tr("How bad?"), trailing: severityNames[severity - 1]) {
                        severityRow
                    }
                    detailsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("Log a germ"))
            .navigationBarTitleDisplayMode(.inline)
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
            .safeAreaInset(edge: .bottom) {
                logButton
            }
            .onAppear(perform: prefill)
            .onChange(of: germID) { _, newValue in
                if let illness = suggestion, illness.germID != newValue {
                    linkedIllnessID = nil
                }
            }
        }
    }

    private func group<Content: View>(_ title: String, trailing: String? = nil,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.inkSecondary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.ink)
                }
            }
            .padding(.horizontal, 4)
            content()
        }
    }

    private func suggestionCard(illness: KidIllness, germ: Germ) -> some View {
        let kidName = model.kid(illness.kidID)?.name ?? tr("Your kid")
        let active = linkedIllnessID == illness.id
        return Button {
            Haptics.tap()
            germID = germ.id
            source = .kid(illness.kidID)
            linkedIllnessID = illness.id
        } label: {
            HStack(spacing: 12) {
                GermImage(germ: germ, size: 50, silhouette: model.count(of: germ.id) == 0)
                    .foregroundStyle(germ.deepTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Same as %@?", kidName))
                        .font(.headline)
                    Text(germ.illness.value)
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                }
                Spacer()
                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(active ? germ.deepTint : palette.inkTertiary)
            }
            .foregroundStyle(palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 70)
            .background(germ.lightTint.opacity(palette.isDark ? 0.18 : 1),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(active ? germ.deepTint : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var sourceRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 18) {
                ForEach(model.data.kids) { kid in
                    sourceButton(.kid(kid.id), name: kid.name) {
                        BuddyBadge(look: kid.colorIndex, size: 54)
                    }
                }
                if let partner = model.data.partnerName {
                    sourceButton(.partner, name: partner) {
                        BuddyBadge(look: model.data.partnerLook, size: 54)
                    }
                }
                sourceButton(.daycare, name: tr("Daycare")) {
                    symbolAvatar("building.2.fill", colors: [Color(hex: Swatch.butter), Color(hex: Swatch.amber)])
                }
                sourceButton(.unknown, name: tr("Not sure")) {
                    symbolAvatar("questionmark", colors: [palette.surfaceAlt, palette.surfaceAlt])
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
    }

    private func symbolAvatar(_ symbol: String, colors: [Color]) -> some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 54, height: 54)
            .overlay {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color(hex: Swatch.night))
            }
    }

    private func sourceButton<Avatar: View>(_ value: GermSource, name: String,
                                            @ViewBuilder avatar: () -> Avatar) -> some View {
        let selected = source == value
        return Button {
            Haptics.tap()
            source = value
        } label: {
            VStack(spacing: 6) {
                avatar()
                    .padding(4)
                    .overlay {
                        Circle().strokeBorder(selected ? palette.ink : Color.clear, lineWidth: 2.5)
                    }
                Text(name)
                    .font(.caption.weight(selected ? .bold : .semibold))
                    .foregroundStyle(selected ? palette.ink : palette.inkSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var severityRow: some View {
        HStack {
            ForEach(1...5, id: \.self) { level in
                Button {
                    Haptics.tap()
                    severity = level
                } label: {
                    SeverityFace(level: level, selected: severity == level)
                        .frame(width: severity == level ? 54 : 40, height: severity == level ? 54 : 40)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(severityNames[level - 1])
                .accessibilityAddTraits(severity == level ? .isSelected : [])
            }
        }
        .frame(height: 76)
        .padding(.horizontal, 10)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.snappy(duration: 0.2), value: severity)
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: "moon.fill")
                DatePicker(tr("Started"), selection: $startedAt, in: AppModel.earliestNewEntry...Date(),
                           displayedComponents: [.date, .hourAndMinute])
                    .font(.body)
            }
            .frame(minHeight: 54)
            if isNightShift {
                HStack {
                    Spacer()
                    PillLabel(text: tr("Night shift +%lld", RewardEngine.nightShiftPoints),
                              foreground: Color(hex: Swatch.grape), background: Color(hex: Swatch.lilacMist))
                }
                .padding(.bottom, 10)
            }
            if let partner = model.data.partnerName {
                Divider()
                HStack(spacing: 12) {
                    IconTile(symbol: "person.2.fill")
                    Picker(tr("Who's sick?"), selection: $sufferer) {
                        Text(tr("Me")).tag(Sufferer.me)
                        Text(verbatim: partner).tag(Sufferer.partner)
                        Text(tr("Both")).tag(Sufferer.both)
                    }
                    .pickerStyle(.segmented)
                }
                .frame(minHeight: 54)
            }
            if model.hasPass, crew.isMember, let crewName = crew.state?.crew.name {
                Divider()
                Toggle(isOn: $tellCrew) {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Tell %@", crewName))
                            Text(crew.sharesName ? tr("Adds 1 to the radar and posts to the feed.")
                                                 : tr("Adds 1 to the radar. No name shared."))
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                        }
                    } icon: {
                        IconTile(symbol: "dot.radiowaves.left.and.right")
                    }
                }
                .frame(minHeight: 60)
            }
        }
        .tint(.green)
        .foregroundStyle(palette.ink)
        .padding(.horizontal, 16)
        .petriCard(padding: 0)
    }

    private var logButton: some View {
        Button {
            submit()
        } label: {
            HStack(spacing: 10) {
                Text(tr("Log it"))
                if previewPoints > 0 {
                    Text(tr("+%lld pts", previewPoints))
                        .font(.footnote.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.22), in: Capsule())
                }
            }
        }
        .buttonStyle(PillButtonStyle(kind: .ink, height: 58))
        .disabled(germID == nil)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        if let picked = request.germID {
            germID = picked
            if let illness = suggestion, illness.germID == picked {
                source = .kid(illness.kidID)
                linkedIllnessID = illness.id
            } else if let kid = model.data.kids.first {
                source = .kid(kid.id)
            }
        } else if let illness = suggestion {
            germID = illness.germID
            source = .kid(illness.kidID)
            linkedIllnessID = illness.id
        } else if let kid = model.data.kids.first {
            source = .kid(kid.id)
        }
    }

    private func submit() {
        guard !submitted, let draft, let result = model.logGerm(draft) else { return }
        submitted = true
        Haptics.thud()
        let share = tellCrew && crew.isMember && model.hasPass
        Task {
            if model.data.settings.checkInsOn { await model.enableReminders() }
            if share { await crew.reportGerm(draft.germID) }
        }
        onLogged(result)
        dismiss()
    }
}

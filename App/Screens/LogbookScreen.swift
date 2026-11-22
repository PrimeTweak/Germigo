import SwiftUI

/// Every logged germ, editable, and what each kid brought home.
struct LogbookScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var editing: SickLog?
    @State private var pendingDelete: SickLog?
    @State private var showsKids = false

    private var logs: [SickLog] {
        model.data.logs.sorted { $0.startedAt > $1.startedAt }
    }

    private var mine: some View {
        let shown = logs.filter { model.isShown($0.startedAt, ongoing: $0.isActive) }
        return ScrollView {
            LazyVStack(spacing: 8) {
                if logs.isEmpty {
                    Text(tr("No germs logged yet. It won't last."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .germigoCard()
                }
                ForEach(Array(shown.enumerated()), id: \.element.id) { item in
                    card(item.element)
                        .cascadeIn(min(item.offset, 8))
                }
                if shown.count < logs.count {
                    LockedHistoryRow(count: logs.count - shown.count)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
    }

    private func card(_ log: SickLog) -> some View {
        HStack(spacing: 4) {
            Button {
                editing = log
            } label: {
                row(log)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Menu {
                Button(role: .destructive) {
                    pendingDelete = log
                } label: {
                    Label(tr("Delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.bold))
                    .foregroundStyle(palette.inkSecondary)
                    .frame(width: 40, height: 40)
                    .hitTarget(width: 40, height: 40)
            }
            .accessibilityLabel(tr("More"))
        }
        .germigoCard(radius: 24, padding: 12)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(tr("Section"), selection: $showsKids) {
                Text(tr("Mine")).tag(false)
                Text(tr("Kids")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            if showsKids {
                ScrollView {
                    KidsGermsView()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
            } else {
                mine
            }
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Logbook"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { log in
            LogEditSheet(log: log)
        }
        .confirmationDialog(tr("Delete this log?"), isPresented: deleteBinding, titleVisibility: .visible) {
            Button(tr("Delete"), role: .destructive) {
                if let log = pendingDelete { model.deleteLog(log.id) }
                pendingDelete = nil
            }
            Button(tr("Cancel"), role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(tr("Its points leave your total and your streak is counted again without it."))
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { shown in
            if !shown { pendingDelete = nil }
        })
    }

    private func row(_ log: SickLog) -> some View {
        let germ = model.catalog.germ(log.germID)
        return HStack(spacing: 12) {
            if let germ {
                GermImage(germ: germ, size: 34)
                    .frame(width: 44, height: 44)
                    .background(germ.tileTint(palette), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(germ?.illness.value ?? log.germID)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(log.startedAt.formatted(date: .abbreviated, time: .omitted) + " · "
                     + trCount(log.dayCount(), one: "%lld day", other: "%lld days") + " · "
                     + model.sourceName(log.source))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
            Spacer(minLength: 4)
            if log.isActive {
                PillLabel(text: tr("Now"), foreground: palette.onAccent, background: palette.accent)
            } else {
                Text(tr("+%lld pts", log.points))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(palette.inkSecondary)
            }
        }
    }
}

/// Fixes the dates or the severity of a logged germ.
private struct LogEditSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SickLog
    @State private var recovered: Bool
    @State private var endDate: Date

    init(log: SickLog) {
        _draft = State(initialValue: log)
        _recovered = State(initialValue: log.endedAt != nil)
        _endDate = State(initialValue: log.endedAt ?? Date())
    }

    /// Only the germ that started last can still be going on.
    private var canStayOpen: Bool {
        JournalRules.latestID(in: model.data.logs) == draft.id
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker(tr("Started"), selection: $draft.startedAt, in: ...Date())
                    if canStayOpen {
                        Toggle(tr("Recovered"), isOn: $recovered)
                    }
                    if recovered || !canStayOpen {
                        DatePicker(tr("Ended"), selection: $endDate, in: draft.startedAt...Date())
                    }
                } footer: {
                    if !canStayOpen {
                        Text(tr("A newer germ is in your journal, so this one has an end date."))
                    }
                }
                Section {
                    Stepper(value: $draft.severity, in: 1...5) {
                        HStack {
                            Text(tr("How bad?"))
                            Spacer()
                            Text(String(draft.severity) + " / 5")
                                .foregroundStyle(palette.inkSecondary)
                        }
                    }
                    if model.hasPass, let partner = model.data.partnerName {
                        Picker(tr("Who was sick?"), selection: $draft.sufferer) {
                            Text(tr("Me")).tag(Sufferer.me)
                            Text(verbatim: partner).tag(Sufferer.partner)
                            Text(tr("Both")).tag(Sufferer.both)
                        }
                    }
                } footer: {
                    Text(tr("Points stay as they were when the germ was logged."))
                }
            }
            .tint(palette.accent)
            .navigationTitle(tr("Edit log"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Cancel"))
                    .tint(palette.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        var updated = draft
                        updated.endedAt = recovered || !canStayOpen ? max(endDate, draft.startedAt) : nil
                        model.updateLog(updated)
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(tr("Save"))
                    .tint(palette.ink)
                }
            }
        }
    }
}

/// What each kid has had, which also drives the incubation countdowns.
private struct KidsGermsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showSheet = false
    @State private var pendingDelete: KidIllness?

    private var illnesses: [KidIllness] {
        model.data.kidIllnesses.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showSheet = true
            } label: {
                Label(tr("Add a kid's germ"), systemImage: "plus")
            }
            .buttonStyle(PillButtonStyle(kind: .ink, height: 46))
            if illnesses.isEmpty {
                Text(tr("When a kid gets sick, add it here. Germigo starts your incubation countdown and remembers who brought what home."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
            }
            let shown = illnesses.filter { model.isShown($0.startedAt, ongoing: DayEngine.isGoingOn($0, catalog: model.catalog, now: Date())) }
            ForEach(Array(shown.enumerated()), id: \.element.id) { item in
                row(item.element)
                    .cascadeIn(min(item.offset, 8))
            }
            if shown.count < illnesses.count {
                LockedHistoryRow(count: illnesses.count - shown.count)
            }
        }
        .sheet(isPresented: $showSheet) {
            KidIllnessSheet()
        }
        .confirmationDialog(tr("Delete this entry?"), isPresented: deleteBinding, titleVisibility: .visible) {
            Button(tr("Delete"), role: .destructive) {
                if let illness = pendingDelete { model.deleteKidIllness(illness.id) }
                pendingDelete = nil
            }
            Button(tr("Cancel"), role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(tr("Its countdown and reminders go with it."))
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { shown in
            if !shown { pendingDelete = nil }
        })
    }

    @ViewBuilder
    private func row(_ illness: KidIllness) -> some View {
        if let germ = model.catalog.germ(illness.germID) {
            let kid = model.kid(illness.kidID)
            HStack(spacing: 12) {
                NavigationLink {
                    GermDetailScreen(germ: germ)
                } label: {
                    HStack(spacing: 12) {
                        BuddyBadge(look: kid?.colorIndex ?? 0, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text((kid?.name ?? tr("Your kid")) + " · " + germ.illness.value)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(palette.ink)
                                .multilineTextAlignment(.leading)
                            Text(illness.startedAt.formatted(date: .abbreviated, time: .omitted) + " · " + outcomeLabel(illness.outcome))
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                        }
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Menu {
                    Button(role: .destructive) {
                        pendingDelete = illness
                    } label: {
                        Label(tr("Delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.bold))
                        .foregroundStyle(palette.inkSecondary)
                        .frame(width: 40, height: 40)
                        .hitTarget(width: 40, height: 40)
                }
                .accessibilityLabel(tr("More"))
            }
            .germigoCard(radius: 24, padding: 12)
        }
    }

    private func outcomeLabel(_ outcome: ExposureOutcome) -> String {
        switch outcome {
        case .open: return tr("You're still clear")
        case .caught: return tr("You caught it")
        case .dodged: return tr("You dodged it")
        case .expired: return tr("Window passed")
        }
    }
}

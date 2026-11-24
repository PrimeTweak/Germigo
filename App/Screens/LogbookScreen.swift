import SwiftUI

/// One illness in the household's history: a germ a parent logged, or one a kid brought home.
enum LogbookEntry: Identifiable {
    case log(SickLog)
    case illness(KidIllness)

    var id: UUID {
        switch self {
        case .log(let log): log.id
        case .illness(let illness): illness.id
        }
    }

    var startedAt: Date {
        switch self {
        case .log(let log): log.startedAt
        case .illness(let illness): illness.startedAt
        }
    }

    var germID: String {
        switch self {
        case .log(let log): log.germID
        case .illness(let illness): illness.germID
        }
    }

    /// What deleting it asks, then what goes with it.
    var deleteTitle: String {
        switch self {
        case .log: tr("Delete this log?")
        case .illness: tr("Delete this entry?")
        }
    }

    var deleteMessage: String {
        switch self {
        case .log: tr("Its points leave your total and your streak is counted again without it.")
        case .illness: tr("Its countdown and reminders go with it.")
        }
    }
}

extension AppModel {
    /// The household's illnesses, newest first: everyone's, or one person's.
    func logbook(for person: Person?) -> [LogbookEntry] {
        let logs = data.logs.filter { log in
            switch person {
            case nil: true
            case .me: log.sufferer.includesMe
            case .partner: log.sufferer.includesPartner
            case .kid: false
            }
        }
        let illnesses = data.kidIllnesses.filter { illness in
            switch person {
            case nil: true
            case .kid(let id): illness.kidID == id
            case .me, .partner: false
            }
        }
        return (logs.map(LogbookEntry.log) + illnesses.map(LogbookEntry.illness)).sorted { $0.startedAt > $1.startedAt }
    }

    func isGoingOn(_ entry: LogbookEntry) -> Bool {
        switch entry {
        case .log(let log): log.isActive
        case .illness(let illness): DayEngine.isGoingOn(illness, catalog: catalog, now: Date())
        }
    }

    /// Who was sick: the kid, or the parents named in the log.
    func whoHad(_ entry: LogbookEntry) -> (look: Int, name: String, person: Person) {
        switch entry {
        case .log(let log):
            let person: Person = log.sufferer == .partner ? .partner : .me
            return (look(of: person), name(of: log.sufferer), person)
        case .illness(let illness):
            let person = Person.kid(illness.kidID)
            return (look(of: person), name(for: person), person)
        }
    }

    func outcomeLabel(_ outcome: ExposureOutcome) -> String {
        switch outcome {
        case .open: tr("You're still clear")
        case .caught: tr("You caught it")
        case .dodged: tr("You dodged it")
        case .expired: tr("Window passed")
        }
    }
}

/// The household's one history, grouped by month, with a chip per person to narrow it.
struct LogbookScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var filter: Person?
    @State private var opened: EntryRef?
    @State private var pendingDelete: LogbookEntry?
    @State private var addsKidGerm = false

    /// The person to show first; nil shows the whole household.
    init(person: Person? = nil) {
        _filter = State(initialValue: person)
    }

    private struct EntryRef: Identifiable {
        let id: UUID
    }

    private struct Month: Identifiable {
        let start: Date
        var entries: [LogbookEntry]
        var id: Date { start }
    }

    var body: some View {
        let all = model.logbook(for: filter)
        let shown = all.filter { model.isShown($0.startedAt, ongoing: model.isGoingOn($0)) }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                if model.people.count > 1 {
                    chips
                }
                if !shown.isEmpty {
                    Text(trCount(all.count, one: "%lld germ", other: "%lld germs"))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                }
                if all.isEmpty {
                    empty
                }
                ForEach(Array(months(shown).enumerated()), id: \.element.id) { item in
                    Text(monthTitle(item.element.start))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 4)
                        .padding(.top, 14)
                    VStack(spacing: 0) {
                        ForEach(Array(item.element.entries.enumerated()), id: \.element.id) { row in
                            if row.offset > 0 {
                                Divider()
                                    .padding(.leading, 66)
                            }
                            entryRow(row.element)
                        }
                    }
                    .padding(.horizontal, 12)
                    .germilyCard(padding: 0)
                    .cascadeIn(min(item.offset, 8))
                }
                if shown.count < all.count {
                    LockedHistoryRow(title: model.lockedHistoryTitle(for: filter, hidden: all.count - shown.count))
                }
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 28)
            .animation(Tempo.quick, value: filter)
        }
        .background(CharacterWash(tint: Color(hex: Swatch.lilac)))
        .navigationTitle(tr("Logbook"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !model.data.kids.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addsKidGerm = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(tr("Add a kid's germ"))
                }
            }
        }
        .sheet(item: $opened) { ref in
            LogbookEntrySheet(id: ref.id)
        }
        .sheet(isPresented: $addsKidGerm, onDismiss: { model.offerTrialIfDue() }) {
            KidIllnessSheet()
        }
        .confirmationDialog(pendingDelete?.deleteTitle ?? "", isPresented: deleteBinding, titleVisibility: .visible) {
            Button(tr("Delete"), role: .destructive) {
                if let entry = pendingDelete { model.deleteEntry(entry) }
                pendingDelete = nil
            }
            Button(tr("Cancel"), role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(pendingDelete?.deleteMessage ?? "")
        }
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ChoiceChip(title: tr("Everyone"), selected: filter == nil) {
                    filter = nil
                }
                ForEach(model.people, id: \.self) { person in
                    PersonChip(look: model.look(of: person), sick: model.isSick(person), name: model.name(for: person),
                               selected: filter == person) {
                        filter = person
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .accessibilityLabel(tr("Who"))
        .padding(.bottom, 4)
    }

    /// The same empty page for everyone and for each person, whose character peeks out of the book.
    /// The way to add a past germ shows where a kid's germ can go.
    private var empty: some View {
        let addsKid: Bool = {
            switch filter {
            case nil: !model.data.kids.isEmpty
            case .kid: true
            case .me, .partner: false
            }
        }()
        return VStack(spacing: 6) {
            Image("record-logbook")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .shadow(color: Color(hex: Swatch.iris).opacity(0.18), radius: 10, y: 8)
                .overlay(alignment: .bottomTrailing) {
                    if let filter {
                        BuddyView(look: model.look(of: filter), sick: model.isSick(filter), size: 62, leads: true)
                            .offset(x: 34, y: 4)
                    }
                }
                .padding(.bottom, 6)
                .accessibilityHidden(true)
            Text(tr("Nothing in here yet"))
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.ink)
            Text(tr("No germs logged yet. It won't last."))
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
            Text(tr("Every germ you log on Today, yours or a kid's, lands here."))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .padding(.top, 8)
            if addsKid {
                Button {
                    addsKidGerm = true
                } label: {
                    Label(tr("Add a kid's germ"), systemImage: "plus")
                        .padding(.horizontal, 24)
                }
                .buttonStyle(PillButtonStyle(kind: .ink, height: 50))
                .fixedSize()
                .padding(.top, 14)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
    }

    private func entryRow(_ entry: LogbookEntry) -> some View {
        let germ = model.catalog.germ(entry.germID)
        let who = model.whoHad(entry)
        return HStack(spacing: 4) {
            Button {
                opened = EntryRef(id: entry.id)
            } label: {
                HStack(spacing: 16) {
                    GermTile(germ: germ, look: who.look, side: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(germ?.illness.value ?? entry.germID)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(palette.ink)
                            Text(who.name)
                                .font(.subheadline)
                                .foregroundStyle(palette.inkSecondary)
                                .lineLimit(1)
                        }
                        Text(detail(entry))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    Spacer(minLength: 4)
                    trailing(entry)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Menu {
                Button(role: .destructive) {
                    pendingDelete = entry
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
    }

    private func detail(_ entry: LogbookEntry) -> String {
        let date = entry.startedAt.formatted(date: .abbreviated, time: .omitted)
        switch entry {
        case .log(let log):
            return date + " · " + trCount(log.dayCount(), one: "%lld day", other: "%lld days") + " · " + model.sourceName(log.source)
        case .illness(let illness):
            return date + " · " + model.outcomeLabel(illness.outcome)
        }
    }

    @ViewBuilder
    private func trailing(_ entry: LogbookEntry) -> some View {
        if model.isGoingOn(entry) {
            PillLabel(text: tr("Now"), foreground: palette.onAccent, background: palette.accent)
        } else if case .log(let log) = entry {
            VStack(alignment: .trailing, spacing: 5) {
                Text(tr("+%lld pts", log.points))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(palette.inkSecondary)
                SeverityGauge(level: log.severity, germ: model.catalog.germ(log.germID))
            }
        }
    }

    private func months(_ entries: [LogbookEntry]) -> [Month] {
        let calendar = Calendar.current
        var months: [Month] = []
        for entry in entries {
            let start = calendar.dateInterval(of: .month, for: entry.startedAt)?.start ?? entry.startedAt
            if let last = months.last, last.start == start {
                months[months.count - 1].entries.append(entry)
            } else {
                months.append(Month(start: start, entries: [entry]))
            }
        }
        return months
    }

    private func monthTitle(_ start: Date) -> String {
        let sameYear = Calendar.current.isDate(start, equalTo: Date(), toGranularity: .year)
        let title = sameYear ? start.formatted(.dateTime.month(.wide)) : start.formatted(.dateTime.month(.wide).year())
        return title.capitalized(with: Locale.current)
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { shown in
            if !shown { pendingDelete = nil }
        })
    }
}

extension AppModel {
    func deleteEntry(_ entry: LogbookEntry) {
        switch entry {
        case .log(let log): deleteLog(log.id)
        case .illness(let illness): deleteKidIllness(illness.id)
        }
    }
}

/// A germ on its tinted tile, with the character of whoever had it on the corner.
struct GermTile: View {
    let germ: Germ?
    let look: Int
    var side: CGFloat = 50
    var sick = false
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            if let germ {
                GermImage(germ: germ, size: side * 0.76)
            }
        }
        .frame(width: side, height: side)
        .background(germ?.tileTint(palette) ?? palette.surfaceAlt,
                    in: RoundedRectangle(cornerRadius: side * 0.3, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            BuddyView(look: look, sick: sick, size: side * 0.44)
                .frame(width: side * 0.58, height: side * 0.58)
                .background(palette.background, in: Circle())
                .shadow(color: .black.opacity(0.14), radius: 1.5, y: 1)
                .offset(x: side * 0.16, y: side * 0.14)
        }
        .accessibilityHidden(true)
    }
}

/// One illness opened from the logbook: who and when, its days with their photos, its signs,
/// the germ's page, and ways to fix or delete it.
private struct LogbookEntrySheet: View {
    let id: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var editing: SickLog?
    @State private var confirmDelete = false

    private var entry: LogbookEntry? {
        if let log = model.data.logs.first(where: { $0.id == id }) { return .log(log) }
        return model.data.kidIllnesses.first { $0.id == id }.map(LogbookEntry.illness)
    }

    var body: some View {
        let current = entry
        let germ = current.flatMap { model.catalog.germ($0.germID) }
        NavigationStack {
            ScrollView {
                if let current {
                    content(current, germ: germ)
                        .padding(.horizontal, Spacing.page)
                        .padding(.bottom, 28)
                }
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(germ?.illness.value ?? "")
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
                if case .log(let log) = current {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            editing = log
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .accessibilityLabel(tr("Edit log"))
                    }
                }
            }
            .sheet(item: $editing) { log in
                LogEditSheet(log: log)
            }
            .confirmationDialog(current?.deleteTitle ?? "", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(tr("Delete"), role: .destructive) {
                    if let current { model.deleteEntry(current) }
                    dismiss()
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(current?.deleteMessage ?? "")
            }
            .onChange(of: current == nil) { _, gone in
                if gone { dismiss() }
            }
        }
    }

    private func content(_ entry: LogbookEntry, germ: Germ?) -> some View {
        let who = model.whoHad(entry)
        return VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 4) {
                GermTile(germ: germ, look: who.look, side: 112, sick: model.isGoingOn(entry))
                    .padding(.bottom, 12)
                Text(who.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(summary(entry))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            IllnessDays(entry: entry, person: who.person)
            VStack(spacing: 0) {
                if let germ {
                    NavigationLink {
                        GermDetailScreen(germ: germ)
                    } label: {
                        SettingsRow(symbol: "book.closed.fill", title: tr("About this germ")) {
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(palette.inkTertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .padding(.leading, 44)
                }
                Button {
                    confirmDelete = true
                } label: {
                    SettingsRow(symbol: "trash", title: tr("Delete"), tint: .red) {}
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .germilyCard(padding: 0)
            Text(tr("Dates and germs as you logged them. Germily adds no diagnosis."))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .padding(.horizontal, 4)
        }
    }

    private func summary(_ entry: LogbookEntry) -> String {
        let day = { (date: Date) in date.formatted(.dateTime.month(.abbreviated).day()) }
        switch entry {
        case .log(let log):
            let dates = log.endedAt.map { tr("%1$@ to %2$@", day(log.startedAt), day($0)) } ?? tr("Since %@", day(log.startedAt))
            return dates + " · " + trCount(log.dayCount(), one: "%lld day", other: "%lld days")
        case .illness(let illness):
            let dates = illness.endedAt.map { tr("%1$@ to %2$@", day(illness.startedAt), day($0)) }
                ?? tr("Started %@", day(illness.startedAt))
            return dates + " · " + model.outcomeLabel(illness.outcome)
        }
    }
}

/// The signs ticked for an illness, then a row per day with its photos and a way to add one.
private struct IllnessDays: View {
    let entry: LogbookEntry
    /// Whose photos new ones are filed under.
    let person: Person
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var seed: PhotoSeed?

    private var range: (start: Date, end: Date, link: PhotoLink, symptoms: [String]) {
        switch entry {
        case .log(let log):
            return (log.startedAt, log.endedAt ?? Date(), .log(log.id), log.symptoms)
        case .illness(let illness):
            let now = Date()
            let going = model.isGoingOn(entry)
            let end = illness.endedAt ?? (going ? now : DayEngine.kidEnd(illness, catalog: model.catalog, now: now))
            return (illness.startedAt, end, .illness(illness.id), illness.symptoms)
        }
    }

    private var photos: [PatientPhoto] {
        model.data.photos.filter { photo in
            switch entry {
            case .log(let log): photo.logID == log.id
            case .illness(let illness): photo.illnessID == illness.id
            }
        }
        .sorted { $0.takenAt < $1.takenAt }
    }

    /// Each day of the illness up to today, at midnight.
    private var days: [Date] {
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: range.start)
        let last = calendar.startOfDay(for: min(range.end, Date()))
        let count = max(0, calendar.dateComponents([.day], from: first, to: last).day ?? 0)
        return (0...count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    var body: some View {
        let calendar = Calendar.current
        let days = days
        let photos = photos
        let signs = Symptom.ordered(Set(range.symptoms))
        let loose = photos.filter { photo in !days.contains { calendar.isDate(photo.takenAt, inSameDayAs: $0) } }
        VStack(alignment: .leading, spacing: 8) {
            if !signs.isEmpty {
                Text(tr("Signs"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .padding(.horizontal, 4)
                ChipRows {
                    ForEach(signs) { sign in
                        Text(sign.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(palette.ink.opacity(0.07), in: Capsule())
                    }
                }
                .padding(.bottom, 6)
            }
            Text(tr("Days"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element) { item in
                    dayRow(item.element, number: item.offset + 1,
                           shots: photos.filter { calendar.isDate($0.takenAt, inSameDayAs: item.element) })
                }
                if !loose.isEmpty {
                    HStack(spacing: 10) {
                        Text(tr("Other days"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .frame(width: 92, alignment: .leading)
                        PhotoRow(photos: loose, side: 50)
                    }
                    .padding(.vertical, 4)
                }
            }
            .germilyCard(padding: 12)
        }
        .sheet(item: $seed) { seed in
            AddPhotoSheet(seed: seed)
        }
    }

    private func dayRow(_ day: Date, number: Int, shots: [PatientPhoto]) -> some View {
        let today = Calendar.current.isDateInToday(day)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(tr("Day %lld", number))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(today ? tr("Today") : day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(today ? .caption.weight(.semibold) : .caption)
                    .foregroundStyle(today ? palette.accent : palette.inkSecondary)
            }
            .frame(width: 92, alignment: .leading)
            PhotoRow(photos: shots, side: 50) {
                addPhoto(on: day, today: today)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    /// A new photo for that day of the illness: now for today, midday for a past day.
    private func addPhoto(on day: Date, today: Bool) {
        let moment = today ? Date() : Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        seed = PhotoSeed(person: person, takenAt: moment, link: range.link)
    }
}

/// Fixes the dates, the severity or who had a logged germ.
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
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("How bad?"))
                        SeverityPicker(level: $draft.severity, looks: model.looks(of: draft.sufferer),
                                       germ: model.catalog.germ(draft.germID))
                    }
                    .padding(.vertical, 6)
                    if let partner = model.data.partnerName {
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

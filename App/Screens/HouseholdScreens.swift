import SwiftUI
import UIKit

/// After a kid's germ is added: habits that keep it from going around the house, and the daycare rules.
struct ProtectHomeView: View {
    let illness: KidIllness
    let onDone: () -> Void

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var done: Set<String> = []

    private var germ: Germ? { model.catalog.germ(illness.germID) }

    private var steps: [HouseholdStep] {
        guard let germ, let guide = model.household else { return [] }
        return guide.steps(for: germ.family)
    }

    /// Each source once, in the order the steps cite them.
    private var sources: [GermReference] {
        var seen = Set<String>()
        return steps.flatMap { $0.sources }.filter { seen.insert($0.url).inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let germ {
                    HStack(spacing: 12) {
                        GermImage(germ: germ, size: 46)
                            .padding(4)
                            .background(germ.lightTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(germ.illness.value)
                                .font(.headline)
                                .foregroundStyle(palette.ink)
                            Text(tr("Since %@", illness.startedAt.formatted(.dateTime.weekday(.wide).hour().minute())))
                                .font(.subheadline)
                                .foregroundStyle(palette.inkSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .germigoCard()
                }
                if !steps.isEmpty {
                    SectionHeader(title: tr("Protect the rest of the house"))
                    VStack(spacing: 0) {
                        ForEach(steps) { step in
                            Button {
                                Haptics.tap()
                                if done.contains(step.id) {
                                    done.remove(step.id)
                                } else {
                                    done.insert(step.id)
                                }
                            } label: {
                                row(step)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .germigoCard()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Sources"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.inkSecondary)
                        ForEach(sources, id: \.url) { source in
                            if let url = URL(string: source.url) {
                                Link(source.name, destination: url)
                                    .font(.footnote)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                if let daycare = model.household?.daycare, let url = URL(string: daycare.url) {
                    SectionHeader(title: tr("Back to daycare?"))
                    Link(destination: url) {
                        HStack(spacing: 12) {
                            IconTile(symbol: "building.columns.fill", size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("Québec's official criteria"))
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(palette.ink)
                                Text(tr("When a child stays home from daycare, and when they can go back. A health ministry guide, in French."))
                                    .font(.footnote)
                                    .foregroundStyle(palette.inkSecondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(palette.inkSecondary)
                        }
                    }
                    .germigoCard()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("%@ is sick", model.kid(illness.kidID)?.name ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onDone()
                } label: {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel(tr("Done"))
            }
        }
    }

    private func row(_ step: HouseholdStep) -> some View {
        let checked = done.contains(step.id)
        return HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: step.icon, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title.value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(step.detail.value)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(checked ? palette.accent : palette.inkTertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(checked ? .isSelected : [])
    }
}

/// The last six months for one person, picked at the top, to show or send before an appointment.
struct DoctorSummaryScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var person: Person?

    private var people: [Person] {
        model.data.kids.map { Person.kid($0.id) } + [.me] + (model.data.partnerName == nil ? [] : [.partner])
    }

    private var current: Person {
        person.flatMap { people.contains($0) ? $0 : nil } ?? people.first ?? .me
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if people.count > 1 {
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(people, id: \.self) { member in
                                PersonChip(look: model.look(of: member), sick: model.isSick(member),
                                           name: model.name(for: member), selected: member == current) {
                                    person = member
                                }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityLabel(tr("Who"))
                }
                HealthHistory(person: current, since: Calendar.current.date(byAdding: .month, value: -6, to: Date()),
                              asPaper: true)
                    .id(current)
                    .transition(.opacity)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .animation(Tempo.quick, value: current)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("For the doctor"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One person's illnesses, with dates, signs and photos, and the ways to show or send them to a doctor.
struct HealthHistory: View {
    private struct Line: Identifiable {
        let id: UUID
        let title: String
        let dates: String
        let length: String?
        let signs: String?
        let photos: [PatientPhoto]
        let start: Date
        let ongoing: Bool
        /// Each day of the illness up to today, at midnight.
        let days: [Date]
        let link: PhotoLink
    }

    let person: Person
    /// The oldest illness shown; nil shows everything.
    let since: Date?
    /// The page the doctor receives, with the ways to send it. Otherwise each illness lists its days,
    /// with a way to add their photos, and the newest illness starts open.
    var asPaper = false
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showPaywall = false
    /// Illnesses opened or closed against their default.
    @State private var toggled: Set<UUID> = []
    @State private var seed: PhotoSeed?
    @State private var focus: PhotoFocus?

    private func kept(_ date: Date) -> Bool {
        since.map { date >= $0 } ?? true
    }

    private func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func illnessName(_ germID: String) -> String {
        model.catalog.germ(germID)?.illness.value ?? germID
    }

    private func sickDays(from start: Date, to end: Date) -> [Date] {
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: min(end, Date()))
        let count = max(0, calendar.dateComponents([.day], from: first, to: last).day ?? 0)
        return (0...count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }

    private func signs(_ ids: [String]) -> String? {
        let titles = Symptom.ordered(Set(ids)).map { $0.title }
        return titles.isEmpty ? nil : titles.joined(separator: ", ")
    }

    private var lines: [Line] {
        let photos = model.data.photos.filter { $0.person == person }
        switch person {
        case .me, .partner:
            let partner = person == .partner
            return model.data.logs
                .filter { (partner ? $0.sufferer.includesPartner : $0.sufferer.includesMe) && kept($0.startedAt) }
                .sorted { $0.startedAt > $1.startedAt }
                .map { log in
                    let dates = log.endedAt.map { tr("%1$@ to %2$@", day(log.startedAt), day($0)) }
                        ?? tr("Since %@", day(log.startedAt))
                    return Line(id: log.id, title: illnessName(log.germID), dates: dates,
                                length: trCount(log.dayCount(), one: "%lld day", other: "%lld days"),
                                signs: signs(log.symptoms), photos: photos.filter { $0.logID == log.id },
                                start: log.startedAt, ongoing: log.endedAt == nil,
                                days: sickDays(from: log.startedAt, to: log.endedAt ?? Date()), link: .log(log.id))
                }
        case .kid(let id):
            let now = Date()
            return model.data.kidIllnesses.filter { $0.kidID == id && kept($0.startedAt) }
                .sorted { $0.startedAt > $1.startedAt }
                .map { illness in
                    var dates = tr("Started %@", day(illness.startedAt))
                    var length: String?
                    let going = illness.endedAt == nil && DayEngine.isGoingOn(illness, catalog: model.catalog, now: now)
                    if let end = illness.endedAt {
                        dates = tr("%1$@ to %2$@", day(illness.startedAt), day(end))
                        let days = StreakMath.days(from: illness.startedAt, to: end) + 1
                        length = trCount(days, one: "%lld day", other: "%lld days")
                    } else if going {
                        dates = tr("Since %@", day(illness.startedAt))
                    }
                    let end = illness.endedAt ?? (going ? now : DayEngine.kidEnd(illness, catalog: model.catalog, now: now))
                    return Line(id: illness.id, title: illnessName(illness.germID), dates: dates, length: length,
                                signs: signs(illness.symptoms), photos: photos.filter { $0.illnessID == illness.id },
                                start: illness.startedAt, ongoing: going,
                                days: sickDays(from: illness.startedAt, to: end), link: .illness(illness.id))
                }
        }
    }

    /// Photos of the period that belong to none of the illnesses listed.
    private func otherPhotos(_ lines: [Line]) -> [PatientPhoto] {
        let listed = Set(lines.flatMap { $0.photos.map { $0.id } })
        return model.data.photos
            .filter { $0.person == person && kept($0.takenAt) && model.isShown($0.takenAt) && !listed.contains($0.id) }
            .sorted { $0.takenAt < $1.takenAt }
    }

    /// What the parents caught from this kid, through the logs linked to its illnesses.
    private var caughtAtHome: [String] {
        guard case .kid(let id) = person else { return [] }
        let ids = Set(model.data.kidIllnesses.filter { $0.kidID == id && kept($0.startedAt) && model.isShown($0.startedAt) }
            .map { $0.id })
        return model.data.logs.filter { log in log.kidIllnessID.map { ids.contains($0) } ?? false }
            .sorted { $0.startedAt < $1.startedAt }
            .map { tr("%1$@: %2$@, %3$@", model.name(of: $0.sufferer), illnessName($0.germID), day($0.startedAt)) }
    }

    private var heading: String {
        since == nil ? tr("%@ · history", model.name(for: person)) : tr("%@ · last 6 months", model.name(for: person))
    }

    private var emptyLine: String {
        since == nil ? tr("Nothing logged yet.") : tr("Nothing logged in the last 6 months.")
    }

    private func counts(_ lines: [Line], photos: Int) -> String {
        trCount(lines.count, one: "%lld illness", other: "%lld illnesses") + ", "
            + trCount(photos, one: "%lld photo", other: "%lld photos")
    }

    private func summaryRows(_ lines: [Line]) -> [String] {
        var rows = [heading]
        if lines.isEmpty {
            rows.append(emptyLine)
        }
        rows += lines.map { line in
            var row = "- " + ([line.title, line.dates] + [line.length].compactMap { $0 }).joined(separator: ", ")
            if let signs = line.signs { row += ". " + signs }
            return row
        }
        if !caughtAtHome.isEmpty {
            rows.append(tr("Also caught at home:"))
            rows += caughtAtHome.map { "- " + $0 }
        }
        rows.append(tr("Dates and germs as logged in Germigo, with no diagnosis."))
        return rows
    }

    private func packet(_ lines: [Line], others: [PatientPhoto]) -> DoctorPacket {
        var sections = lines.map { DoctorPacket.Section(title: $0.title + ", " + $0.dates, photoIDs: $0.photos.map { $0.id }) }
        sections.append(DoctorPacket.Section(title: tr("Other photos"), photoIDs: others.map { $0.id }))
        return DoctorPacket(lines: summaryRows(lines), sections: sections)
    }

    var body: some View {
        let all = lines
        let found = all.filter { model.isShown($0.start, ongoing: $0.ongoing) }
        let others = otherPhotos(found)
        let photoCount = found.reduce(others.count) { $0 + $1.photos.count }
        let shown = (found.flatMap { $0.photos } + others).sorted { $0.takenAt < $1.takenAt }
        let opening = found.first(where: { $0.ongoing })?.id ?? found.first?.id
        VStack(alignment: .leading, spacing: 14) {
            if asPaper {
                paper(found, others: others)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(heading)
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(counts(found, photos: photoCount))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.bottom, 6)
                    if found.isEmpty {
                        Text(emptyLine)
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .padding(.vertical, 8)
                    }
                    ForEach(Array(found.enumerated()), id: \.element.id) { item in
                        dayLineView(item.element, open: (item.element.id == opening) != toggled.contains(item.element.id))
                            .cascadeIn(item.offset)
                    }
                    if !others.isEmpty {
                        Divider()
                        Text(tr("Other photos"))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .padding(.top, 12)
                        PhotoRow(photos: others, side: 56)
                            .padding(.top, 8)
                            .padding(.bottom, 12)
                    }
                    if !caughtAtHome.isEmpty {
                        Text(tr("Also caught at home:"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .padding(.top, 8)
                        ForEach(caughtAtHome, id: \.self) { item in
                            Text(item)
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .germigoCard()
            }
            if all.count > found.count {
                LockedHistoryRow(count: all.count - found.count)
            }
            if asPaper {
                paperActions(found, others: others)
            } else {
                Text(tr("Dates and germs as you logged them. Germigo adds no diagnosis."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
                if !shown.isEmpty || model.hasPass {
                    HStack(spacing: 10) {
                        if let first = shown.first {
                            Button {
                                focus = PhotoFocus(ids: shown.map { $0.id }, start: first.id)
                            } label: {
                                Label(tr("Show photos"), systemImage: "photo.stack")
                            }
                            .buttonStyle(PillButtonStyle(kind: .ink))
                        }
                        if model.hasPass {
                            ShareLink(item: packet(found, others: others), preview: SharePreview(tr("For the doctor"))) {
                                Label(tr("Share"), systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(PillButtonStyle(kind: shown.isEmpty ? .ink : .ghost))
                        }
                    }
                }
                if model.hasPass {
                    ShareLink(item: summaryRows(found).joined(separator: "\n")) {
                        Text(tr("Share as text"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.inkSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                } else {
                    Button {
                        showPaywall = true
                    } label: {
                        Label(tr("Share for the doctor"), systemImage: "lock.fill")
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(item: $seed) { seed in
            AddPhotoSheet(seed: seed)
        }
        .fullScreenCover(item: $focus) { focus in
            PhotoViewer(focus: focus)
        }
    }

    /// An illness with a row per day; closed, it shows only its dates and how many photos it holds.
    private func dayLineView(_ line: Line, open: Bool) -> some View {
        let span = ([line.dates] + [line.length].compactMap { $0 }).joined(separator: " · ")
        let calendar = Calendar.current
        let loose = line.photos.filter { photo in !line.days.contains { calendar.isDate(photo.takenAt, inSameDayAs: $0) } }
        return VStack(alignment: .leading, spacing: 2) {
            Divider()
                .padding(.bottom, 10)
            Button {
                withAnimation(Tempo.quick) {
                    if toggled.contains(line.id) {
                        toggled.remove(line.id)
                    } else {
                        toggled.insert(line.id)
                    }
                }
            } label: {
                HStack(alignment: open ? .firstTextBaseline : .center) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(line.title)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        if !open {
                            Text(span)
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                        }
                    }
                    Spacer(minLength: 8)
                    if open {
                        Text(span)
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                            .multilineTextAlignment(.trailing)
                    } else {
                        Text(line.photos.isEmpty ? tr("No photos")
                                                 : trCount(line.photos.count, one: "%lld photo", other: "%lld photos"))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.inkTertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(open ? tr("Expanded") : tr("Collapsed"))
            if open {
                if let signs = line.signs {
                    Text(signs)
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.bottom, 4)
                }
                ForEach(Array(line.days.enumerated()), id: \.element) { item in
                    dayRow(line, day: item.element, number: item.offset + 1)
                }
                if !loose.isEmpty {
                    HStack(spacing: 10) {
                        Text(tr("Other days"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .frame(width: 92, alignment: .leading)
                        PhotoRow(photos: loose.sorted { $0.takenAt < $1.takenAt }, side: 50)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
    }

    private func dayRow(_ line: Line, day: Date, number: Int) -> some View {
        let calendar = Calendar.current
        let today = calendar.isDateInToday(day)
        let shots = line.photos.filter { calendar.isDate($0.takenAt, inSameDayAs: day) }.sorted { $0.takenAt < $1.takenAt }
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
                addPhoto(line, on: day, today: today)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    /// The page the doctor receives, drawn as a sheet of paper: who, which months, each illness and its photos.
    private func paper(_ found: [Line], others: [PatientPhoto]) -> some View {
        let ink = Color(hex: Swatch.ink)
        let soft = ink.opacity(0.72)
        let from = since ?? found.last?.start ?? Date()
        let period = tr("%1$@ to %2$@", day(from), Date().formatted(.dateTime.month(.abbreviated).day().year()))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image("record-doctor")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr("Germigo · For the doctor"))
                        .font(.caption2)
                        .foregroundStyle(soft)
                    Text(model.name(for: person))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(ink)
                    Text(period)
                        .font(.footnote)
                        .foregroundStyle(soft)
                }
            }
            .padding(.bottom, 10)
            .padding(.trailing, 20)
            if found.isEmpty && others.isEmpty {
                PaperRule()
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("Nothing to report."))
                        .font(.headline)
                        .foregroundStyle(ink)
                    Text(tr("No germ logged for %1$@ since %2$@. The page fills itself as you log.",
                            model.name(for: person), day(from)))
                        .font(.subheadline)
                        .foregroundStyle(soft)
                }
                .padding(.vertical, 14)
            }
            ForEach(Array(found.enumerated()), id: \.element.id) { item in
                PaperRule()
                paperRow(item.element, ink: ink, soft: soft)
                    .cascadeIn(item.offset)
            }
            if !others.isEmpty {
                PaperRule()
                Text(tr("Other photos"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ink)
                    .padding(.top, 10)
                PhotoRow(photos: others, side: 44)
                    .padding(.vertical, 8)
            }
            if !caughtAtHome.isEmpty {
                PaperRule()
                Text(tr("Also caught at home:"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(ink)
                    .padding(.top, 10)
                ForEach(caughtAtHome, id: \.self) { item in
                    Text(item)
                        .font(.footnote)
                        .foregroundStyle(soft)
                }
            }
            PaperRule()
            Text(tr("Dates and germs as logged in Germigo, with no diagnosis."))
                .font(.caption2)
                .foregroundStyle(soft)
                .padding(.top, 10)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            DogEaredPaper()
                .fill(Color.white)
                .shadow(color: ink.opacity(0.12), radius: 12, y: 8)
        }
        .overlay(alignment: .topTrailing) {
            PaperFold()
                .fill(Color(hex: Swatch.mistDeep))
                .frame(width: DogEaredPaper.fold, height: DogEaredPaper.fold)
        }
        .accessibilityElement(children: .contain)
    }

    private func paperRow(_ line: Line, ink: Color, soft: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(line.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ink)
                Spacer(minLength: 8)
                Text(([line.dates] + [line.length].compactMap { $0 }).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(soft)
                    .multilineTextAlignment(.trailing)
            }
            if let signs = line.signs {
                Text(signs)
                    .font(.footnote)
                    .foregroundStyle(soft)
            }
            if !line.photos.isEmpty {
                PhotoRow(photos: line.photos, side: 44)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 10)
    }

    /// Under the page: send it as a PDF or copy it as text, once there is something on it.
    @ViewBuilder
    private func paperActions(_ found: [Line], others: [PatientPhoto]) -> some View {
        if !found.isEmpty || !others.isEmpty {
            if model.hasPass {
                ShareLink(item: packet(found, others: others), preview: SharePreview(tr("For the doctor"))) {
                    Label(tr("Send the PDF"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PillButtonStyle(kind: .ink))
                Button {
                    UIPasteboard.general.string = summaryRows(found).joined(separator: "\n")
                    Haptics.tap()
                    model.toast = tr("Text copied.")
                } label: {
                    Text(tr("Copy as text"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Label(tr("Send the PDF"), systemImage: "lock.fill")
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))
            }
        }
    }

    /// A new photo for this person on that day of the illness: now for today, midday for a past day.
    private func addPhoto(_ line: Line, on day: Date, today: Bool) {
        guard model.hasPass else {
            showPaywall = true
            return
        }
        let moment = today ? Date() : Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
        seed = PhotoSeed(person: person, takenAt: moment, link: line.link)
    }
}

/// A sheet of paper with its top right corner folded down.
private struct DogEaredPaper: Shape {
    static let fold: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - Self.fold, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + Self.fold))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The folded corner of the paper.
private struct PaperFold: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A thin line between the parts of the paper.
private struct PaperRule: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: Swatch.mistDeep))
            .frame(height: 1)
    }
}

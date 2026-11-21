import SwiftUI

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
                    Picker(tr("Who"), selection: Binding(get: { current }, set: { person = $0 })) {
                        ForEach(people, id: \.self) { member in
                            Text(model.name(for: member)).tag(member)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                HealthHistory(person: current, since: Calendar.current.date(byAdding: .month, value: -6, to: Date()))
                    .id(current)
                    .transition(.opacity)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .animation(.snappy, value: current)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("For the doctor"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One person's illnesses, with dates, signs and photos, and the ways to send them to a doctor.
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
    }

    let person: Person
    /// The oldest illness shown; nil shows everything.
    let since: Date?
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showPaywall = false

    private func kept(_ date: Date) -> Bool {
        since.map { date >= $0 } ?? true
    }

    private func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func illnessName(_ germID: String) -> String {
        model.catalog.germ(germID)?.illness.value ?? germID
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
                                start: log.startedAt, ongoing: log.endedAt == nil)
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
                    return Line(id: illness.id, title: illnessName(illness.germID), dates: dates, length: length,
                                signs: signs(illness.symptoms), photos: photos.filter { $0.illnessID == illness.id },
                                start: illness.startedAt, ongoing: going)
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
        VStack(alignment: .leading, spacing: 14) {
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
                    lineView(item.element)
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
            if all.count > found.count {
                LockedHistoryRow(count: all.count - found.count)
            }
            Text(tr("Dates and germs as you logged them. Germigo adds no diagnosis."))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .padding(.horizontal, 4)
            if model.hasPass {
                ShareLink(item: packet(found, others: others), preview: SharePreview(tr("For the doctor"))) {
                    Label(tr("Share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PillButtonStyle(kind: .ink))
                ShareLink(item: summaryRows(found).joined(separator: "\n")) {
                    Label(tr("Share as text"), systemImage: "text.alignleft")
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Label(tr("Share for the doctor"), systemImage: "lock.fill")
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private func lineView(_ line: Line) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider()
                .padding(.bottom, 10)
            HStack(alignment: .firstTextBaseline) {
                Text(line.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Spacer(minLength: 8)
                Text(([line.dates] + [line.length].compactMap { $0 }).joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.trailing)
            }
            if let signs = line.signs {
                Text(signs)
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
            }
            if !line.photos.isEmpty {
                PhotoRow(photos: line.photos, side: 56)
                    .padding(.top, 8)
            }
        }
        .padding(.bottom, 12)
        .accessibilityElement(children: .contain)
    }
}

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
                            .background(germ.lightTint, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
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
                    .germilyCard()
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
                    .germilyCard()
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tr("Sources"))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.inkSecondary)
                        ForEach(sources, id: \.url) { source in
                            if let url = source.link {
                                Link(source.name, destination: url)
                                    .font(.footnote)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                if let daycare = model.household?.daycare, let url = daycare.link {
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
                    .germilyCard()
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
                HealthHistory(person: current, since: Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date())
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

/// The page a doctor receives for one person: their illnesses since a date, with signs and photos,
/// and the ways to send it.
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
    /// The oldest illness shown.
    let since: Date
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var door: PassReason?

    private func kept(_ date: Date) -> Bool {
        date >= since
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
        tr("%@ · last 6 months", model.name(for: person))
    }

    private var emptyLine: String {
        tr("Nothing logged in the last 6 months.")
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
        rows.append(tr("Dates and germs as logged in Germily, with no diagnosis."))
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
        VStack(alignment: .leading, spacing: 14) {
            paper(found, others: others)
            if all.count > found.count {
                LockedHistoryRow(count: all.count - found.count)
            }
            paperActions(found, others: others)
        }
        .sheet(item: $door) { reason in
            PaywallView(reason: reason)
        }
    }

    /// The page the doctor receives, drawn as a sheet of paper: who, which months, each illness and its photos.
    private func paper(_ found: [Line], others: [PatientPhoto]) -> some View {
        let ink = Color(hex: Swatch.ink)
        let soft = ink.opacity(0.72)
        let from = since
        let period = tr("%1$@ to %2$@", day(from), Date().formatted(.dateTime.month(.abbreviated).day().year()))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image("record-doctor")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr("Germily · For the doctor"))
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
            Text(tr("Dates and germs as logged in Germily, with no diagnosis."))
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
                    Clipboard.copy(summaryRows(found).joined(separator: "\n"))
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
                    door = .doctor
                } label: {
                    Label(tr("Send the PDF"), systemImage: "lock.fill")
                }
                .buttonStyle(PillButtonStyle(kind: .ghost))
                offerLine
            }
        }
    }

    /// Under a locked way to send the file: what the Season Pass opens, and the offer.
    private var offerLine: some View {
        PassOfferText(reason: .doctor)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(palette.accent)
            .frame(maxWidth: .infinity)
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

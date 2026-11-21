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
                            .background(germ.lightTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                    .petriCard()
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
                    .petriCard()
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
                    .petriCard()
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
                Button(tr("Done")) {
                    onDone()
                }
                .fontWeight(.semibold)
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

/// The last six months of germs for one person, to read out or send before an appointment.
struct DoctorSummaryScreen: View {
    private enum Person: Hashable {
        case me
        case kid(UUID)
    }

    private struct Line: Identifiable {
        let id: UUID
        let title: String
        let dates: String
        let length: String?
    }

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var person: Person?

    private var since: Date {
        Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
    }

    private var current: Person {
        person ?? model.data.kids.first.map { Person.kid($0.id) } ?? .me
    }

    private var name: String {
        switch current {
        case .me: return model.displayName
        case .kid(let id): return model.kid(id)?.name ?? ""
        }
    }

    private func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func illnessName(_ germID: String) -> String {
        model.catalog.germ(germID)?.illness.value ?? germID
    }

    private var lines: [Line] {
        switch current {
        case .me:
            return model.data.logs.filter { $0.sufferer.includesMe && $0.startedAt >= since }
                .sorted { $0.startedAt > $1.startedAt }
                .map { log in
                    let dates = log.endedAt.map { tr("%1$@ to %2$@", day(log.startedAt), day($0)) }
                        ?? tr("Since %@", day(log.startedAt))
                    return Line(id: log.id, title: illnessName(log.germID), dates: dates,
                                length: trCount(log.dayCount(), one: "%lld day", other: "%lld days"))
                }
        case .kid(let id):
            return model.data.kidIllnesses.filter { $0.kidID == id && $0.startedAt >= since }
                .sorted { $0.startedAt > $1.startedAt }
                .map { Line(id: $0.id, title: illnessName($0.germID), dates: tr("Started %@", day($0.startedAt)), length: nil) }
        }
    }

    /// What the parents caught from this kid, through the logs linked to its illnesses.
    private var caughtAtHome: [String] {
        guard case .kid(let id) = current else { return [] }
        let ids = Set(model.data.kidIllnesses.filter { $0.kidID == id && $0.startedAt >= since }.map { $0.id })
        return model.data.logs.filter { log in log.kidIllnessID.map { ids.contains($0) } ?? false }
            .sorted { $0.startedAt < $1.startedAt }
            .map { tr("%1$@: %2$@, %3$@", model.name(of: $0.sufferer), illnessName($0.germID), day($0.startedAt)) }
    }

    private var summaryText: String {
        var rows = [tr("%@ · last 6 months", name)]
        if lines.isEmpty {
            rows.append(tr("Nothing logged in the last 6 months."))
        }
        rows += lines.map { line in "- " + ([line.title, line.dates] + [line.length].compactMap { $0 }).joined(separator: ", ") }
        if !caughtAtHome.isEmpty {
            rows.append(tr("Also caught at home:"))
            rows += caughtAtHome.map { "- " + $0 }
        }
        rows.append(tr("Dates and germs as logged in Petri, with no diagnosis."))
        return rows.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker(tr("Who"), selection: Binding(get: { current }, set: { person = $0 })) {
                    ForEach(model.data.kids) { kid in
                        Text(kid.name).tag(Person.kid(kid.id))
                    }
                    Text(tr("Me")).tag(Person.me)
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr("%@ · last 6 months", name))
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(trCount(lines.count, one: "%lld illness", other: "%lld illnesses"))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.bottom, 6)
                    if lines.isEmpty {
                        Text(tr("Nothing logged in the last 6 months."))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .padding(.vertical, 8)
                    }
                    ForEach(lines) { line in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.title)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(palette.ink)
                                Text(line.dates)
                                    .font(.footnote)
                                    .foregroundStyle(palette.inkSecondary)
                            }
                            Spacer(minLength: 8)
                            if let length = line.length {
                                Text(length)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.ink)
                            }
                        }
                        .padding(.vertical, 8)
                        .accessibilityElement(children: .combine)
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
                .petriCard()
                Text(tr("Dates and germs as you logged them. Petri adds no diagnosis."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
                ShareLink(item: summaryText) {
                    Label(tr("Share as text"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PillButtonStyle(kind: .ink))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("For the doctor"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

import SwiftUI

// The sections of a person's file in Family: the illness going on, the numbers, the season day by day,
// the history, what keeps coming back, the patterns, who brought the germs, the photos and the doctor's file.

/// A germ's picture on its tint, the way rows of germs show it.
private struct IllnessTile: View {
    let germID: String
    let side: CGFloat
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let germ = model.catalog.germ(germID)
        ZStack {
            if let germ {
                GermImage(germ: germ, size: side * 0.8)
            }
        }
        .frame(width: side, height: side)
        .background(germ?.tileTint(palette) ?? palette.surfaceAlt,
                    in: RoundedRectangle(cornerRadius: side * 0.32, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// A card's title, with a quiet line on the right.
private struct FileHeader: View {
    let title: String
    var detail: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.ink)
            Spacer(minLength: 8)
            if let detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
        }
    }
}

private extension Date {
    var shortDay: String { formatted(.dateTime.month(.abbreviated).day()) }
}

/// The illness going on: its day against the germ's usual length, the signs ticked, a photo and the case file.
struct PersonNowCard: View {
    let person: Person
    let illness: PersonIllness
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var seed: PhotoSeed?

    var body: some View {
        let germ = model.catalog.germ(illness.germID)
        VStack(alignment: .leading, spacing: 12) {
            FileHeader(title: tr("Right now"), detail: tr("Since %@", illness.start.shortDay))
            HStack(spacing: 12) {
                IllnessTile(germID: illness.germID, side: 54)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("%1$@, day %2$lld", germ?.illness.value ?? "", illness.days))
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    if let germ {
                        Text(tr("Usually lasts %@.", germ.lasts.value))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                    }
                }
            }
            if let upTo = germ?.lastsUpToDays, upTo > 1 {
                VStack(spacing: 4) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(palette.ink.opacity(0.08))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(palette.accent)
                                    .frame(width: proxy.size.width * min(1, Double(illness.days) / Double(upTo)))
                            }
                    }
                    .frame(height: 8)
                    HStack {
                        Text(tr("Day %lld", 1))
                        Spacer()
                        Text(tr("Day %lld", upTo))
                    }
                    .font(.caption2)
                    .foregroundStyle(palette.inkTertiary)
                }
                .accessibilityHidden(true)
            }
            let signs = Symptom.ordered(Set(illness.symptoms))
            if !signs.isEmpty {
                ChipRows(spacing: 6) {
                    ForEach(signs) { sign in
                        Text(sign.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(palette.accent.opacity(0.12), in: Capsule())
                    }
                }
            }
            HStack(spacing: 8) {
                Button {
                    addPhoto()
                } label: {
                    Label(tr("Add a photo"), systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PillButtonStyle(kind: .ghost, height: 42))
                if let germ {
                    NavigationLink {
                        GermDetailScreen(germ: germ)
                    } label: {
                        Label(tr("Case file"), systemImage: "book.closed")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost, height: 42))
                }
            }
        }
        .germilyCard()
        .sheet(item: $seed) { seed in
            AddPhotoSheet(seed: seed)
        }
    }

    private func addPhoto() {
        let now = Date()
        seed = PhotoSeed(person: person, takenAt: now, link: model.photoLink(for: person, on: now))
    }
}

/// The person's numbers, side by side in one card.
struct PersonNumbers: View {
    let person: Person
    let illnesses: [PersonIllness]
    @Environment(AppModel.self) private var model

    var body: some View {
        NumberStrip(values: values)
    }

    private var values: [(Int, String)] {
        let days = illnesses.reduce(0) { $0 + $1.days }
        switch person {
        case .kid(let id):
            return [(illnesses.count, tr("brought home")), (days, tr("days sick")),
                    (model.data.logs.filter { $0.source == .kid(id) }.count, tr("got you")),
                    (illnesses.filter { $0.dodged }.count, tr("you dodged"))]
        case .me:
            return [(illnesses.count, tr("germs caught")), (days, tr("days sick")),
                    (model.data.kidIllnesses.filter { $0.outcome == .dodged }.count, tr("dodged")),
                    (StreakMath.record(data: model.data, now: Date()), tr("best run"))]
        case .partner:
            return [(illnesses.count, tr("germs caught")), (days, tr("days sick"))]
        }
    }
}

/// Numbers side by side in one card, split by thin lines: the person file and the season page.
struct NumberStrip: View {
    let values: [(Int, String)]
    @Environment(\.palette) private var palette
    /// The big numbers, the same size as on Trophies and following the text size set in iOS.
    @ScaledMetric(relativeTo: .title) private var figureSize: CGFloat = 26

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(values.enumerated()), id: \.offset) { item in
                VStack(spacing: 1) {
                    RollingNumber(value: item.element.0)
                        .font(.system(size: figureSize, weight: .bold))
                        .foregroundStyle(palette.ink)
                    Text(item.element.1)
                        .font(.caption)
                        .foregroundStyle(palette.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    if item.offset > 0 {
                        Rectangle()
                            .fill(palette.ink.opacity(0.08))
                            .frame(width: 1)
                            .padding(.vertical, 4)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .germilyCard(padding: 12)
    }
}

/// The season day by day: a square per day since September, in the color of the germ of that day.
struct PersonSeasonCard: View {
    let illnesses: [PersonIllness]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let season = model.season
        let sick = PersonFileEngine.sickDays(illnesses, in: season)
        let since = PersonFileEngine.trackedSince(data: model.data)
        let year = Calendar.current.component(.year, from: season.start)
        let germs = illnesses.filter { season.contains($0.start) }.reduce(into: [String]()) { list, illness in
            if !list.contains(illness.germID) { list.append(illness.germID) }
        }
        VStack(alignment: .leading, spacing: 10) {
            FileHeader(title: tr("This season"), detail: "\(year)–\(String(year + 1).suffix(2))")
            SeasonStrip(season: season, sick: sick, since: since)
            if !germs.isEmpty {
                ChipRows(spacing: 10) {
                    ForEach(germs, id: \.self) { id in
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                .fill(SeasonStrip.color(of: id, model: model, palette: palette))
                                .frame(width: 9, height: 9)
                            Text(model.catalog.germ(id)?.illness.value ?? "")
                                .font(.caption)
                                .foregroundStyle(palette.inkSecondary)
                        }
                    }
                }
                .accessibilityHidden(true)
            }
            Text(seasonSickLine(sick.count, season: season, since: since))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
        }
        .germilyCard()
    }
}

/// How many days of the season were sick, counted from the first day the journal covers when that came later.
private func seasonSickLine(_ count: Int, season: Season, since: Date) -> String {
    guard since > season.start else {
        return tr("Sick %1$lld days out of %2$lld this season.", count, PersonFileEngine.seasonDaysSoFar(season, now: Date()))
    }
    return tr("Sick %1$lld days since %2$@.", count, since.formatted(.dateTime.month(.abbreviated).day()))
}

/// The squares of a season, a column per week, with the months underneath.
/// Days before the journal began look like days to come: nothing was followed then.
private struct SeasonStrip: View {
    let season: Season
    let sick: [Date: String]
    let since: Date
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    static func color(of germID: String, model: AppModel, palette: Palette) -> Color {
        (model.catalog.germ(germID)?.deepTint ?? palette.accent).mix(with: palette.ink, by: 0.28)
    }

    var body: some View {
        let calendar = Calendar.current
        let offset = (calendar.component(.weekday, from: season.start) + 5) % 7
        let total = StreakMath.days(from: season.start, to: season.end)
        let weeks = (offset + total + 6) / 7
        let today = calendar.startOfDay(for: Date())
        Canvas { context, size in
            let step = size.width / CGFloat(weeks)
            let cell = step * 0.78
            for index in 0..<total {
                guard let day = calendar.date(byAdding: .day, value: index, to: season.start) else { continue }
                let slot = index + offset
                let rect = CGRect(x: CGFloat(slot / 7) * step, y: CGFloat(slot % 7) * step, width: cell, height: cell)
                let color: Color = sick[calendar.startOfDay(for: day)].map { Self.color(of: $0, model: model, palette: palette) }
                    ?? palette.ink.opacity(day > today || day < since ? 0.035 : 0.08)
                context.fill(Path(roundedRect: rect, cornerRadius: cell * 0.28), with: .color(color))
            }
            for month in stride(from: 0, to: 12, by: 2) {
                guard let first = calendar.date(byAdding: .month, value: month, to: season.start) else { continue }
                let slot = StreakMath.days(from: season.start, to: first) + offset
                let label = Text(first.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2)
                    .foregroundStyle(palette.inkTertiary)
                context.draw(label, at: CGPoint(x: CGFloat(slot / 7) * step, y: 7 * step + 3), anchor: .topLeading)
            }
        }
        .aspectRatio(CGFloat(weeks) / 9.6, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(seasonSickLine(sick.count, season: season, since: since))
    }
}

/// The last illnesses the journal shows, and the way to all of them in the logbook.
struct PersonHistoryCard: View {
    let person: Person
    let illnesses: [PersonIllness]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let shown = illnesses.filter { model.isShown($0.start, ongoing: $0.goingOn) }
        let hidden = illnesses.count - shown.count
        VStack(spacing: 10) {
            NavigationLink {
                LogbookScreen(person: person)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(tr("History"))
                            .font(.headline)
                            .foregroundStyle(palette.ink)
                        Spacer(minLength: 8)
                        if !shown.isEmpty {
                            Text(tr("Logbook"))
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                        }
                        RowChevron()
                    }
                    if shown.isEmpty {
                        HStack(spacing: 12) {
                            Image("record-logbook")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .accessibilityHidden(true)
                            Text(hidden > 0 ? tr("Nothing in the last 7 days.") : tr("Nothing logged yet."))
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                        }
                        .padding(.top, 4)
                    }
                    ForEach(shown.prefix(3)) { illness in
                        HStack(spacing: 11) {
                            IllnessTile(germID: illness.germID, side: 38)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(model.catalog.germ(illness.germID)?.illness.value ?? "")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(palette.ink)
                                Text(line(illness))
                                    .font(.caption)
                                    .foregroundStyle(palette.inkSecondary)
                            }
                            Spacer(minLength: 0)
                            if let severity = illness.severity {
                                SeverityGauge(level: severity, germ: model.catalog.germ(illness.germID))
                            }
                        }
                        .padding(.top, 6)
                        .accessibilityElement(children: .combine)
                    }
                }
                .multilineTextAlignment(.leading)
                .germilyCard()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if hidden > 0 {
                LockedHistoryRow(title: model.lockedHistoryTitle(for: person, hidden: hidden))
            }
        }
    }

    private func line(_ illness: PersonIllness) -> String {
        var parts = [illness.start.shortDay,
                     illness.goingOn ? tr("going on") : trCount(illness.days, one: "%lld day", other: "%lld days")]
        switch illness.note {
        case .gotYou: parts.append(tr("got you"))
        case .youDodged: parts.append(tr("you dodged it"))
        case .from(.kid(let id)): parts.append(tr("from %@", model.name(for: .kid(id))))
        case .from(.partner): parts.append(tr("from %@", model.name(for: .partner)))
        case .from(.daycare): parts.append(tr("from daycare"))
        case .from(.unknown), nil: break
        }
        return parts.joined(separator: " · ")
    }
}

/// The germs that came most often.
struct PersonComingBackCard: View {
    let illnesses: [PersonIllness]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FileHeader(title: tr("What keeps coming back"),
                       detail: trCount(illnesses.count, one: "%lld germ", other: "%lld germs"))
            ForEach(PersonFileEngine.comingBack(illnesses).prefix(3), id: \.germID) { item in
                HStack(spacing: 11) {
                    IllnessTile(germID: item.germID, side: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(model.catalog.germ(item.germID)?.illness.value ?? "")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Text(tr("Last: %@", item.last.start.shortDay))
                            .font(.caption)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    Spacer(minLength: 8)
                    Text(verbatim: "×\(item.count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.ink)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .germilyCard()
    }
}

/// Days sick by month, the usual length and the worst month. Counts only.
struct PersonPatternsCard: View {
    let illnesses: [PersonIllness]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let season = model.season
        let totals = PersonFileEngine.monthTotals(PersonFileEngine.sickDays(illnesses, in: season), season: season)
        let top = max(1, totals.max() ?? 1)
        let worst = totals.firstIndex(of: totals.max() ?? 0)
        let monthsSoFar = (Calendar.current.dateComponents([.month], from: season.start, to: Date()).month ?? 0) + 1
        let longest = illnesses.filter { !$0.goingOn }.max { $0.days < $1.days }
        VStack(alignment: .leading, spacing: 10) {
            FileHeader(title: tr("Patterns"), detail: tr("Days sick by month"))
            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<12, id: \.self) { month in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(month == worst && totals[month] > 0 ? palette.accent
                                  : palette.ink.opacity(month < monthsSoFar ? 0.12 : 0.05))
                            .frame(height: max(3, 46 * CGFloat(totals[month]) / CGFloat(top)))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 46, alignment: .bottom)
                HStack(spacing: 5) {
                    ForEach(0..<12, id: \.self) { month in
                        Text(Calendar.current.date(byAdding: .month, value: month, to: season.start)?
                                .formatted(.dateTime.month(.narrow)) ?? "")
                            .font(.caption2)
                            .foregroundStyle(palette.inkTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .accessibilityHidden(true)
            if let usual = PersonFileEngine.usualDays(illnesses) {
                fact("clock", tr("Usually sick about %lld days.", usual)
                     + (longest.map { " " + tr("Longest: %1$@, %2$lld days.", model.catalog.germ($0.germID)?.illness.value ?? "", $0.days) } ?? ""))
            }
            if let worst, totals[worst] > 0,
               let month = Calendar.current.date(byAdding: .month, value: worst, to: season.start) {
                fact("calendar", tr("%1$@ was the worst: %2$lld days sick.", month.formatted(.dateTime.month(.wide)), totals[worst]))
            }
        }
        .germilyCard()
    }

    private func fact(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 32, height: 32)
                .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Where a parent's germs came from, the most frequent first.
struct PersonSuppliersCard: View {
    let person: Person
    let illnesses: [PersonIllness]
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let sources = illnesses.reduce(into: [GermSource: Int]()) { counts, illness in
            if case .from(let source)? = illness.note, source != .unknown { counts[source, default: 0] += 1 }
        }
        .sorted { $0.value > $1.value }
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                FileHeader(title: person == .me ? tr("Who got you") : tr("Who got %@", model.name(for: person)))
                ForEach(Array(sources.prefix(3).enumerated()), id: \.offset) { item in
                    HStack(spacing: 10) {
                        face(item.element.key)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(verbatim: name(item.element.key) + " ×\(item.element.value)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.ink)
                            if item.offset == 0 {
                                Text(tr("Top supplier"))
                                    .font(.caption)
                                    .foregroundStyle(palette.inkSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .germilyCard()
        }
    }

    @ViewBuilder
    private func face(_ source: GermSource) -> some View {
        switch source {
        case .kid(let id):
            BuddyView(look: model.look(of: .kid(id)), size: 30)
                .frame(width: 38, height: 38)
        case .partner:
            BuddyView(look: model.look(of: .partner), size: 30)
                .frame(width: 38, height: 38)
        case .daycare, .unknown:
            Image(systemName: "backpack.fill")
                .font(.body)
                .foregroundStyle(palette.accent)
                .frame(width: 38, height: 38)
                .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func name(_ source: GermSource) -> String {
        switch source {
        case .kid(let id): return model.name(for: .kid(id))
        case .partner: return model.name(for: .partner)
        case .daycare, .unknown: return tr("Daycare")
        }
    }
}

/// The person's latest photos and the way to the album, opened on them.
struct PersonPhotosCard: View {
    let person: Person
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let photos = model.data.photos.filter { $0.person == person }.sorted { $0.takenAt > $1.takenAt }
        if !photos.isEmpty {
            NavigationLink {
                AlbumScreen(person: person)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(tr("Photos"))
                            .font(.headline)
                            .foregroundStyle(palette.ink)
                        Spacer(minLength: 8)
                        Text(verbatim: "\(photos.count)")
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                        RowChevron()
                    }
                    HStack(spacing: 7) {
                        ForEach(photos.prefix(4)) { photo in
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    if let image = PhotoStore.thumbnail(photo.id, side: 160) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    }
                                }
                                .background(palette.ink.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        ForEach(0..<max(0, 4 - photos.count), id: \.self) { _ in
                            Color.clear.aspectRatio(1, contentMode: .fit)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .germilyCard()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(tr("Photos") + ", \(photos.count)")
        }
    }
}

/// The way to the page a doctor receives for this person.
struct PersonDoctorRow: View {
    let person: Person
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationLink {
            DoctorSummaryScreen(person: person)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "stethoscope")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 42, height: 42)
                    .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("For the doctor"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Text(tr("6 months of dates, signs and photos, in one PDF"))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                RowChevron()
            }
            .germilyCard(padding: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// What the Season Pass adds to a person's file, in one locked card.
struct PersonPassCard: View {
    @Environment(\.palette) private var palette
    @State private var showPaywall = false

    var body: some View {
        Button {
            showPaywall = true
        } label: {
            VStack(spacing: 6) {
                PassLock()
                Text(tr("Season, patterns and photos"))
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                Text(tr("The season day by day, what keeps coming back, the photos and the doctor's PDF."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                PassOfferTag()
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .germilyCard(padding: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .stats)
        }
    }
}

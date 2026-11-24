import SwiftUI

/// The daycare year in numbers, opened from Trophies. Before the season's first germ it says what will fill it.
struct SeasonScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showWrapped = false
    @State private var showDuel = false
    @State private var showMonth = false
    @State private var showPartner = false

    /// Zero is the current season; each step goes one daycare year back.
    @State private var seasonsBack = 0

    var body: some View {
        let seasonCount = model.season.number
        let season = model.season(back: min(seasonsBack, seasonCount - 1))
        let stats = model.seasonStats(for: season)
        let untouched = StatsEngine.isUntouched(data: model.data, season: season)
        let hatched = StatsEngine.monthsBeforeJournal(since: PersonFileEngine.trackedSince(data: model.data), season: season)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(rangeLabel(season))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
                if untouched && seasonsBack == 0 {
                    startCard(stats, season: season, hatched: hatched)
                } else {
                    NumberStrip(values: [(stats.germsCaught, tr("germs caught")), (stats.daysSick, tr("days sick")),
                                         (stats.dodged, tr("germs dodged"))])
                    chartCard(stats, season: season, hatched: hatched)
                    if let supplier = stats.topSupplier {
                        supplierCard(supplier)
                    }
                    if let chain = stats.longestChain {
                        chainCard(chain)
                    }
                }
                duelCard(season)
                if !untouched {
                    shareCard(season)
                }
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Season %lld", season.number))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if seasonCount > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(0..<seasonCount, id: \.self) { back in
                            Button(tr("Season %lld", seasonCount - back)) {
                                seasonsBack = back
                            }
                        }
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel(tr("Seasons"))
                }
            }
            if !untouched {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showWrapped = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(tr("Season recap"))
                }
            }
        }
        .fullScreenCover(isPresented: $showWrapped) {
            WrappedScreen(season: season)
        }
        .sheet(isPresented: $showMonth) {
            SharePreviewSheet(title: tr("Month recap")) {
                MonthRecapCard(recap: model.lastMonthRecap())
            }
        }
        .sheet(isPresented: $showPartner) {
            PartnerEditSheet()
        }
        .sheet(isPresented: $showDuel) {
            SharePreviewSheet(title: tr("Couple duel")) {
                DuelShareCard(seasonNumber: season.number, me: model.displayName, meLook: model.data.hostLook,
                              partner: model.partnerDisplayName, partnerLook: model.data.partnerLook,
                              stats: DuelEngine.stats(data: model.data, season: season, now: Date()))
            }
        }
    }

    /// Before the season's first germ: what this page will hold, and where the season stands.
    private func startCard(_ stats: SeasonStats, season: Season, hatched: Int) -> some View {
        let since = PersonFileEngine.trackedSince(data: model.data)
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image("mascot-giggle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 66, height: 66)
                    .rotationEffect(.degrees(-6))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("Your season starts with the first germ."))
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(tr("Germs by month, your top supplier and the longest chain fill this page."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            MonthRibbon(months: stats.months, hatched: hatched)
            if since > season.start {
                Text(tr("You started on %@.", since.formatted(.dateTime.month(.abbreviated).day())))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
        }
        .germilyCard()
    }

    /// The season's story cards and last month's card: what this page shares.
    private func shareCard(_ season: Season) -> some View {
        let recap = model.lastMonthRecap()
        let revealed = Date() >= WrapEngine.revealDate(for: season)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Share"))
            VStack(spacing: 0) {
                Button {
                    showWrapped = true
                } label: {
                    HStack(spacing: 10) {
                        RecapCardsIcon()
                        ValueRow(title: tr("Season story"), value: revealed ? tr("Ready") : tr("So far"))
                    }
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                if seasonsBack == 0, !recap.isEmpty {
                    Divider()
                        .padding(.leading, 52)
                    Button {
                        showMonth = true
                    } label: {
                        HStack(spacing: 10) {
                            IconTile(symbol: "calendar", size: 26)
                            ValueRow(title: tr("Your %@ recap", recap.monthName))
                        }
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .germilyCard(padding: 0)
        }
    }

    @ViewBuilder
    private func duelCard(_ season: Season) -> some View {
        if model.data.partnerName != nil {
            let duel = DuelEngine.stats(data: model.data, season: season, now: Date())
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("Couple duel"), trailing: duelVerdict(duel))
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        duelSide(name: model.displayName, side: duel.me, leads: duel.leader == .me,
                                 look: model.data.hostLook)
                        duelSide(name: model.partnerDisplayName, side: duel.partner, leads: duel.leader == .partner,
                                 look: model.data.partnerLook)
                    }
                    ShareCapsule(title: tr("Share the scoreboard")) {
                        showDuel = true
                    }
                }
                .germilyCard()
            }
        } else {
            Button {
                showPartner = true
            } label: {
                HStack(spacing: 14) {
                    BuddyView(look: model.data.partnerLook, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Couple duel"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Text(tr("Add your partner to start it."))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.inkTertiary)
                }
                .germilyCard(padding: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private func duelVerdict(_ duel: DuelStats) -> String {
        if duel.leader == .me { return tr("%@ leads", model.displayName) }
        if duel.leader == .partner { return tr("%@ leads", model.partnerDisplayName) }
        return tr("Tied")
    }

    private func duelSide(name: String, side: DuelSide, leads: Bool, look: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                BuddyBadge(look: look, size: 32)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                if leads {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(palette.accent)
                        .accessibilityLabel(tr("Leads"))
                }
            }
            Text(tr("%lld pts", side.points))
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(palette.ink)
            Text(tr("%1$lld germs · %2$lld days", side.germs, side.daysSick))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(leads ? palette.accent.opacity(0.22) : palette.surfaceAlt.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func rangeLabel(_ season: Season) -> String {
        let lastDay = season.end.addingTimeInterval(-86_400)
        let style = Date.FormatStyle().month(.abbreviated).year()
        guard season.contains(Date()) else {
            return tr("%1$@ to %2$@", season.start.formatted(style), lastDay.formatted(style))
        }
        let weeks = StatsEngine.sickWeekGerms(data: model.data, season: season, now: Date()).count
        return tr("Week %1$lld for you · %2$@ to %3$@", weeks, season.start.formatted(style), lastDay.formatted(style))
    }

    private func monthName(_ offset: Int, season: Season) -> String {
        let date = Calendar.current.date(byAdding: .month, value: offset, to: season.start) ?? season.start
        return date.formatted(.dateTime.month(.wide)).localizedCapitalized
    }

    private func supplierCard(_ supplier: SupplierStat) -> some View {
        HStack(spacing: 13) {
            ZStack(alignment: .bottomTrailing) {
                BuddyBadge(look: supplier.kid.colorIndex, size: 52)
                Image(systemName: "trophy.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(palette.onAccent)
                    .frame(width: 24, height: 24)
                    .background(palette.accent, in: Circle())
                    .offset(x: 6, y: 4)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Top supplier: %@", supplier.kid.name))
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                Text(tr("%1$lld of your %2$lld germs", supplier.count, supplier.total))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
            }
            Spacer(minLength: 4)
            HStack(spacing: -8) {
                ForEach(supplier.germs.prefix(3)) { germ in
                    GermImage(germ: germ, size: 34)
                }
            }
        }
        .germilyCard()
    }

    /// The season month by month, then a key to the germs whose colors the bars use.
    private func chartCard(_ stats: SeasonStats, season: Season, hatched: Int) -> some View {
        let germs = stats.months.flatMap { $0.entries.map { $0.germ } }.reduce(into: [Germ]()) { list, germ in
            if !list.contains(where: { $0.id == germ.id }) { list.append(germ) }
        }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Germs by month"))
            VStack(alignment: .leading, spacing: 12) {
                Text(chartCaption(stats, season: season))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                MonthBars(months: stats.months, hatched: hatched)
                if !germs.isEmpty {
                    ChipRows(spacing: 10) {
                        ForEach(germs) { germ in
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                    .fill(germ.deepTint)
                                    .frame(width: 9, height: 9)
                                Text(germ.illness.value)
                                    .font(.caption)
                                    .foregroundStyle(palette.inkSecondary)
                            }
                        }
                    }
                    .accessibilityHidden(true)
                }
            }
            .germilyCard()
        }
    }

    private func chartCaption(_ stats: SeasonStats, season: Season) -> String {
        guard let worst = stats.months.max(by: { $0.total < $1.total }), worst.total > 0 else {
            return tr("Nothing yet. Enjoy it while it lasts.")
        }
        let name = monthName(worst.id, season: season)
        if worst.total >= 3 {
            return tr("%1$@: %2$lld. Rough.", name, worst.total)
        }
        return tr("Busiest month so far: %@.", name)
    }

    private func chainCard(_ chain: ChainStat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Longest chain"),
                          trailing: trCount(chain.days, one: "%lld day", other: "%lld days"))
            HStack(spacing: 10) {
                chainLink(name: chain.kid.name, look: chain.kid.colorIndex, germ: chain.germ)
                if chain.sufferer.includesMe {
                    arrow
                    chainLink(name: model.displayName, look: model.data.hostLook, germ: chain.germ)
                }
                if chain.includesPartner {
                    arrow
                    chainLink(name: model.data.partnerName ?? tr("Partner"), look: model.data.partnerLook,
                              germ: chain.germ)
                }
                Spacer(minLength: 0)
            }
            .germilyCard()
        }
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(palette.inkTertiary)
            .accessibilityHidden(true)
    }

    private func chainLink(name: String, look: Int, germ: Germ) -> some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                BuddyBadge(look: look, sick: true, size: 46)
                GermImage(germ: germ, size: 24)
                    .offset(x: 8, y: 6)
            }
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
        }
        .frame(minWidth: 58)
        .accessibilityElement(children: .combine)
    }
}

/// Diagonal stripes for the months the journal did not follow.
private struct Hatch: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x = -size.height
            while x < size.width {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += 6
            }
            context.stroke(path, with: .color(palette.ink.opacity(0.16)), lineWidth: 1.2)
        }
        .background(palette.ink.opacity(0.03))
    }
}

/// The twelve months of an empty season as pills: hatched before the journal began, the current one in the accent.
private struct MonthRibbon: View {
    let months: [MonthBucket]
    let hatched: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            ForEach(months) { month in
                VStack(spacing: 6) {
                    Group {
                        if month.id < hatched {
                            Hatch()
                                .clipShape(Capsule())
                        } else {
                            Capsule()
                                .fill(month.isCurrent ? palette.accent : palette.ink.opacity(0.08))
                        }
                    }
                    .frame(height: 10)
                    MonthLetter(month: month)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The season's germs month by month, stacked in each germ's color with the count on top.
/// Months before the journal began are hatched.
private struct MonthBars: View {
    let months: [MonthBucket]
    let hatched: Int
    @Environment(\.palette) private var palette

    var body: some View {
        let scale = CGFloat(max(3, months.map { $0.total }.max() ?? 0))
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(months) { month in
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        if month.id < hatched {
                            Hatch()
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .padding(.horizontal, 2)
                        }
                        VStack(spacing: 3) {
                            if month.total > 0 {
                                Text(verbatim: "\(month.total)")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(palette.ink)
                            }
                            VStack(spacing: 2) {
                                ForEach(month.entries) { entry in
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .fill(entry.germ.deepTint)
                                        .frame(width: 15, height: CGFloat(entry.count) / scale * 104)
                                }
                            }
                        }
                        Rectangle()
                            .fill(palette.ink.opacity(0.1))
                            .frame(height: 1)
                    }
                    .frame(height: 130, alignment: .bottom)
                    MonthLetter(month: month)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Germs by month"))
    }
}

/// A month's initial, in the accent while it is the current one.
private struct MonthLetter: View {
    let month: MonthBucket
    @Environment(\.palette) private var palette

    var body: some View {
        Text(month.label)
            .font(.caption.weight(month.isCurrent ? .bold : .regular))
            .foregroundStyle(month.isCurrent ? palette.accent : palette.inkTertiary)
    }
}

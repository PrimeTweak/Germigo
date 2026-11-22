import Charts
import SwiftUI

/// The daycare year in numbers, opened from Trophies.
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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(rangeLabel(season))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
                wrappedBanner(season)
                if seasonsBack == 0 {
                    monthRecapRow
                }
                tiles(stats)
                duelCard(season)
                if let supplier = stats.topSupplier {
                    supplierCard(supplier)
                }
                chartCard(stats, season: season)
                if let chain = stats.longestChain {
                    chainCard(chain)
                }
            }
            .padding(.horizontal, 20)
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
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showWrapped = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(tr("Season recap"))
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

    /// Last month's card, once there is something to tell.
    @ViewBuilder
    private var monthRecapRow: some View {
        let recap = model.lastMonthRecap()
        if !recap.isEmpty {
            Button {
                showMonth = true
            } label: {
                ValueRow(title: tr("Your %@ recap", recap.monthName))
                    .padding(.horizontal, 16)
                    .germigoCard(padding: 0)
            }
            .buttonStyle(.plain)
        }
    }

    /// Nothing to wrap before the first germ; the full story is announced on the reveal date.
    @ViewBuilder
    private func wrappedBanner(_ season: Season) -> some View {
        if model.data.logs.contains(where: { season.contains($0.startedAt) }) {
            let revealed = Date() >= WrapEngine.revealDate(for: season)
            Button {
                showWrapped = true
            } label: {
                HStack(spacing: 13) {
                    IconTile(symbol: "sparkles", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(revealed ? tr("Season %lld recap", season.number) : tr("Your season so far"))
                            .font(.headline)
                            .foregroundStyle(palette.ink)
                        Text(tr("Your season in story cards, ready to share."))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(palette.inkTertiary)
                }
                .germigoCard()
            }
            .buttonStyle(.plain)
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
                .germigoCard()
            }
        } else {
            Button {
                showPartner = true
            } label: {
                HStack(spacing: 12) {
                    BuddyView(look: model.data.partnerLook, size: 40)
                    Text(tr("Add your partner to start the couple duel."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.inkTertiary)
                }
                .germigoCard()
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
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func rangeLabel(_ season: Season) -> String {
        let lastDay = season.end.addingTimeInterval(-86_400)
        let style = Date.FormatStyle().month(.abbreviated).year()
        guard season.contains(Date()) else {
            return tr("%1$@ to %2$@", season.start.formatted(style), lastDay.formatted(style))
        }
        return tr("%1$@ to %2$@ · Week %3$lld", season.start.formatted(style), lastDay.formatted(style),
                  season.week(for: Date()))
    }

    private func monthName(_ offset: Int, season: Season) -> String {
        let date = Calendar.current.date(byAdding: .month, value: offset, to: season.start) ?? season.start
        return date.formatted(.dateTime.month(.wide)).localizedCapitalized
    }

    private func tiles(_ stats: SeasonStats) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        return LazyVGrid(columns: columns, spacing: 10) {
            tile(String(stats.germsCaught), tr("germs caught"))
            tile(String(stats.daysSick), tr("days sick"))
            tile(String(stats.dodged), tr("germs dodged"))
        }
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .germigoCard(radius: 24, padding: 14)
        .accessibilityElement(children: .combine)
    }

    private func supplierCard(_ supplier: SupplierStat) -> some View {
        HStack(spacing: 13) {
            ZStack(alignment: .bottomTrailing) {
                BuddyBadge(look: supplier.kid.colorIndex, size: 52, lively: true)
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
        .germigoCard()
    }

    private func chartCard(_ stats: SeasonStats, season: Season) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Germs by month"), trailing: tr("This season"))
            VStack(alignment: .leading, spacing: 12) {
                Text(chartCaption(stats, season: season))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Chart {
                    ForEach(stats.months) { bucket in
                        ForEach(bucket.entries) { entry in
                            BarMark(x: .value("Month", Double(bucket.id)),
                                    y: .value("Germs", entry.count),
                                    width: .fixed(15))
                                .foregroundStyle(entry.germ.deepTint)
                                .cornerRadius(4)
                        }
                    }
                }
                .chartXScale(domain: -0.6...11.6)
                .chartYScale(domain: 0...max(3, stats.months.map { $0.total }.max() ?? 0))
                .chartXAxis {
                    AxisMarks(values: stats.months.map { Double($0.id) }) { value in
                        AxisValueLabel {
                            if let raw = value.as(Double.self), Int(raw) >= 0, Int(raw) < stats.months.count {
                                Text(stats.months[Int(raw)].label)
                                    .fontWeight(stats.months[Int(raw)].isCurrent ? .bold : .regular)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3))
                }
                .frame(height: 150)
                .accessibilityLabel(tr("Germs by month"))
            }
            .germigoCard()
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
            .germigoCard()
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

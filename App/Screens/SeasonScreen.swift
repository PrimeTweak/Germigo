import Charts
import SwiftUI

/// The daycare year in numbers.
struct SeasonScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showWrapped = false
    @State private var showDuel = false

    /// Zero is the current season; each step goes one daycare year back.
    @State private var seasonsBack = 0

    var body: some View {
        let seasonCount = model.season.number
        let season = model.season(back: min(seasonsBack, seasonCount - 1))
        let stats = model.seasonStats(for: season)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(rangeLabel(season))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                    wrappedBanner(season)
                    tiles(stats)
                    duelCard(season)
                    if let supplier = stats.topSupplier {
                        supplierCard(supplier)
                    }
                    chartCard(stats, season: season)
                    if let chain = stats.longestChain {
                        chainCard(chain)
                    }
                    NavigationLink {
                        LogbookScreen()
                    } label: {
                        ValueRow(symbol: "list.bullet", tint: palette.sky, title: tr("Logbook"),
                                 value: String(model.data.logs.count))
                            .padding(.horizontal, 16)
                            .petriCard(padding: 0)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("Season %lld", season.number))
            .toolbar {
                if seasonCount > 1 {
                    ToolbarItem(placement: .topBarLeading) {
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
                    .accessibilityLabel(tr("Season wrapped"))
                }
            }
            .fullScreenCover(isPresented: $showWrapped) {
                WrappedScreen(season: season)
            }
            .sheet(isPresented: $showDuel) {
                SharePreviewSheet(title: tr("Couple duel")) {
                    DuelShareCard(seasonNumber: season.number, me: model.displayName, partner: model.partnerDisplayName,
                                  stats: DuelEngine.stats(data: model.data, season: season, now: Date()))
                }
            }
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
                    IconTile(symbol: "sparkles", background: palette.night, foreground: palette.lime, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(revealed ? tr("Season %lld, wrapped", season.number) : tr("Your season so far"))
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
                .petriCard()
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
                                 gradient: AvatarColors.you)
                        duelSide(name: model.partnerDisplayName, side: duel.partner, leads: duel.leader == .partner,
                                 gradient: AvatarColors.gradient(1))
                    }
                    Button {
                        showDuel = true
                    } label: {
                        Label(tr("Share the scoreboard"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost, height: 44))
                }
                .petriCard()
            }
        } else {
            HStack(spacing: 12) {
                IconTile(symbol: "person.2.fill", background: Color(hex: Swatch.pink), size: 36)
                Text(tr("Add your partner in Settings, under Family, to start the couple duel."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .petriCard()
        }
    }

    private func duelVerdict(_ duel: DuelStats) -> String {
        if duel.leader == .me { return tr("%@ leads", model.displayName) }
        if duel.leader == .partner { return tr("%@ leads", model.partnerDisplayName) }
        return tr("Tied")
    }

    private func duelSide(name: String, side: DuelSide, leads: Bool, gradient: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AvatarView(name: name, gradient: gradient, size: 32)
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                if leads {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(palette.crown)
                        .accessibilityLabel(tr("Leads"))
                }
            }
            Text(tr("%lld pts", side.points))
                .font(.title3.weight(.heavy).monospacedDigit())
                .foregroundStyle(palette.ink)
            Text(tr("%1$lld germs · %2$lld days", side.germs, side.daysSick))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(leads ? palette.lime.opacity(0.22) : palette.surfaceAlt.opacity(0.6),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        let level = model.level
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
        return LazyVGrid(columns: columns, spacing: 10) {
            tile(String(stats.germsCaught), tr("germs caught"), tint: palette.coral)
            tile(String(stats.daysSick), tr("days sick"), tint: palette.lilac)
            tile(String(stats.dodged), tr("germs dodged"), tint: palette.sky)
            tile(tr("Lv %lld", level.number), model.displayTitle, tint: palette.limeDeep)
        }
    }

    private func tile(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .petriCard(radius: 22, padding: 14)
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(tint)
                .frame(width: 10, height: 10)
                .padding(14)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private func supplierCard(_ supplier: SupplierStat) -> some View {
        HStack(spacing: 13) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: supplier.kid.name, gradient: AvatarColors.gradient(supplier.kid.colorIndex), size: 52)
                Image(systemName: "trophy.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(hex: Swatch.night))
                    .frame(width: 24, height: 24)
                    .background(palette.hazard, in: Circle())
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
        .petriCard()
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
            .petriCard()
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
                chainLink(name: chain.kid.name, gradient: AvatarColors.gradient(chain.kid.colorIndex), germ: chain.germ)
                if chain.sufferer.includesMe {
                    arrow
                    chainLink(name: model.displayName, gradient: AvatarColors.you, germ: chain.germ)
                }
                if chain.includesPartner {
                    arrow
                    chainLink(name: model.data.partnerName ?? tr("Partner"), gradient: AvatarColors.gradient(4),
                              germ: chain.germ)
                }
                Spacer(minLength: 0)
            }
            .petriCard()
        }
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(palette.inkTertiary)
            .accessibilityHidden(true)
    }

    private func chainLink(name: String, gradient: LinearGradient, germ: Germ) -> some View {
        VStack(spacing: 5) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(name: name, gradient: gradient, size: 46)
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

/// Every logged germ, editable.
struct LogbookScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var editing: SickLog?
    @State private var pendingDelete: SickLog?

    private var logs: [SickLog] {
        model.data.logs.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        List {
            if logs.isEmpty {
                Text(tr("No germs logged yet. It won't last."))
                    .foregroundStyle(palette.inkSecondary)
            }
            ForEach(logs) { log in
                Button {
                    editing = log
                } label: {
                    row(log)
                }
                .swipeActions(edge: .trailing) {
                    Button {
                        pendingDelete = log
                    } label: {
                        Label(tr("Delete"), systemImage: "trash")
                    }
                    .tint(Color.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
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
                GermImage(germ: germ, size: 38)
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
                PillLabel(text: tr("Now"), foreground: palette.night, background: palette.coralDeep)
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
            .tint(.green)
            .navigationTitle(tr("Edit log"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Cancel")) {
                        dismiss()
                    }
                    .tint(palette.ink)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Save")) {
                        var updated = draft
                        updated.endedAt = recovered || !canStayOpen ? max(endDate, draft.startedAt) : nil
                        model.updateLog(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(palette.ink)
                }
            }
        }
    }
}

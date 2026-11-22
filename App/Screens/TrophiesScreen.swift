import SwiftUI

/// The parent's game: the player card with the next goal, the family league, the season and the trophy shelf.
struct TrophiesScreen: View {
    /// One place on the shelf: a germ, and how many times it was caught.
    private struct ShelfItem: Identifiable {
        let germ: Germ
        let count: Int

        var id: String { germ.id }
    }

    /// The badge closest to being earned, and how far along it is.
    private struct NextBadge {
        let badge: Badge
        let count: BadgeCount
    }

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showPartner = false
    @State private var showPaywall = false
    @State private var appeared = false
    @State private var showWrapped = false
    @State private var showLeagueShare = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    playerCard
                    leagueCard
                    seasonCard
                    shelfCard
                    links
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 28)
            }
            .background(CharacterWash(tint: TabWash.trophies))
            .navigationTitle(tr("Trophies"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsButton()
                }
            }
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
            }
            .onAppear {
                appeared = true
            }
            .fullScreenCover(isPresented: $showWrapped) {
                WrappedScreen(season: model.season)
            }
            .sheet(isPresented: $showPartner) {
                PartnerEditSheet()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: .stats)
            }
        }
    }

    // MARK: - Player card

    private var playerCard: some View {
        let level = model.level
        let goal = GoalEngine.next(data: model.data, catalog: model.catalog, now: Date())
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    ProgressRing(fraction: level.fraction, lineWidth: 6)
                    BuddyView(look: model.data.hostLook, sick: model.onSickLeave, size: 58, leads: true, pokes: true)
                }
                .frame(width: 92, height: 92)
                .overlay(alignment: .bottomTrailing) {
                    Text(verbatim: String(level.number))
                        .font(.callout.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(palette.background)
                        .frame(minWidth: 32, minHeight: 32)
                        .background(palette.ink, in: Circle())
                        .offset(x: 4, y: 2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    Text(model.displayTitle)
                        .font(.callout)
                        .foregroundStyle(palette.inkSecondary)
                    if level.span > 0 {
                        ThinGauge(fraction: level.fraction, fill: palette.accent)
                            .padding(.top, 8)
                        Text(tr("%1$lld of %2$lld points to level %3$lld", level.progress, level.span, level.number + 1))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                            .padding(.top, 4)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.displayName + ". " + tr("%1$@, level %2$lld", model.displayTitle, level.number))
            if let goal {
                Rectangle()
                    .fill(palette.ink.opacity(0.1))
                    .frame(height: 1)
                    .padding(.vertical, 12)
                NavigationLink {
                    SkillTreeScreen()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "target")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(palette.accent)
                            .symbolEffect(.bounce, value: appeared)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(tr("Next up"))
                                .font(.caption)
                                .foregroundStyle(palette.inkSecondary)
                            Text(goal.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(palette.ink)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 8)
                        Text(tr("%1$lld of %2$lld", goal.progress, goal.target))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(palette.inkSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [Buddy.tint(model.data.hostLook).opacity(palette.isDark ? 0.3 : 0.55), palette.surface],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    // MARK: - Season

    private var seasonCard: some View {
        Group {
            if model.hasPass {
                NavigationLink {
                    SeasonScreen()
                } label: {
                    seasonContent
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    seasonContent
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var seasonContent: some View {
        let season = model.season
        let now = Date()
        let stats = model.seasonStats(for: season, now: now)
        let weeks = StatsEngine.sickWeekGerms(data: model.data, season: season, now: now)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(tr("Season %lld", season.number))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.ink)
                Spacer(minLength: 8)
                Text(tr("Week %lld", season.week(for: now)))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                if model.hasPass {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.inkTertiary)
                        .accessibilityHidden(true)
                } else {
                    PassOfferTag()
                }
            }
            HStack(alignment: .top, spacing: 8) {
                SeasonFigure(value: stats.germsCaught, label: tr("germs caught"))
                SeasonFigure(value: stats.daysSick, label: tr("days sick"))
                SeasonFigure(value: stats.dodged, label: tr("germs dodged"))
            }
            .padding(.top, 10)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 12), spacing: 5) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { item in
                    SeasonWeekCell(germ: item.element.flatMap { model.catalog.germ($0) }, isNow: item.offset == weeks.count - 1)
                        .cascadeIn(item.offset / 4)
                }
            }
            .padding(.top, 12)
            .accessibilityHidden(true)
            Text(seasonLine(weeks, season: season))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.leading)
                .padding(.top, 10)
        }
        .germilyCard()
    }

    private func seasonLine(_ weeks: [String?], season: Season) -> String {
        if let nemesis = StatsEngine.nemesis(data: model.data, season: season), let germ = model.catalog.germ(nemesis.germID) {
            return tr("%1$@ is your nemesis: %2$lld times already.", germ.name, nemesis.count)
        }
        let sick = weeks.compactMap { $0 }.count
        return sick == 0 ? tr("Not one sick week so far.") : tr("Sick %1$lld weeks out of %2$lld.", sick, weeks.count)
    }

    // MARK: - Shelf

    /// The germs caught last, one each, then gray shapes still to find.
    private var shelfItems: [ShelfItem] {
        var seen = Set<String>()
        var items: [ShelfItem] = []
        for log in model.data.logs.sorted(by: { $0.startedAt > $1.startedAt }) where seen.insert(log.germID).inserted {
            if let germ = model.catalog.germ(log.germID) {
                items.append(ShelfItem(germ: germ, count: model.count(of: germ.id)))
            }
        }
        for germ in model.catalog.germs where !seen.contains(germ.id) && germ.id != GermCatalog.mysteryID {
            items.append(ShelfItem(germ: germ, count: 0))
        }
        return Array(items.prefix(5))
    }

    private var nextBadge: NextBadge? {
        let counts = BadgeProgress.counts(data: model.data, catalog: model.catalog, now: Date())
        return BadgeCatalog.all.compactMap { badge -> NextBadge? in
            guard !model.hasBadge(badge.id), let count = counts[badge.id], count.target > 0,
                  count.progress < count.target else { return nil }
            return NextBadge(badge: badge, count: count)
        }
        .max { $0.count.fraction < $1.count.fraction }
    }

    private var shelfCard: some View {
        let items = shelfItems
        let all = BadgeCatalog.all
        let earned = all.filter { model.hasBadge($0.id) }
        let next = nextBadge
        let locked = all.filter { !model.hasBadge($0.id) && $0.id != next?.badge.id }
        let medals = Array((earned + (next.map { [$0.badge] } ?? []) + locked).prefix(5))
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: tr("Germs caught"),
                          trailing: tr("%1$lld of %2$lld", model.caughtGermIDs.count, model.catalog.germs.count))
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.element.id) { item in
                    slot(item.element, index: item.offset)
                }
            }
            .padding(.top, 10)
            if model.caughtGermIDs.isEmpty {
                Text(tr("An empty shelf. Enjoy it while it lasts."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.top, 8)
            }
            NavigationLink {
                BadgesScreen()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: tr("Badges"), trailing: tr("%1$lld of %2$lld", earned.count, all.count))
                    HStack(spacing: 8) {
                        ForEach(Array(medals.enumerated()), id: \.element.id) { item in
                            BadgeMedal(badge: item.element, won: model.hasBadge(item.element.id),
                                       progress: item.element.id == next?.badge.id ? next?.count.fraction : nil,
                                       bounce: appeared)
                                .cascadeIn(item.offset)
                        }
                    }
                    if let next {
                        Text(tr("Next: %1$@, %2$lld of %3$lld.", next.badge.title, next.count.progress, next.count.target))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
        .germilyCard()
    }

    private func slot(_ item: ShelfItem, index: Int) -> some View {
        NavigationLink(value: item.germ) {
            ShelfTile(germ: item.germ, count: item.count, phase: Double(index) * 0.8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.germ.name)
        .accessibilityValue(item.count > 0 ? tr("Caught") : tr("Not caught yet"))
        .cascadeIn(index)
    }

    // MARK: - Family league

    @ViewBuilder
    private var leagueCard: some View {
        let entries = LeagueEngine.standings(data: model.data, catalog: model.catalog, season: model.season, now: Date())
        if !model.hasPass {
            lockedLeague
        } else if entries.count > 1 {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: tr("Family league"), trailing: tr("Season %lld", model.season.number))
                Podium(places: places(entries, you: tr("You")))
                    .padding(.top, 14)
                if entries.allSatisfy({ $0.title == nil }) {
                    Text(tr("Nobody stands out yet this season."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.top, 10)
                }
                ShareCapsule(title: tr("Share the standings")) {
                    showLeagueShare = true
                }
                .padding(.top, 14)
            }
            .germilyCard()
            .sheet(isPresented: $showLeagueShare) {
                SharePreviewSheet(title: tr("Family league")) {
                    FamilyLeagueShareCard(seasonNumber: model.season.number, places: places(entries, you: model.displayName))
                }
            }
        } else {
            Button {
                showPartner = true
            } label: {
                HStack(spacing: 14) {
                    BuddyView(look: model.data.partnerLook, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Family league"))
                            .font(.body.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Text(tr("Add your partner"))
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                    }
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

    /// The league without the pass: the household's characters and the way to the pass.
    private var lockedLeague: some View {
        let looks = [model.data.hostLook, model.data.partnerLook] + model.data.kids.prefix(1).map { $0.colorIndex }
        return Button {
            showPaywall = true
        } label: {
            HStack(spacing: 14) {
                HStack(spacing: -14) {
                    ForEach(Array(looks.enumerated()), id: \.offset) { item in
                        BuddyView(look: item.element, size: 46)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Family league"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Text(tr("Podium, titles and the couple duel"))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                }
                Spacer(minLength: 8)
                PassOfferTag()
            }
            .germilyCard(padding: 14)
        }
        .buttonStyle(.plain)
    }

    private func places(_ entries: [LeagueEntry], you: String) -> [PodiumPlace] {
        entries.map { entry in
            let ahead = entries.filter { ($0.sickDays, $0.germs) < (entry.sickDays, entry.germs) }.count
            return PodiumPlace(id: placeID(entry.person), look: model.look(of: entry.person),
                               name: entry.person == .me ? you : model.name(for: entry.person), title: entry.title?.text,
                               detail: trCount(entry.sickDays, one: "%lld sick day", other: "%lld sick days"),
                               rank: ahead + 1)
        }
    }

    private func placeID(_ person: Person) -> String {
        switch person {
        case .me: return "me"
        case .partner: return "partner"
        case .kid(let kidID): return kidID.uuidString
        }
    }

    // MARK: - Links

    private var links: some View {
        let reveal = WrapEngine.revealDate(for: model.season)
        let weeksLeft = Int((reveal.timeIntervalSinceNow / (7 * 24 * 3600)).rounded(.up))
        return VStack(spacing: 0) {
            NavigationLink {
                SkillTreeScreen()
            } label: {
                row("tree.fill", tr("Skill tree"), model.displayTitle)
            }
            .buttonStyle(.plain)
            Divider()
                .padding(.leading, 36)
            Button {
                showWrapped = true
            } label: {
                row("sparkles", tr("Season story"),
                    weeksLeft > 0 ? trCount(weeksLeft, one: "In %lld week", other: "In %lld weeks") : tr("Ready"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .germilyCard(padding: 0)
    }

    private func row(_ symbol: String, _ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.inkSecondary)
                .frame(width: 26)
            ValueRow(title: title, value: value)
        }
    }
}

/// A big season number over its label, following the text size set in iOS.
struct SeasonFigure: View {
    let value: Int
    let label: String
    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .title) private var size: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RollingNumber(value: value)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(palette.ink)
            Text(label)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// A week of the season: its germ's face when one was going on, the current week outlined.
struct SeasonWeekCell: View {
    let germ: Germ?
    let isNow: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
            .fill(germ.map { $0.tileTint(palette) } ?? palette.ink.opacity(0.1))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let germ {
                    GeometryReader { proxy in
                        GermImage(germ: germ, size: proxy.size.width * 0.8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .overlay {
                if isNow {
                    RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                        .strokeBorder(palette.accent, lineWidth: 2)
                }
            }
    }
}

/// A germ on the shelf: its face on its tint once caught, a silhouette before, the count past one.
struct ShelfTile: View {
    let germ: Germ
    let count: Int
    var phase: Double = 0
    @Environment(\.palette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
            .fill(count > 0 ? germ.tileTint(palette) : palette.background)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    Group {
                        if count > 0 {
                            LivelyCharacter(mood: .stalking, phase: phase, touch: nil) {
                                GermImage(germ: germ, size: proxy.size.width * 0.76)
                            }
                        } else {
                            GermImage(germ: germ, size: proxy.size.width * 0.76, silhouette: true)
                                .foregroundStyle(palette.ink.opacity(palette.isDark ? 0.2 : 0.13))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .overlay(alignment: .topTrailing) {
                if count > 1 {
                    Text(verbatim: "×\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.background)
                        .padding(.horizontal, 7)
                        .frame(height: 22)
                        .background(palette.ink, in: Capsule())
                        .offset(x: 4, y: -5)
                }
            }
    }
}

/// A badge: filled once earned, ringed by its progress when it is the next one, faint otherwise.
struct BadgeMedal: View {
    let badge: Badge
    let won: Bool
    var progress: Double?
    /// Bounces an earned badge when it turns true.
    var bounce = false
    @Environment(\.palette) private var palette

    var body: some View {
        Circle()
            .fill(won ? palette.accent : palette.background)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let progress {
                    ProgressRing(fraction: progress, lineWidth: 4)
                }
            }
            .overlay {
                Image(systemName: badge.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(won ? palette.onAccent : (progress != nil ? palette.accent : palette.ink.opacity(0.5)))
                    .symbolEffect(.bounce, value: won && bounce)
            }
            .accessibilityLabel(badge.title)
    }
}

import SwiftUI

/// The parent's game: the player card with the next title or badge, the family league, the season,
/// titles and badges, and the way to the microbe cards. The run without a germ stays on Today.
struct TrophiesScreen: View {
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
    @State private var showQuiz = false
    @State private var showRewards = false

    var body: some View {
        let earned = BadgeCatalog.all.filter { model.hasBadge($0.id) }
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    playerCard(showsGoal: !earned.isEmpty)
                    leagueCard
                    if earned.isEmpty {
                        starterCard
                    }
                    seasonCard
                    if !earned.isEmpty {
                        titlesCard(earned: earned)
                    }
                    tricksRow
                    if !model.caughtGermIDs.isEmpty {
                        mugshotsRow
                    }
                    storyRow
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
            .navigationDestination(for: Article.self) { article in
                ArticleScreen(article: article)
            }
            .onAppear {
                appeared = true
            }
            .fullScreenCover(isPresented: $showWrapped) {
                WrappedScreen(season: model.season)
            }
            .fullScreenCover(isPresented: $showQuiz) {
                QuizScreen()
            }
            .sheet(isPresented: $showPartner) {
                PartnerEditSheet()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: .stats)
            }
            .sheet(isPresented: $showRewards) {
                LevelRewardsSheet()
            }
        }
    }

    // MARK: - Player card

    /// The goal row waits while the empty trophy case lists the first badges, so the quiz is not asked for twice.
    private func playerCard(showsGoal: Bool) -> some View {
        let level = model.level
        let goal = showsGoal ? GoalEngine.next(data: model.data, catalog: model.catalog, now: Date()) : nil
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
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.accent)
                    if level.span > 0 {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                ThinGauge(fraction: level.fraction, fill: palette.accent)
                                Text(tr("%1$lld of %2$lld points to level %3$lld", level.progress, level.span, level.number + 1))
                                    .font(.footnote)
                                    .foregroundStyle(palette.inkSecondary)
                            }
                            if let next = LevelRewards.asset(level.number + 1) {
                                Button {
                                    showRewards = true
                                } label: {
                                    Image(next)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 34, height: 34)
                                        .padding(5)
                                        .background(palette.surface.opacity(0.85),
                                                    in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.displayName + ". " + tr("%1$@, level %2$lld", model.displayTitle, level.number))
            .accessibilityAction(named: tr("Level rewards")) {
                showRewards = true
            }
            if let goal {
                Rectangle()
                    .fill(palette.ink.opacity(0.1))
                    .frame(height: 1)
                    .padding(.vertical, 12)
                NavigationLink {
                    TitlesScreen()
                } label: {
                    nextUp(goal)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [Buddy.tint(model.data.hostLook).opacity(palette.isDark ? 0.3 : 0.55), palette.surface],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    /// The next title or badge: its symbol ringed by how far along it is, what it asks for, and the count.
    private func nextUp(_ goal: Goal) -> some View {
        let tint = Color(hex: goal.tint)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(palette.isDark ? 0.24 : 0.18))
                ProgressRing(fraction: goal.fraction, lineWidth: 3, tint: tint)
                Image(systemName: goal.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(palette.isDark ? tint : tint.mix(with: Color(hex: Swatch.ink), by: 0.35))
                    .symbolEffect(.bounce, value: appeared)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 0) {
                Text(tr("Next up"))
                    .font(.caption)
                    .foregroundStyle(palette.inkSecondary)
                Text(goal.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(goal.detail)
                    .font(.caption)
                    .foregroundStyle(palette.inkSecondary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Text(tr("%1$lld of %2$lld", goal.progress, goal.target))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(palette.accent)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - Family league

    @ViewBuilder
    private var leagueCard: some View {
        let entries = LeagueEngine.standings(data: model.data, catalog: model.catalog, season: model.season, now: Date())
        if !model.hasPass {
            lockedLeague
        } else if entries.count > 1, entries.allSatisfy({ $0.sickDays == 0 }) {
            leagueRow(looks: entries.map { model.look(of: $0.person) },
                      line: tr("Tied at zero. The podium opens with the first germ.")) {
                EmptyView()
            }
        } else if entries.count > 1 {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: tr("Family league"), trailing: tr("Season %lld", model.season.number))
                Podium(places: places(entries, you: tr("You")))
                    .padding(.top, 14)
                if entries.allSatisfy({ $0.title == nil }) {
                    leagueLine(tr("Nobody stands out yet this season."))
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

    private func leagueLine(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(palette.inkSecondary)
            .padding(.top, 10)
    }

    /// The league without the pass: the household's characters and the way to the pass.
    private var lockedLeague: some View {
        let partner: [Int] = model.data.partnerName == nil ? [] : [model.data.partnerLook]
        let looks = [model.data.hostLook] + partner + model.data.kids.prefix(1).map { $0.colorIndex }
        return Button {
            showPaywall = true
        } label: {
            leagueRow(looks: looks, line: tr("Podium, titles and the couple duel")) {
                PassOfferTag()
            }
        }
        .buttonStyle(.plain)
    }

    /// The league on one row: the household's characters overlapping, the title, one line and what trails.
    private func leagueRow<Trailing: View>(looks: [Int], line: String, @ViewBuilder trailing: () -> Trailing) -> some View {
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
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .germilyCard(padding: 14)
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

    // MARK: - First badges

    /// Before any badge: the mascot, and the three easiest badges with what earns them.
    private var starterCard: some View {
        let counts = BadgeProgress.counts(data: model.data, catalog: model.catalog, now: Date())
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image("mascot-giggle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-6))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Empty trophy case."))
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(tr("Best possible news. Here's where the first ones come from."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 4)
            if let badge = BadgeCatalog.badge(BadgeCatalog.labRat) {
                starter(badge, title: tr("Finish today's quiz"), line: tr("Earns %@", badge.title)) {
                    showQuiz = true
                }
            }
            if let badge = BadgeCatalog.badge(BadgeCatalog.professor), let count = counts[badge.id] {
                NavigationLink {
                    LessonsScreen()
                } label: {
                    starterRow(badge, title: tr("Read a lesson in the Guide"),
                               line: tr("%1$@, %2$lld of %3$lld", badge.title, count.progress, count.target))
                }
                .buttonStyle(.plain)
            }
            if let badge = BadgeCatalog.badge(BadgeCatalog.patientOne) {
                starter(badge, title: tr("Log a germ when one hits"), line: tr("Earns %@", badge.title)) {
                    model.logRequest = LogRequest()
                }
            }
        }
        .germilyCard()
    }

    private func starter(_ badge: Badge, title: String, line: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            starterRow(badge, title: title, line: line)
        }
        .buttonStyle(.plain)
    }

    private func starterRow(_ badge: Badge, title: String, line: String) -> some View {
        HStack(spacing: 12) {
            BadgeMedal(badge: badge, won: false)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(line)
                    .font(.caption)
                    .foregroundStyle(palette.inkSecondary)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            RowChevron()
        }
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.ink.opacity(0.08))
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
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
                Text(tr("Week %lld for you", weeks.count))
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
            if !StatsEngine.isUntouched(data: model.data, season: season) {
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
            }
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
        if sick > 0 { return tr("Sick %1$lld weeks out of %2$lld.", sick, weeks.count) }
        return weeks.count == 1 ? tr("Every clean week gets its soap.") : tr("Not one sick week so far.")
    }

    // MARK: - Titles and badges

    private var nextBadge: NextBadge? {
        let counts = BadgeProgress.counts(data: model.data, catalog: model.catalog, now: Date())
        return BadgeCatalog.all.compactMap { badge -> NextBadge? in
            guard !badge.secret, !model.hasBadge(badge.id), let count = counts[badge.id], count.target > 0,
                  count.progress < count.target else { return nil }
            return NextBadge(badge: badge, count: count)
        }
        .max { $0.count.fraction < $1.count.fraction }
    }

    /// The title worn and how far the next one on its branch is, then the badges: earned, the next one, the rest.
    private func titlesCard(earned: [Badge]) -> some View {
        let all = BadgeCatalog.all
        let next = nextBadge
        let locked = all.filter { !model.hasBadge($0.id) && $0.id != next?.badge.id }
        let medals = Array((earned + (next.map { [$0.badge] } ?? []) + locked).prefix(5))
        let nodes = SkillTree.nodes(data: model.data, catalog: model.catalog)
        let total = nodes.filter { $0.isUnlocked }.count + earned.count
        return NavigationLink {
            TitlesScreen()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tr("Titles and badges"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.ink)
                    Spacer(minLength: 8)
                    Text(tr("%1$lld of %2$lld", total, nodes.count + all.count))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.inkTertiary)
                        .accessibilityHidden(true)
                }
                if let worn = nodes.first(where: { $0.id == model.data.settings.wornTitle && $0.isUnlocked }) {
                    wornRow(worn, nodes: nodes)
                }
                HStack(spacing: 8) {
                    ForEach(Array(medals.enumerated()), id: \.element.id) { item in
                        BadgeMedal(badge: item.element.shown(earned: model.hasBadge(item.element.id)),
                                   won: model.hasBadge(item.element.id),
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
            .germilyCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func wornRow(_ worn: SkillNode, nodes: [SkillNode]) -> some View {
        let tint = Color(hex: worn.branch?.tint ?? Swatch.gold)
        let following = nodes.first { $0.branch != nil && $0.branch == worn.branch && $0.rank == worn.rank + 1 }
        return HStack(spacing: 10) {
            HexNode(symbol: worn.branch?.symbol ?? "crown.fill", tint: tint, stage: .won, size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(tr("Wearing"))
                    .font(.caption)
                    .foregroundStyle(palette.inkSecondary)
                Text(worn.title)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(palette.ink)
            }
            Spacer(minLength: 8)
            if let following, !following.isUnlocked {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(tr("Next title"))
                        .font(.caption)
                    Text(tr("%1$lld of %2$lld", following.progress, following.target))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(palette.inkSecondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(palette.isDark ? 0.18 : 0.16), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Tricks, microbe cards and the season story

    /// The napping germ's tricks found so far, and the way to the notebook of all ten.
    private var tricksRow: some View {
        let found = MascotTrick.allCases.filter { model.data.mascotTricks.contains($0.rawValue) }
        return NavigationLink {
            TricksScreen()
        } label: {
            HStack(spacing: 14) {
                HStack(spacing: -12) {
                    ForEach(found.suffix(3), id: \.self) { trick in
                        Image(trick.face)
                            .resizable()
                            .scaledToFit()
                            .padding(4)
                            .frame(width: 44, height: 44)
                            .background(palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(palette.surface, lineWidth: 2.5)
                            }
                    }
                    if found.count < MascotTrick.allCases.count {
                        Text(verbatim: "?")
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(palette.inkTertiary)
                            .frame(width: 44, height: 44)
                            .background(palette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(palette.surface, lineWidth: 2.5)
                            }
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Napping germ's tricks"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Text(tr("%1$lld of %2$lld found", found.count, MascotTrick.allCases.count))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                    HStack(spacing: 4) {
                        ForEach(MascotTrick.allCases, id: \.self) { trick in
                            Capsule()
                                .fill(found.contains(trick) ? palette.accent : palette.ink.opacity(0.1))
                                .frame(width: 14, height: 5)
                        }
                    }
                    .padding(.top, 4)
                    .accessibilityHidden(true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                RowChevron()
            }
            .germilyCard(padding: 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    /// The last three germs caught, as their mugshots, and the way to the microbe cards in the Guide.
    private var mugshotsRow: some View {
        var seen = Set<String>()
        let recent = model.data.logs.sorted { $0.startedAt > $1.startedAt }
            .filter { seen.insert($0.germID).inserted }
            .prefix(3)
            .compactMap { model.catalog.germ($0.germID) }
        return Button {
            model.selectedTab = .lab
        } label: {
            HStack(spacing: 14) {
                HStack(spacing: -14) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { item in
                        Mugshot(germ: item.element, count: model.count(of: item.element.id))
                            .frame(width: 54)
                            .rotationEffect(.degrees(item.offset == 1 ? -5 : (item.offset == 2 ? 5 : 0)))
                            .shadow(color: Color.black.opacity(0.12), radius: 3, y: 2)
                    }
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Microbe cards"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Text(tr("%1$lld of %2$lld caught · in the Guide", model.caughtGermIDs.count, model.catalog.germs.count))
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
        .accessibilityElement(children: .combine)
    }

    private var storyRow: some View {
        let reveal = WrapEngine.revealDate(for: model.season)
        let weeksLeft = Int((reveal.timeIntervalSinceNow / (7 * 24 * 3600)).rounded(.up))
        return Button {
            showWrapped = true
        } label: {
            HStack(spacing: 10) {
                RecapCardsIcon()
                ValueRow(title: tr("Season story"),
                         value: weeksLeft > 0 ? trCount(weeksLeft, one: "In %lld week", other: "In %lld weeks") : tr("Ready"))
            }
            .padding(.horizontal, 16)
            .germilyCard(padding: 0)
        }
        .buttonStyle(.plain)
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

/// A week of the season: its germ's face when one was going on, soap bubbles when it stayed clean,
/// the current week outlined.
struct SeasonWeekCell: View {
    let germ: Germ?
    let isNow: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
            .fill(germ.map { $0.tileTint(palette) } ?? Color(hex: Swatch.green).opacity(palette.isDark ? 0.22 : 0.14))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    Group {
                        if let germ {
                            GermImage(germ: germ, size: proxy.size.width * 0.8)
                        } else {
                            Image(systemName: "bubbles.and.sparkles.fill")
                                .font(.system(size: proxy.size.width * 0.42, weight: .semibold))
                                .foregroundStyle(Color(hex: palette.isDark ? Swatch.green : Swatch.greenInk))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// A badge in its color: full once earned, ringed by its progress when it is on its way, pale otherwise.
struct BadgeMedal: View {
    let badge: Badge
    let won: Bool
    var progress: Double?
    /// Bounces an earned badge when it turns true.
    var bounce = false
    @Environment(\.palette) private var palette

    var body: some View {
        let tint = Color(hex: badge.tint)
        Circle()
            .fill(won ? AnyShapeStyle(RadialGradient(colors: [tint.mix(with: .white, by: 0.35), tint], center: UnitPoint(x: 0.35, y: 0.3),
                                                     startRadius: 0, endRadius: 44))
                      : AnyShapeStyle(tint.opacity(palette.isDark ? 0.22 : 0.14)))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let progress {
                    ProgressRing(fraction: progress, lineWidth: 3.5, tint: tint)
                } else if !won {
                    Circle()
                        .strokeBorder(tint.opacity(0.3), lineWidth: 1.5)
                }
            }
            .overlay {
                GeometryReader { proxy in
                    Image(systemName: badge.symbol)
                        .font(.system(size: proxy.size.width * 0.38, weight: .semibold))
                        .foregroundStyle(won ? Color.white : (palette.isDark ? tint : tint.mix(with: Color(hex: Swatch.ink), by: 0.4)))
                        .symbolEffect(.bounce, value: won && bounce)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .shadow(color: won ? tint.opacity(0.35) : Color.clear, radius: 4, y: 2)
            .accessibilityLabel(badge.title)
    }
}

/// Every level and the sticker it unlocks: the earned ones in color, the next two in gray, the rest a surprise.
private struct LevelRewardsSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let current = model.level.number
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(tr("Every level unlocks a sticker for the couch."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                    VStack(spacing: 0) {
                        ForEach(1...Levels.thresholds.count, id: \.self) { number in
                            row(number, current: current)
                            if number < Levels.thresholds.count {
                                Divider()
                                    .padding(.leading, 66)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .germilyCard(padding: 0)
                }
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 24)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("Level rewards"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(tr("Done"))
                    .tint(palette.ink)
                }
            }
        }
    }

    private func row(_ number: Int, current: Int) -> some View {
        let got = number <= current
        let shown = number <= current + 2
        let isNext = number == current + 1
        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                    .fill(got || isNext ? palette.accent.opacity(0.12) : palette.ink.opacity(0.05))
                if shown, let asset = LevelRewards.asset(number) {
                    Image(asset)
                        .resizable()
                        .scaledToFit()
                        .padding(7)
                        .saturation(got ? 1 : 0)
                        .opacity(got ? 1 : 0.4)
                } else {
                    Image(systemName: "questionmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.inkTertiary)
                }
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("Level %1$lld · %2$@", number, Levels.info(for: Levels.thresholds[number - 1]).title))
                    .font(.caption)
                    .foregroundStyle(palette.inkSecondary)
                Text(shown ? LevelRewards.name(number) : tr("Surprise"))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(shown ? palette.ink : palette.inkSecondary)
            }
            Spacer(minLength: 8)
            if got {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(palette.accent)
            } else {
                Text(tr("%lld pts", Levels.thresholds[number - 1]))
                    .font(.footnote.weight(isNext ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(isNext ? palette.accent : palette.inkTertiary)
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

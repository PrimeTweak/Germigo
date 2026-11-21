import SwiftUI

/// The parent's own page: a player card, the shelf of germs caught, the badges, the season and the duel.
struct YouScreen: View {
    /// One place on the shelf: a germ, and how many times it was caught.
    private struct ShelfItem: Identifiable {
        let germ: Germ
        let count: Int

        var id: String { germ.id }
    }

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var editingPartner = false
    @State private var nameDraft = ""
    @State private var appeared = false

    private var hasHistory: Bool {
        !model.data.logs.isEmpty || !model.data.kidIllnesses.isEmpty
    }

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    if hasHistory {
                        numbers
                            .padding(.top, 18)
                    }
                    if let goal = GoalEngine.next(data: model.data, catalog: model.catalog, now: Date()) {
                        quest(goal)
                            .padding(.top, 12)
                    }
                    shelf
                        .padding(.top, 14)
                    badges
                        .padding(.top, 10)
                    seasonCard
                        .padding(.top, 22)
                    duelCard
                        .padding(.top, 10)
                    doors
                        .padding(.top, 10)
                    if hasHistory {
                        doctorRow
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(CharacterWash(tint: Buddy.tint(model.data.hostLook), reach: 0.4))
            .navigationTitle(tr("You"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
            }
            .onAppear {
                appeared = true
            }
            .alert(tr("Partner"), isPresented: $editingPartner) {
                TextField(tr("Name"), text: $nameDraft)
                Button(tr("Save")) {
                    model.setPartnerName(nameDraft)
                }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(tr("Used for the couple duel, the nap coupon and Tag Team. Leave it empty to remove."))
            }
        }
    }

    // MARK: - Player card

    private var hero: some View {
        let level = model.level
        return VStack(spacing: 0) {
            ZStack {
                ProgressRing(fraction: level.fraction)
                BuddyView(look: model.data.hostLook, sick: model.onSickLeave, size: 88, lively: true, pokes: true)
            }
            .frame(width: 148, height: 148)
            .overlay(alignment: .bottomTrailing) {
                Text(verbatim: String(level.number))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(palette.background)
                    .frame(minWidth: 42, minHeight: 42)
                    .background(palette.ink, in: Circle())
                    .offset(y: -4)
            }
            Text(model.displayName)
                .font(.title.weight(.bold))
                .foregroundStyle(palette.ink)
                .padding(.top, 10)
            Text(model.displayTitle)
                .font(.callout)
                .foregroundStyle(palette.ink.opacity(0.82))
            if level.span > 0 {
                Text(tr("%1$lld of %2$lld points to level %3$lld", level.progress, level.span, level.number + 1))
                    .font(.footnote)
                    .foregroundStyle(palette.ink.opacity(0.72))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.displayName + ". " + tr("%1$@, level %2$lld", model.displayTitle, level.number))
    }

    private var numbers: some View {
        let logs = model.data.logs
        let daysSick = logs.reduce(0) { $0 + $1.dayCount() }
        let dodged = model.data.kidIllnesses.filter { $0.outcome == .dodged }.count
        return HStack(spacing: 8) {
            number(logs.count, tr("germs caught"))
            number(daysSick, tr("days sick"))
            number(dodged, tr("germs dodged"))
        }
    }

    private func number(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RollingNumber(value: value)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(palette.ink)
            Text(label)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .petriCard(radius: 22, padding: 12)
        .accessibilityElement(children: .combine)
    }

    private func quest(_ goal: Goal) -> some View {
        NavigationLink {
            SkillTreeScreen()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "target")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .symbolEffect(.bounce, value: appeared)
                    .frame(width: 46, height: 46)
                    .background(palette.background, in: Circle())
                VStack(alignment: .leading, spacing: 0) {
                    Text(tr("Next up"))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                    Text(goal.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.leading)
                    ThinGauge(fraction: goal.fraction, fill: palette.accent)
                        .padding(.top, 8)
                }
                Text(tr("%1$lld of %2$lld", goal.progress, goal.target))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(palette.inkSecondary)
            }
            .petriCard(radius: 26, padding: 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shelf and badges

    private var shelf: some View {
        let items = shelfItems
        let caught = model.caughtGermIDs.count
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: tr("Germs caught"), trailing: tr("%1$lld of %2$lld", caught, model.catalog.germs.count))
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.element.id) { item in
                    slot(item.element, index: item.offset)
                }
            }
            .padding(.top, 12)
            if caught == 0 {
                Text(tr("An empty shelf. Enjoy it while it lasts."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
                    .padding(.top, 10)
            }
        }
    }

    private func slot(_ item: ShelfItem, index: Int) -> some View {
        let caught = item.count > 0
        return NavigationLink(value: item.germ) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(caught ? item.germ.tileTint(palette) : palette.surface)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        Group {
                            if caught {
                                LivelyCharacter(mood: .stalking, phase: Double(index) * 0.8, pokes: false) {
                                    GermImage(germ: item.germ, size: proxy.size.width * 0.74)
                                }
                            } else {
                                GermImage(germ: item.germ, size: proxy.size.width * 0.74, silhouette: true)
                                    .foregroundStyle(palette.ink.opacity(palette.isDark ? 0.2 : 0.13))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if item.count > 1 {
                        Text(verbatim: "×\(item.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.background)
                            .padding(.horizontal, 7)
                            .frame(height: 22)
                            .background(palette.ink, in: Capsule())
                            .offset(x: 4, y: -5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.germ.name)
        .accessibilityValue(caught ? tr("Caught") : tr("Not caught yet"))
        .cascadeIn(index)
    }

    private var badges: some View {
        let all = BadgeCatalog.all
        let earned = all.filter { model.hasBadge($0.id) }
        let shown = Array((earned + all.filter { !model.hasBadge($0.id) }).prefix(5))
        return NavigationLink {
            BadgesScreen()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: tr("Badges"), trailing: tr("%1$lld of %2$lld", earned.count, all.count))
                HStack(spacing: 8) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { item in
                        medal(item.element, won: model.hasBadge(item.element.id))
                            .cascadeIn(item.offset)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func medal(_ badge: Badge, won: Bool) -> some View {
        Circle()
            .fill(won ? palette.ink : palette.surface)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: badge.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(won ? palette.background : palette.ink.opacity(0.3))
                    .symbolEffect(.bounce, value: won && appeared)
            }
            .accessibilityLabel(badge.title)
    }

    // MARK: - Season and duel

    private var seasonCard: some View {
        let season = model.season
        let weeks = StatsEngine.sickWeeks(data: model.data, season: season, now: Date())
        let sick = weeks.filter { $0 }.count
        return NavigationLink {
            SeasonScreen()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(tr("Season %lld", season.number))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(palette.ink)
                    Spacer(minLength: 8)
                    Text(tr("Week %lld", season.week(for: Date())))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.inkTertiary)
                        .accessibilityHidden(true)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 18), spacing: 5) {
                    ForEach(Array(weeks.enumerated()), id: \.offset) { item in
                        Circle()
                            .fill(item.element ? palette.ink : palette.ink.opacity(0.12))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if item.offset == weeks.count - 1 {
                                    Circle()
                                        .strokeBorder(palette.accent, lineWidth: 2)
                                        .padding(-3)
                                }
                            }
                            .cascadeIn(item.offset / 3)
                    }
                }
                .padding(.top, 14)
                .accessibilityHidden(true)
                Text(sick == 0 ? tr("Not one sick week so far.") : tr("Sick %1$lld weeks out of %2$lld.", sick, weeks.count))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.top, 10)
            }
            .petriCard(radius: 26, padding: 16)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var duelCard: some View {
        if let partner = model.data.partnerName {
            let stats = DuelEngine.stats(data: model.data, season: model.season, now: Date())
            NavigationLink {
                SeasonScreen()
            } label: {
                HStack(spacing: 10) {
                    duelSide(look: model.data.hostLook, name: tr("You"))
                    VStack(spacing: 0) {
                        Text(tr("Couple duel"))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                        Text(verbatim: "\(stats.me.germs) – \(stats.partner.germs)")
                            .font(.system(size: 32, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(palette.ink)
                        Text(duelLine(mine: stats.me.germs, theirs: stats.partner.germs, partner: partner))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    duelSide(look: model.data.partnerLook, name: partner)
                }
                .petriCard(radius: 26, padding: 14)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tr("Couple duel") + ". " + tr("You %1$lld, %2$@ %3$lld", stats.me.germs, partner, stats.partner.germs))
        } else {
            Button {
                nameDraft = ""
                editingPartner = true
            } label: {
                HStack(spacing: 14) {
                    BuddyView(look: model.data.partnerLook, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Couple duel"))
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
                .petriCard(radius: 26, padding: 14)
            }
            .buttonStyle(.plain)
        }
    }

    private func duelSide(look: Int, name: String) -> some View {
        VStack(spacing: 2) {
            BuddyView(look: look, size: 50, lively: true)
            Text(name)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .lineLimit(1)
        }
        .frame(width: 72)
    }

    private func duelLine(mine: Int, theirs: Int, partner: String) -> String {
        if mine == theirs { return tr("A tie, for now.") }
        if mine > theirs { return tr("You caught %lld more.", mine - theirs) }
        return tr("%1$@ caught %2$lld more.", partner, theirs - mine)
    }

    // MARK: - Doors

    private var doors: some View {
        let entries = model.data.logs.count + model.data.kidIllnesses.count
        return HStack(spacing: 10) {
            door("tree.fill", tr("Skill Tree"), model.displayTitle) {
                SkillTreeScreen()
            }
            door("list.bullet", tr("Logbook"), entries == 0 ? tr("Empty") : trCount(entries, one: "%lld entry", other: "%lld entries")) {
                LogbookScreen()
            }
        }
    }

    private func door<Destination: View>(_ symbol: String, _ title: String, _ value: String,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .frame(width: 40, height: 40)
                    .background(palette.background, in: Circle())
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .padding(.top, 16)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .petriCard(radius: 26, padding: 14)
        }
        .buttonStyle(.plain)
    }

    private var doctorRow: some View {
        NavigationLink {
            DoctorSummaryScreen()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "stethoscope")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.inkSecondary)
                ValueRow(title: tr("For the doctor"))
            }
            .padding(.horizontal, 16)
            .petriCard(padding: 0)
        }
        .buttonStyle(.plain)
    }
}

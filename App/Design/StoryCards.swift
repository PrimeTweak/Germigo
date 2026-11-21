import SwiftUI

/// The Today sign as a card, for a germ-free streak milestone.
struct MilestoneShareCard: View {
    let days: Int

    var body: some View {
        ZStack {
            Color(hex: Swatch.agarSign)
            VStack(spacing: 0) {
                HazardStripes()
                    .frame(height: 22)
                Spacer(minLength: 0)
                Text(tr("This household has gone").uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(2)
                FlapCounter(value: days, tileWidth: days >= 100 ? 84 : 104)
                    .padding(.top, 18)
                Text(trCount(days, one: "day without a germ", other: "days without a germ").uppercased())
                    .font(.system(size: 21, weight: .black))
                    .kerning(0.6)
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
                PillLabel(text: tr("Milestone unlocked"), foreground: Color(hex: Swatch.night), background: Color(hex: Swatch.lime))
                    .padding(.top, 14)
                Spacer(minLength: 0)
                ShareWordmark(color: Color(hex: Swatch.night))
                    .padding(.bottom, 28)
                HazardStripes()
                    .frame(height: 22)
            }
            .foregroundStyle(Color(hex: Swatch.night))
        }
        .frame(width: 360, height: 640)
    }
}

/// The couple scoreboard for the season.
struct DuelShareCard: View {
    let seasonNumber: Int
    let me: String
    let meLook: Int
    let partner: String
    let partnerLook: Int
    let stats: DuelStats

    private var verdict: String {
        if stats.leader == .me { return tr("%@ suffered the most.", me) }
        if stats.leader == .partner { return tr("%@ suffered the most.", partner) }
        return tr("Dead heat. Nobody wins.")
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.pinkPale), Color(hex: Swatch.wisteria)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RingsBackground(color: Color.white.opacity(0.28), spacing: 34)
            VStack(spacing: 0) {
                Text(tr("Season %lld", seasonNumber).uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(2)
                    .padding(.top, 48)
                Text(tr("Couple duel"))
                    .font(.system(size: 42, weight: .black))
                    .kerning(-1)
                    .padding(.top, 2)
                HStack(alignment: .center, spacing: 8) {
                    column(name: me, look: meLook, side: stats.me, leads: stats.leader == .me)
                    Text(verbatim: "VS")
                        .font(.system(size: 16, weight: .black))
                        .opacity(0.6)
                    column(name: partner, look: partnerLook, side: stats.partner, leads: stats.leader == .partner)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                Text(verdict)
                    .font(.system(size: 21, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.top, 22)
                Spacer(minLength: 0)
                ShareWordmark(color: Color(hex: Swatch.night))
                    .padding(.bottom, 36)
            }
            .foregroundStyle(Color(hex: Swatch.night))
        }
        .frame(width: 360, height: 640)
    }

    private func column(name: String, look: Int, side: DuelSide, leads: Bool) -> some View {
        VStack(spacing: 8) {
            BuddyView(look: look, size: 62)
                .overlay(alignment: .top) {
                    if leads {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(hex: Swatch.night))
                            .offset(y: -24)
                    }
                }
            Text(name)
                .font(.system(size: 17, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(spacing: 7) {
                stat(String(side.points), tr("Sick Points"))
                stat(String(side.germs), tr("germs caught"))
                stat(String(side.daysSick), tr("days sick"))
                stat(String(side.nights), tr("night shifts"))
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 26)
        .padding(.bottom, 16)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(leads ? 0.94 : 0.62), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 26, weight: .heavy))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.65)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// A germ's boss card, sized for stories.
struct BossShareCard: View {
    let germ: Germ
    let survived: Int

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.plum), Color(hex: Swatch.plumDeep)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [germ.deepTint.opacity(0.65), Color.clear], center: UnitPoint(x: 0.5, y: 0.3),
                           startRadius: 0, endRadius: 230)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    PillLabel(text: tr("Boss").uppercased(), foreground: Color(hex: Swatch.night), background: Color(hex: Swatch.hazard))
                    PillLabel(text: germ.rarity.label.uppercased(), foreground: germ.rarity.pillForeground, background: germ.rarity.pillBackground)
                }
                .padding(.top, 40)
                GermImage(germ: germ, size: 168)
                    .padding(.top, 10)
                Text(germ.name)
                    .font(.system(size: 34, weight: .black))
                    .kerning(-0.5)
                Text(germ.illness.value)
                    .font(.system(size: 15, weight: .semibold))
                    .opacity(0.65)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Text(tr("HP"))
                            .font(.system(size: 13, weight: .heavy))
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.14))
                                Capsule()
                                    .fill(germ.rarity.color)
                                    .frame(width: proxy.size.width * CGFloat(germ.rarity.bossHealth) / 100)
                            }
                        }
                        .frame(height: 10)
                        Text(verbatim: "\(germ.rarity.bossHealth)")
                            .font(.system(size: 13, weight: .heavy))
                            .monospacedDigit()
                    }
                    line(tr("Special attack"), germ.boss.attack.value)
                    line(tr("Weakness"), germ.boss.weakness.value)
                    line(tr("Loot"), tr("+%lld Sick Points", germ.rarity.basePoints))
                }
                .padding(16)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 22)
                .padding(.top, 16)
                Spacer(minLength: 0)
                Text(trCount(survived, one: "Survived it %lld time.", other: "Survived it %lld times."))
                    .font(.system(size: 15, weight: .semibold))
                    .opacity(0.8)
                    .padding(.bottom, 14)
                ShareWordmark()
                    .padding(.bottom, 30)
            }
            .foregroundStyle(Color.white)
        }
        .frame(width: 360, height: 640)
    }

    private func line(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .kerning(0.8)
                .opacity(0.55)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The pages of the season story; empty pages are left out.
enum WrapPage: Hashable, Identifiable {
    case intro
    case count
    case days
    case guess
    case nemesis
    case dodges
    case duel
    case persona
    case summary

    var id: Self { self }

    static func pages(for wrap: SeasonWrap, supplier: SupplierStat?, hasPartner: Bool) -> [WrapPage] {
        var pages: [WrapPage] = [.intro]
        if wrap.germsCaught > 0 { pages += [.count, .days] }
        if (wrap.topGerm?.value ?? 0) >= 2 { pages += [.guess, .nemesis] }
        if wrap.dodged > 0 || supplier != nil { pages.append(.dodges) }
        if hasPartner && wrap.germsCaught > 0 { pages.append(.duel) }
        pages += [.persona, .summary]
        return pages
    }
}

/// One page of the season story, sized for stories.
struct WrapCard: View {
    let page: WrapPage
    let wrap: SeasonWrap
    let supplier: SupplierStat?

    private var ink: Color { Color(hex: Swatch.night) }

    var body: some View {
        ZStack {
            background
            RingsBackground(color: Color.white.opacity(page == .nemesis ? 0.05 : 0.3), spacing: 34)
            VStack(spacing: 0) {
                content
                Spacer(minLength: 0)
                ShareWordmark(color: page == .nemesis ? Color.white : ink)
                    .padding(.bottom, 36)
            }
            .foregroundStyle(page == .nemesis ? Color.white : ink)
            .padding(.horizontal, 28)
        }
        .frame(width: 360, height: 640)
    }

    private var background: LinearGradient {
        let pair: (UInt32, UInt32)
        switch page {
        case .intro, .summary, .guess, .duel: pair = (Swatch.limeLight, Swatch.grass)
        case .count: pair = (Swatch.lilacPale, Swatch.lilac)
        case .days: pair = (Swatch.coralPale, Swatch.coral)
        case .nemesis: pair = (Swatch.plum, Swatch.plumDeep)
        case .dodges: pair = (Swatch.skyPale, Swatch.skyMid)
        case .persona: pair = (Swatch.butter, Swatch.amber)
        }
        return LinearGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)], startPoint: .top, endPoint: .bottom)
    }

    private func kicker(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 14, weight: .heavy))
            .kerning(2)
            .padding(.top, 50)
    }

    private func bigNumber(_ value: Int) -> some View {
        Text(verbatim: String(value))
            .font(.system(size: 120, weight: .black))
            .kerning(-4)
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .intro:
            kicker(tr("Season %lld", wrap.season.number))
            Text(tr("Wrapped."))
                .font(.system(size: 64, weight: .black))
                .kerning(-2)
            Text(tr("Your daycare year, in germs."))
                .font(.system(size: 17, weight: .semibold))
                .opacity(0.7)
            HStack(spacing: -18) {
                ForEach(Array(wrap.germs.prefix(5).enumerated()), id: \.offset) { item in
                    GermImage(germ: item.element, size: 84)
                        .rotationEffect(.degrees(item.offset % 2 == 0 ? -8 : 7))
                }
            }
            .padding(.top, 40)
        case .count:
            kicker(tr("The damage"))
            Text(tr("You caught"))
                .font(.system(size: 22, weight: .bold))
                .padding(.top, 18)
            bigNumber(wrap.germsCaught)
            Text(trCount(wrap.germsCaught, one: "germ this season", other: "germs this season"))
                .font(.system(size: 20, weight: .bold))
            VStack(spacing: 8) {
                familyRow(SkillBranch.airways, wrap.families[.airways] ?? 0)
                familyRow(SkillBranch.gut, wrap.families[.gut] ?? 0)
                familyRow(SkillBranch.skin, wrap.families[.skin] ?? 0)
            }
            .padding(.top, 20)
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("For scale"))
                    .font(.system(size: 13, weight: .heavy))
                Text(tr("A one-year-old's first daycare year brings about 12 to 15 respiratory infections, 2 stomach bugs and 1 or 2 rash illnesses."))
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: "Caddy et al., Clinical Microbiology Reviews, 2026")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.6)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.top, 16)
        case .days:
            kicker(tr("Couch time"))
            bigNumber(wrap.daysSick)
                .padding(.top, 30)
            Text(trCount(wrap.daysSick, one: "day sick", other: "days sick"))
                .font(.system(size: 24, weight: .heavy))
            VStack(spacing: 8) {
                if let longest = wrap.longest {
                    factRow(tr("Longest"), longest.germ.name + " · " + trCount(longest.value, one: "%lld day", other: "%lld days"))
                }
                factRow(tr("Night-shift logs"), String(wrap.nightLogs))
                factRow(tr("Workdays lost"), String(wrap.workdays))
            }
            .padding(.top, 28)
        case .nemesis:
            kicker(tr("Your nemesis"))
            if let top = wrap.topGerm {
                GermImage(germ: top.germ, size: 220)
                    .padding(.top, 24)
                Text(top.germ.name)
                    .font(.system(size: 44, weight: .black))
                    .kerning(-1)
                Text(top.germ.illness.value)
                    .font(.system(size: 16, weight: .semibold))
                    .opacity(0.65)
                Text(trCount(top.value, one: "Caught %lld time this season", other: "Caught %lld times this season"))
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color(hex: Swatch.lime))
                    .padding(.top, 18)
            }
        case .dodges:
            kicker(tr("The ones that got away"))
            bigNumber(wrap.dodged)
                .padding(.top, 30)
            Text(trCount(wrap.dodged, one: "germ dodged", other: "germs dodged"))
                .font(.system(size: 24, weight: .heavy))
            if let supplier {
                HStack(spacing: 12) {
                    BuddyView(look: supplier.kid.colorIndex, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Top supplier: %@", supplier.kid.name))
                            .font(.system(size: 17, weight: .heavy))
                        Text(tr("%1$lld of your %2$lld germs", supplier.count, supplier.total))
                            .font(.system(size: 14, weight: .semibold))
                            .opacity(0.7)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 30)
            }
        case .persona:
            kicker(tr("Your parent type"))
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 76, weight: .semibold))
                .padding(.top, 50)
            Text(wrap.persona.title)
                .font(.system(size: 40, weight: .black))
                .kerning(-1)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .padding(.top, 18)
            Text(wrap.persona.blurb)
                .font(.system(size: 19, weight: .semibold))
                .multilineTextAlignment(.center)
                .opacity(0.75)
                .padding(.top, 10)
        case .guess, .duel, .summary:
            EmptyView()
        }
    }

    private func familyRow(_ branch: SkillBranch, _ count: Int) -> some View {
        HStack {
            Image(systemName: branch.symbol)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 24)
            Text(branch.unit)
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(verbatim: String(count))
                .font(.system(size: 18, weight: .heavy))
                .monospacedDigit()
        }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .opacity(0.75)
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// The household's league for the season, sized for stories.
struct FamilyLeagueShareCard: View {
    let seasonNumber: Int
    let places: [PodiumPlace]

    private static let heights: [CGFloat] = [96, 66, 44]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.pinkPale), Color(hex: Swatch.wisteria)], startPoint: .topLeading, endPoint: .bottomTrailing)
            RingsBackground(color: Color.white.opacity(0.28), spacing: 34)
            VStack(spacing: 0) {
                Text(tr("Season %lld", seasonNumber).uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(2)
                    .padding(.top, 48)
                Text(tr("Family league"))
                    .font(.system(size: 42, weight: .black))
                    .kerning(-1)
                    .padding(.top, 2)
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach([1, 0, 2].filter { $0 < places.count }, id: \.self) { index in
                        step(places[index], rank: index + 1)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 34)
                VStack(spacing: 6) {
                    ForEach(Array(places.enumerated()).dropFirst(3).prefix(3), id: \.element.id) { item in
                        Text(verbatim: line(item.element, rank: item.offset + 1))
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                    }
                }
                .padding(.top, 18)
                Spacer(minLength: 0)
                ShareWordmark(color: Color(hex: Swatch.night))
                    .padding(.bottom, 36)
            }
            .foregroundStyle(Color(hex: Swatch.night))
        }
        .frame(width: 360, height: 640)
    }

    private func line(_ place: PodiumPlace, rank: Int) -> String {
        let head = String(rank) + ". " + place.name
        guard let title = place.title else { return head }
        return head + ", " + title
    }

    private func step(_ place: PodiumPlace, rank: Int) -> some View {
        VStack(spacing: 0) {
            BuddyView(look: place.look, sick: place.sick, size: rank == 1 ? 74 : 60)
                .padding(.bottom, 4)
            Text(verbatim: String(rank))
                .font(.system(size: 24, weight: .black))
                .padding(.top, 8)
                .frame(maxWidth: .infinity, minHeight: Self.heights[rank - 1], alignment: .top)
                .background(Color.white.opacity(rank == 1 ? 0.94 : 0.62),
                            in: UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 8,
                                                       bottomTrailingRadius: 8, topTrailingRadius: 20))
            Text(place.name)
                .font(.system(size: 17, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 10)
            Text(place.title ?? " ")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: Swatch.iris))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(place.detail)
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.65)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

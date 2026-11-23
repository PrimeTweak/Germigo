import SwiftUI

/// The pages that show what Germily does, between the practice tap and the Season Pass offer.
enum TourPage: Int, CaseIterable {
    case family
    case guide
    case crew
    case trophies

    var title: String {
        switch self {
        case .family: return tr("Who brought it home?")
        case .guide: return tr("Know the enemy.")
        case .crew: return tr("Know what's going around.")
        case .trophies: return tr("Make it a game.")
        }
    }

    var detail: String {
        switch self {
        case .family: return tr("Your kid, then the whole household: who caught what, from whom, and for how long.")
        case .guide: return tr("Every germ has its file: how it spreads, how long it lasts and when to call. A daily quiz unlocks the lessons.")
        case .crew: return tr("Your daycare can warn you when an illness hits your kid's group. Free.")
        case .trophies: return tr("Every germ fills your collection: badges, streaks and the story of your season, to share.")
        }
    }

    /// What the Season Pass adds on this page, if anything.
    var passLine: String? {
        switch self {
        case .family: return tr("Your partner and every kid")
        case .guide: return nil
        case .crew: return tr("The radar of your crew of friends")
        case .trophies: return tr("The family league and the couple duel")
        }
    }

    var previous: TourPage? { TourPage(rawValue: rawValue - 1) }
    var next: TourPage? { TourPage(rawValue: rawValue + 1) }
}

/// One page of the tour: what a part of the app does, then a sample of it with made-up data.
struct TourPageView: View {
    let page: TourPage
    /// The first name typed for patient zero, empty when skipped.
    let kidName: String
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text(page.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(page.detail)
                    .font(.body)
                    .foregroundStyle(palette.inkSecondary)
                if let line = page.passLine {
                    passLine(line)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.page)
            .padding(.top, 8)
            ShrinkToFit {
                hero
                    .frame(maxWidth: 320)
                    .padding(.horizontal, Spacing.page)
            }
            .padding(.vertical, 16)
            .accessibilityHidden(true)
        }
    }

    private func passLine(_ text: String) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .accessibilityHidden(true)
                Text(tr("Season Pass"))
                    .lineLimit(1)
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(palette.accent.opacity(0.12), in: Capsule())
            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var hero: some View {
        switch page {
        case .family: familyHero
        case .guide: guideHero
        case .crew: crewHero
        case .trophies: trophiesHero
        }
    }

    private var name: String {
        kidName.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Family

    private var familyHero: some View {
        let looks = [0, Looks.host, Looks.partner]
        let seats = CouchSeats(count: looks.count)
        return VStack(spacing: 3) {
            ZStack {
                CouchBackdrop()
                ForEach(Array(looks.enumerated()), id: \.offset) { item in
                    BuddyView(look: item.element, sick: item.offset == 0, size: seats.head, leads: true,
                              phase: Double(item.offset) * CharacterPose.accentCycle / Double(looks.count))
                        .position(seats.center(of: item.offset))
                }
            }
            .frame(width: CouchSeats.width, height: CouchSeats.height)
            Text(name.isEmpty ? tr("Patient zero brought it home.") : tr("%@ brought it home.", name))
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
    }

    // MARK: - Guide

    @ViewBuilder
    private var guideHero: some View {
        if let germ = model.catalog.germ("rhino") {
            VStack(spacing: 12) {
                GermHero(germ: germ, caught: 2)
                doctorCard(germ)
            }
        }
    }

    /// The "when to call" card of the case file, open on its signs.
    private func doctorCard(_ germ: Germ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 13) {
                IconTile(symbol: "stethoscope", size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("When to call"))
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(germ.doctorLead.value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.ink.opacity(0.85))
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.up")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(palette.inkSecondary)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(germ.doctorSigns.enumerated()), id: \.offset) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "circle")
                            .font(.title3)
                            .foregroundStyle(palette.inkTertiary)
                        Text(item.element.value)
                            .font(.subheadline)
                            .foregroundStyle(palette.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8)
                }
            }
            Text(tr("In an emergency, call your local emergency number."))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.accent.opacity(palette.isDark ? 0.2 : 0.12),
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    // MARK: - Crew

    private var crewHero: some View {
        VStack(spacing: 12) {
            daycareCard
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: tr("Going around"), trailing: tr("This week"))
                RadarRow(entry: RadarEntry(germID: "noro", families: 4), families: 5)
                RadarRow(entry: RadarEntry(germID: "rhino", families: 3), families: 5)
                Label(tr("A germ shows up once 3 families report it. No names."), systemImage: "shield.lefthalf.filled")
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.leading)
            }
            .germilyCard()
        }
    }

    /// A followed daycare with a fresh notice, as the Crew tab shows it.
    private var daycareCard: some View {
        let group = tr("Toddlers")
        let time = Calendar.current.date(bySettingHour: 14, minute: 14, second: 0, of: Date()) ?? Date()
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                DaycareBadge()
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Little Peas Daycare"))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .lineLimit(1)
                    Text(name.isEmpty ? group : name + " · " + group)
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.inkTertiary)
            }
            if let germ = model.catalog.germ("noro") {
                HStack(spacing: 10) {
                    GermImage(germ: germ, size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("%1$@ in %2$@", germ.illness.value, group))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.ink)
                            .lineLimit(1)
                        Text(tr("Today, %@", time.formatted(date: .omitted, time: .shortened)) + " · " + tr("from the daycare"))
                            .font(.caption)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    Spacer(minLength: 0)
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 9, height: 9)
                }
                .padding(10)
                .background(germ.lightTint.opacity(palette.isDark ? 0.18 : 0.32),
                            in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            }
        }
        .germilyCard(padding: 12)
    }

    // MARK: - Trophies

    private var trophiesHero: some View {
        VStack(spacing: 12) {
            collectionCard
            seasonCard
        }
    }

    private var collectionCard: some View {
        let shelf = [("rhino", 2), ("noro", 1), ("flu", 0), ("pinky", 0), ("strep", 0)]
            .compactMap { item in model.catalog.germ(item.0).map { ($0, item.1) } }
        let badges = [BadgeCatalog.ironParent, BadgeCatalog.nightShift, "collector", BadgeCatalog.labRat, BadgeCatalog.dodger]
            .compactMap { BadgeCatalog.badge($0) }
        return VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: tr("Microbe cards"), trailing: tr("%1$lld of %2$lld caught", 2, model.catalog.germs.count))
            HStack(spacing: 8) {
                ForEach(Array(shelf.enumerated()), id: \.offset) { item in
                    MicrobeCard(germ: item.element.0, count: item.element.1)
                }
            }
            .padding(.top, 10)
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("Badges"), trailing: tr("%1$lld of %2$lld", 2, BadgeCatalog.all.count))
                HStack(spacing: 8) {
                    ForEach(Array(badges.enumerated()), id: \.offset) { item in
                        BadgeMedal(badge: item.element, won: item.offset < 2, progress: item.offset == 2 ? 0.4 : nil)
                    }
                }
                if badges.count > 2 {
                    Text(tr("Next: %1$@, %2$lld of %3$lld.", badges[2].title, 2, 5))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
            }
            .padding(.top, 16)
        }
        .germilyCard()
    }

    private var seasonCard: some View {
        let rhino = model.catalog.germ("rhino")
        let noro = model.catalog.germ("noro")
        let weeks: [Germ?] = [nil, nil, rhino, rhino, nil, nil, nil, noro, nil, nil, nil, nil]
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(tr("Season %lld", 1))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.ink)
                Spacer(minLength: 8)
                Text(tr("Week %lld", weeks.count))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
            }
            HStack(alignment: .top, spacing: 8) {
                SeasonFigure(value: 2, label: tr("germs caught"))
                SeasonFigure(value: 9, label: tr("days sick"))
                SeasonFigure(value: 1, label: tr("germs dodged"))
            }
            .padding(.top, 10)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: weeks.count), spacing: 5) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { item in
                    SeasonWeekCell(germ: item.element, isNow: item.offset == weeks.count - 1)
                }
            }
            .padding(.top, 12)
            if let rhino {
                Text(tr("%1$@ is your nemesis: %2$lld times already.", rhino.name, 2))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 10)
            }
        }
        .germilyCard()
    }
}

/// Where the tour is: one dot per page, the current one stretched.
struct TourDots: View {
    let current: TourPage
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TourPage.allCases, id: \.self) { page in
                Capsule()
                    .fill(page == current ? palette.ink : palette.ink.opacity(0.18))
                    .frame(width: page == current ? 22 : 7, height: 7)
            }
        }
        .animation(Tempo.quick, value: current)
        .accessibilityHidden(true)
    }
}

/// Scales its content down to the height left, never up, so a sample fits small phones and large text.
private struct ShrinkToFit<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var natural: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let scale = natural > proxy.size.height && proxy.size.height > 0 ? proxy.size.height / natural : 1
            content
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { natural = $0 }
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

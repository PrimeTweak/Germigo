import SwiftUI

/// The boss-defeated card, sized for stories.
struct VictoryShareCard: View {
    let germ: Germ
    let days: Int

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.plum), Color(hex: Swatch.plumDeep)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [germ.deepTint.opacity(0.55), Color.clear], center: UnitPoint(x: 0.5, y: 0.36),
                           startRadius: 0, endRadius: 230)
            VStack(spacing: 0) {
                PillLabel(text: tr("Boss defeated").uppercased(), foreground: Color(hex: Swatch.night),
                          background: Color(hex: Swatch.lime))
                    .padding(.top, 44)
                ZStack(alignment: .topTrailing) {
                    GermImage(germ: germ, size: 190)
                        .saturation(0.6)
                    Text(verbatim: "K.O.")
                        .font(.system(size: 26, weight: .black))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: Swatch.coral), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                        .rotationEffect(.degrees(8))
                }
                .padding(.top, 18)
                Text(germ.name)
                    .font(.system(size: 38, weight: .black))
                    .kerning(-0.5)
                    .padding(.top, 10)
                Text(germ.illness.value + " · " + trCount(days, one: "%lld day", other: "%lld days"))
                    .font(.system(size: 16, weight: .semibold))
                    .opacity(0.7)
                HStack(spacing: 10) {
                    Text(tr("HP"))
                        .font(.system(size: 13, weight: .heavy))
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                        .frame(height: 10)
                    Text(verbatim: "0 / \(germ.rarity.bossHealth)")
                        .font(.system(size: 13, weight: .heavy))
                        .monospacedDigit()
                }
                .padding(16)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                .padding(.horizontal, 28)
                .padding(.top, 22)
                Spacer(minLength: 0)
                Text(tr("Back on my feet."))
                    .font(.system(size: 22, weight: .heavy))
                    .padding(.bottom, 14)
                ShareWordmark()
                    .padding(.bottom, 36)
            }
            .foregroundStyle(Color.white)
        }
        .frame(width: 360, height: 640)
    }
}

/// A month in numbers, sized for stories.
struct MonthRecapCard: View {
    let recap: MonthRecap

    private var ink: Color { Color(hex: Swatch.night) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.limeLight), Color(hex: Swatch.grass)], startPoint: .top, endPoint: .bottom)
            RingsBackground(color: Color.white.opacity(0.3), spacing: 34)
            VStack(alignment: .leading, spacing: 0) {
                Text(recap.monthName.uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(2)
                    .padding(.top, 50)
                Text(tr("Your %@ recap", recap.monthName))
                    .font(.system(size: 44, weight: .black))
                    .kerning(-1.5)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 10)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile(recap.caught, trCount(recap.caught, one: "germ caught", other: "germs caught"))
                    tile(recap.daysSick, trCount(recap.daysSick, one: "day sick", other: "days sick"))
                    tile(recap.labDays, trCount(recap.labDays, one: "quiz day", other: "quiz days"))
                    tile(recap.dodged, trCount(recap.dodged, one: "germ dodged", other: "germs dodged"))
                }
                .padding(.top, 22)
                if let germ = recap.nemesis {
                    HStack(spacing: 12) {
                        GermImage(germ: germ, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Month's nemesis").uppercased())
                                .font(.system(size: 11, weight: .heavy))
                                .kerning(1.4)
                                .foregroundStyle(Color(hex: Swatch.lime))
                            Text(germ.name)
                                .font(.system(size: 22, weight: .heavy))
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Color(hex: Swatch.chalk))
                    .padding(12)
                    .background(ink, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    .padding(.top, 12)
                }
                Spacer(minLength: 0)
                ShareWordmark(color: ink)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 36)
            }
            .foregroundStyle(ink)
            .padding(.horizontal, 28)
        }
        .frame(width: 360, height: 640)
    }

    private func tile(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: String(value))
                .font(.system(size: 40, weight: .black))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
    }
}

/// A kid standing over the germ they beat, the germ faded and stamped K.O.
struct KidKnockout: View {
    let look: Int
    let germ: Germ
    var size: CGFloat = 150
    var leads = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            BuddyView(look: look, size: size, leads: leads)
            GermImage(germ: germ, size: size * 0.66)
                .saturation(0.35)
                .rotationEffect(.degrees(-14))
                .overlay(alignment: .topTrailing) {
                    Text(verbatim: "K.O.")
                        .font(.system(size: size * 0.13, weight: .black))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color(hex: Swatch.coral), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                        .rotationEffect(.degrees(8))
                        .offset(x: 8, y: -8)
                }
        }
        .accessibilityHidden(true)
    }
}

/// The score between a kid and a germ: every win of the kid against the germ's none.
struct KidScore: View {
    let name: String
    let wins: Int
    let germ: String

    var body: some View {
        HStack(spacing: 14) {
            side(name)
            number(wins)
            Text(verbatim: "–")
                .font(.system(size: 30, weight: .bold))
                .opacity(0.4)
            number(0)
            side(germ)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("%1$@ %2$lld, %3$@ %4$lld", name, wins, germ, 0))
    }

    private func side(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .opacity(0.75)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func number(_ value: Int) -> some View {
        Text(verbatim: String(value))
            .font(.system(size: 46, weight: .heavy))
            .monospacedDigit()
    }
}

/// A kid's win over a germ, sized for stories.
struct KidVictoryShareCard: View {
    let victory: KidVictory

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.plum), Color(hex: Swatch.plumDeep)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [victory.germ.deepTint.opacity(0.55), Color.clear], center: UnitPoint(x: 0.5, y: 0.42),
                           startRadius: 0, endRadius: 230)
            VStack(spacing: 0) {
                PillLabel(text: tr("Boss defeated").uppercased(), foreground: Color(hex: Swatch.night),
                          background: Color(hex: Swatch.lime))
                    .padding(.top, 44)
                Text(tr("%1$@ beat %2$@!", victory.kid.name, victory.germ.name))
                    .font(.system(size: 34, weight: .black))
                    .kerning(-0.5)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                Text(victory.germ.illness.value + " · " + trCount(victory.days, one: "%lld day", other: "%lld days"))
                    .font(.system(size: 16, weight: .semibold))
                    .opacity(0.7)
                    .padding(.top, 6)
                KidKnockout(look: victory.kid.colorIndex, germ: victory.germ, size: 130)
                    .padding(.top, 28)
                KidScore(name: victory.kid.name, wins: victory.wins, germ: victory.germ.name)
                    .padding(.top, 22)
                Spacer(minLength: 0)
                Text(tr("Back to full volume."))
                    .font(.system(size: 22, weight: .heavy))
                    .padding(.bottom, 14)
                ShareWordmark()
                    .padding(.bottom, 36)
            }
            .foregroundStyle(Color.white)
        }
        .frame(width: 360, height: 640)
    }
}

/// Two of the recap's cards, fanned out: what the season story opens.
struct RecapCardsIcon: View {
    private let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)

    var body: some View {
        ZStack {
            face
                .overlay(Color(hex: Swatch.limeInk).opacity(0.3), in: shape)
                .rotationEffect(.degrees(-14))
                .offset(x: -4)
            face
                .overlay(alignment: .topLeading) {
                    marks
                }
                .rotationEffect(.degrees(6))
                .offset(x: 3, y: 1)
        }
        .frame(width: 26, height: 30)
        .accessibilityHidden(true)
    }

    private var face: some View {
        shape
            .fill(LinearGradient(colors: [Color(hex: Swatch.limeLight), Color(hex: Swatch.grass)], startPoint: .top, endPoint: .bottom))
            .frame(width: 18, height: 25)
    }

    /// The card's title, the line under it and its code in the corner, in miniature.
    private var marks: some View {
        let ink = Color(hex: Swatch.night)
        return ZStack(alignment: .topLeading) {
            Capsule()
                .fill(ink)
                .frame(width: 12, height: 3.3)
                .offset(x: 3, y: 5)
            Capsule()
                .fill(ink.opacity(0.6))
                .frame(width: 9.5, height: 1.4)
                .offset(x: 4.3, y: 10)
            RoundedRectangle(cornerRadius: 0.8, style: .continuous)
                .fill(Color.white)
                .frame(width: 4.4, height: 4.4)
                .offset(x: 10.6, y: 18)
        }
        .frame(width: 18, height: 25, alignment: .topLeading)
    }
}

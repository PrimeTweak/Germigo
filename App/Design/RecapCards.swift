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
                        .background(Color(hex: Swatch.coral), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                Text(tr("Your %@, wrapped", recap.monthName))
                    .font(.system(size: 44, weight: .black))
                    .kerning(-1.5)
                    .minimumScaleFactor(0.6)
                    .padding(.top, 10)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    tile(recap.caught, trCount(recap.caught, one: "germ caught", other: "germs caught"))
                    tile(recap.daysSick, trCount(recap.daysSick, one: "day sick", other: "days sick"))
                    tile(recap.labDays, trCount(recap.labDays, one: "Lab day", other: "Lab days"))
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
                    .background(ink, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

import SwiftUI

/// The words around a "Going around" report.
enum GoingAroundText {
    static func country(_ region: String) -> String {
        region == "US" ? tr("United States") : tr("Canada")
    }
}

extension GoingAroundTrend {
    var title: String {
        switch self {
        case .rising: tr("Rising")
        case .steady: tr("Steady")
        case .falling: tr("Falling")
        case .low: tr("Low")
        }
    }

    var symbol: String {
        switch self {
        case .rising: "arrow.up"
        case .steady: "arrow.right"
        case .falling: "arrow.down"
        case .low: "minus"
        }
    }

    func ink(_ palette: Palette) -> Color {
        switch self {
        case .rising: Color(hex: palette.isDark ? Swatch.coralSoft : Swatch.coralInk)
        case .steady: Color(hex: palette.isDark ? Swatch.slate : Swatch.slateInk)
        case .falling, .low: Color(hex: palette.isDark ? Swatch.green : Swatch.greenInk)
        }
    }
}

/// This week's public health report, in our words: each germ and where it is heading, then the source.
struct GoingAroundScreen: View {
    let report: GoingAroundReport
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                hero
                VStack(spacing: 0) {
                    ForEach(Array(report.germs.enumerated()), id: \.element.germID) { item in
                        if item.offset > 0 {
                            Divider()
                                .padding(.leading, 58)
                        }
                        if let germ = model.catalog.germ(item.element.germID) {
                            NavigationLink(value: germ) {
                                row(germ, item.element)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .germilyCard(padding: 0)
                SectionHeader(title: tr("Source"))
                SourceList(references: [report.source])
                Text(tr("Summarized in our words. Tap a germ for its page."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
                HealthLineNote()
                Text(HealthNotice.text)
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 28)
        }
        .background(CharacterWash(tint: TabWash.lab))
        .navigationTitle(tr("Going around"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        let week = LessonEngine.calendarDay(report.week)
        let published = LessonEngine.calendarDay(report.published)
        return VStack(alignment: .leading, spacing: 6) {
            Text(GoingAroundText.country(report.region))
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: Swatch.azureInk))
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Color.white, in: Capsule())
            if let week {
                Text(tr("Week of %@", week.formatted(.dateTime.month(.wide).day())))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(hex: Swatch.ink))
            }
            Text(report.headline.value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color(hex: Swatch.ink))
                .fixedSize(horizontal: false, vertical: true)
            if let published {
                Text(tr("Published %@", published.formatted(.dateTime.weekday(.wide).month(.wide).day())))
                    .font(.footnote)
                    .foregroundStyle(Color(hex: Swatch.slateInk))
            }
            Label(tr("National figures. Your region can differ."), systemImage: "info.circle")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color(hex: Swatch.azureInk))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(hex: Swatch.skyMist), Color(hex: Swatch.lilacMist)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func row(_ germ: Germ, _ item: GoingAroundGerm) -> some View {
        let ink = item.trend.ink(palette)
        return HStack(spacing: 12) {
            GermImage(germ: germ, size: 37)
                .frame(width: 46, height: 46)
                .background(germ.tileTint(palette), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(germ.illness.value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(item.line.value)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 6)
            Label(item.trend.title, systemImage: item.trend.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(ink)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .background(ink.opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

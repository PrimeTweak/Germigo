import SwiftUI

/// The season told in a few story cards, each one shareable.
struct WrappedScreen: View {
    let season: Season
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var page = WrapPage.intro
    @State private var sharing: WrapPage?

    var body: some View {
        let wrap = WrapEngine.wrap(data: model.data, catalog: model.catalog, season: season, now: Date())
        let stats = model.seasonStats(for: season)
        let pages = WrapPage.pages(for: wrap, supplier: stats.topSupplier)
        GeometryReader { proxy in
            let scale = max(0.4, min((proxy.size.width - 48) / 360, (proxy.size.height - 130) / 640))
            VStack(spacing: 14) {
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        card(item, wrap: wrap, stats: stats)
                            .frame(width: 360, height: 640)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                            .scaleEffect(scale)
                            .frame(width: 360 * scale, height: 640 * scale)
                            .tag(item)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .frame(width: 52, height: 52)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(tr("Close"))
                    Button {
                        sharing = page
                    } label: {
                        Label(tr("Share this card"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PillButtonStyle(kind: .accent, height: 52))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
        .foregroundStyle(Color.white)
        .background(Color(hex: Swatch.nightBase).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(item: $sharing) { item in
            SharePreviewSheet(title: tr("Season wrapped")) {
                card(item, wrap: wrap, stats: stats)
            }
        }
    }

    @ViewBuilder
    private func card(_ item: WrapPage, wrap: SeasonWrap, stats: SeasonStats) -> some View {
        if item == .summary {
            SeasonRecapCard(seasonNumber: season.number, stats: stats, level: model.level,
                            title: model.displayTitle, germs: wrap.germs)
        } else {
            WrapCard(page: item, wrap: wrap, supplier: stats.topSupplier)
        }
    }
}

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
        let pages = WrapPage.pages(for: wrap, supplier: stats.topSupplier, hasPartner: model.data.partnerName != nil)
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
                    .disabled(page == .guess)
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
        } else if item == .guess {
            NemesisGuessCard(season: season, wrap: wrap)
        } else if item == .duel {
            DuelShareCard(seasonNumber: season.number, me: model.displayName, partner: model.partnerDisplayName,
                          stats: DuelEngine.stats(data: model.data, season: season, now: Date()))
        } else {
            WrapCard(page: item, wrap: wrap, supplier: stats.topSupplier)
        }
    }
}

/// Before the reveal: guess the season's nemesis among three germs, once.
private struct NemesisGuessCard: View {
    let season: Season
    let wrap: SeasonWrap
    @Environment(AppModel.self) private var model

    private var options: [Germ] {
        guard let top = wrap.topGerm?.germ else { return [] }
        var pool = wrap.germs.filter { $0.id != top.id }
        if pool.count < 2 {
            let extra = model.catalog.germs.filter { germ in germ.id != top.id && !pool.contains(germ) }
            pool += extra
        }
        var generator = SeededGenerator(seed: QuizEngine.seed("nemesis-" + String(season.number)))
        let others = Array(pool.shuffled(using: &generator).prefix(2))
        return ([top] + others).shuffled(using: &generator)
    }

    var body: some View {
        let guess = model.data.wrapGuesses[String(season.number)]
        let topID = wrap.topGerm?.germ.id
        let lime = Color(hex: Swatch.lime)
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.plum), Color(hex: Swatch.plumDeep)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                Text(tr("Before the reveal").uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(2)
                    .foregroundStyle(lime)
                    .padding(.top, 50)
                Text(tr("Who was your nemesis this season?"))
                    .font(.system(size: 36, weight: .black))
                    .kerning(-1)
                    .minimumScaleFactor(0.7)
                    .padding(.top, 10)
                Text(guessLine(guess))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(guess == true ? lime : Color.white.opacity(0.75))
                    .padding(.top, 8)
                VStack(spacing: 12) {
                    ForEach(options) { germ in
                        let isTop = guess != nil && germ.id == topID
                        Button {
                            Haptics.tap()
                            model.guessNemesis(germ.id, season: season)
                        } label: {
                            HStack(spacing: 14) {
                                GermImage(germ: germ, size: 50)
                                    .padding(4)
                                    .background(germ.lightTint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                Text(germ.name)
                                    .font(.system(size: 21, weight: .heavy))
                                Spacer(minLength: 0)
                                if isTop {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundStyle(lime)
                                }
                            }
                            .padding(12)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(isTop ? lime : Color.white.opacity(0.12), lineWidth: 2)
                            }
                            .opacity(guess != nil && !isTop ? 0.55 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(guess != nil)
                    }
                }
                .padding(.top, 28)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 28)
        }
        .frame(width: 360, height: 640)
    }

    private func guessLine(_ guess: Bool?) -> String {
        switch guess {
        case .some(true): return tr("Right! +%lld pts", RewardEngine.wrapGuessPoints)
        case .some(false): return tr("Not this one. Swipe to see.")
        case .none: return tr("Guess, then swipe to see.")
        }
    }
}


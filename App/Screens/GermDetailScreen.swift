import SwiftUI

/// One germ: the card, the always-open health notes, and the parent's history with it.
struct GermDetailScreen: View {
    let germ: Germ
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showShare = false
    @State private var showPaywall = false

    private var caught: Int { model.count(of: germ.id) }
    private var finish: GermCardView.Finish { model.cardFinish(for: germ) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                statTiles
                notes
                doctorBanner
                deepDive
                history
                sources
                Text(tr("Petri shares general information from public health sources. It is not medical advice and does not replace a health professional."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(germ.illness.value)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if caught > 0 {
                    Button {
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel(tr("Share card"))
                }
            }
        }
        .sheet(isPresented: $showShare) {
            SharePreviewSheet(title: tr("Share card")) {
                GermShareCard(germ: germ, count: caught, finish: finish)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            GermCardView(germ: germ, width: 168, finish: finish, count: caught)
            VStack(spacing: 4) {
                Text(caught > 0 ? germ.name : tr("Not caught yet"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(germ.scientific.value)
                    .font(.subheadline.italic())
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: 8) {
                PillLabel(text: germ.rarity.label, foreground: .white, background: germ.rarity.color)
                PillLabel(text: tr("Card %@", germ.numberLabel), foreground: palette.ink,
                          background: palette.ink.opacity(0.08))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background {
            ZStack {
                LinearGradient(colors: [germ.lightTint.opacity(0.55), germ.lightTint.opacity(0.15)],
                               startPoint: .top, endPoint: .bottom)
                RingsBackground(color: Color.white.opacity(palette.isDark ? 0.06 : 0.5), spacing: 26)
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }

    private var statTiles: some View {
        HStack(spacing: 10) {
            statTile(value: String(caught), label: tr("Caught"))
            statTile(value: germ.showsUp.value, label: tr("Shows up"))
            statTile(value: germ.lasts.value, label: tr("Lasts"))
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(palette.inkSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .petriCard(radius: 20, padding: 12)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Field Notes"), trailing: tr("Always open"))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(germ.facts.enumerated()), id: \.offset) { item in
                    if item.offset > 0 {
                        Divider()
                    }
                    HStack(alignment: .top, spacing: 13) {
                        IconTile(symbol: item.element.icon, background: germ.lightTint, foreground: Color(hex: 0x1E1A26))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.element.label.value)
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                            Text(item.element.value.value)
                                .font(.callout)
                                .foregroundStyle(palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .petriCard(padding: 0)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(germ.tips.enumerated()), id: \.offset) { item in
                    if item.offset > 0 {
                        Divider()
                    }
                    HStack(alignment: .top, spacing: 13) {
                        IconTile(symbol: item.element.icon, background: palette.surfaceAlt, foreground: palette.ink)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.element.title.value)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(palette.ink)
                            Text(item.element.body.value)
                                .font(.subheadline)
                                .foregroundStyle(palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .petriCard(padding: 0)
        }
    }

    private var doctorBanner: some View {
        HStack(alignment: .top, spacing: 13) {
            IconTile(symbol: "cross.case.fill", background: palette.coralDeep, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("When to call"))
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                Text(germ.doctor.value)
                    .font(.subheadline)
                    .foregroundStyle(palette.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                Text(tr("In an emergency, call your local emergency number."))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.coralDeep)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.coral.opacity(palette.isDark ? 0.2 : 0.12),
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder
    private var deepDive: some View {
        if !germ.deepDive.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("Deep dive"))
                if model.deepDiveUnlocked(for: germ) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(germ.deepDive.enumerated()), id: \.offset) { item in
                            Text(item.element.value)
                                .font(.callout)
                                .foregroundStyle(palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .petriCard()
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            IconTile(symbol: "lock.fill", background: palette.surfaceAlt, foreground: palette.ink, size: 36)
                            Text(tr("The fun science unlocks when you catch this germ, or right away with the Season Pass."))
                                .font(.subheadline)
                                .foregroundStyle(palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Button(tr("See the Season Pass")) {
                            showPaywall = true
                        }
                        .buttonStyle(PillButtonStyle(kind: .accent, height: 46))
                    }
                    .petriCard()
                }
            }
        }
    }

    @ViewBuilder
    private var history: some View {
        let logs = model.logs(of: germ.id)
        if !logs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("History"), trailing: trCount(logs.count, one: "%lld time", other: "%lld times"))
                VStack(spacing: 0) {
                    ForEach(Array(logs.enumerated()), id: \.element.id) { item in
                        if item.offset > 0 {
                            Divider()
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.element.startedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(palette.ink)
                                Text(tr("From %1$@ · %2$@", model.sourceName(item.element.source),
                                        trCount(item.element.dayCount(), one: "%lld day", other: "%lld days")))
                                    .font(.footnote)
                                    .foregroundStyle(palette.inkSecondary)
                            }
                            Spacer()
                            Text(tr("+%lld pts", item.element.points))
                                .font(.footnote.weight(.semibold).monospacedDigit())
                                .foregroundStyle(palette.inkSecondary)
                        }
                        .padding(.vertical, 11)
                    }
                }
                .padding(.horizontal, 16)
                .petriCard(padding: 0)
            }
        }
    }

    @ViewBuilder
    private var sources: some View {
        if !germ.sources.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("Sources"))
                SourceList(references: germ.sources)
            }
        }
    }
}

/// Tappable references for a germ or an article.
struct SourceList: View {
    let references: [GermReference]
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(references.enumerated()), id: \.offset) { item in
                if item.offset > 0 {
                    Divider()
                }
                if let url = URL(string: item.element.url) {
                    Link(destination: url) {
                        HStack {
                            Text(item.element.name)
                                .font(.subheadline)
                                .foregroundStyle(palette.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(palette.inkTertiary)
                        }
                        .frame(minHeight: 46)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .petriCard(padding: 0)
    }
}

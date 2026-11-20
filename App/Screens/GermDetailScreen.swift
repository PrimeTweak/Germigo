import SwiftUI

/// One germ: the card, the always-open health notes, and the parent's history with it.
struct GermDetailScreen: View {
    let germ: Germ
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showShare = false
    @State private var showPaywall = false
    @State private var showBossShare = false
    @State private var checkedSigns: Set<Int> = []
    @State private var mythAnswer: Bool?

    private var caught: Int { model.count(of: germ.id) }
    private var finish: GermCardView.Finish { model.cardFinish(for: germ) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                statTiles
                notes
                doctorBanner
                bossSection
                mythSection
                deepDive
                history
                sources
                Text(HealthNotice.text)
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
        .sheet(isPresented: $showBossShare) {
            SharePreviewSheet(title: tr("Boss card")) {
                BossShareCard(germ: germ, survived: caught)
            }
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
                PillLabel(text: germ.rarity.label, foreground: germ.rarity.pillForeground, background: germ.rarity.pillBackground)
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
                        IconTile(symbol: item.element.icon, background: germ.lightTint, foreground: Color(hex: Swatch.night))
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

    /// The "when to call" advice as a list to go down, one sign at a time.
    private var doctorBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 13) {
                IconTile(symbol: "cross.case.fill", background: palette.coralDeep, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("When to call"))
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(germ.doctorLead.value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(germ.doctorSigns.enumerated()), id: \.offset) { item in
                    let checked = checkedSigns.contains(item.offset)
                    Button {
                        Haptics.tap()
                        if checked {
                            checkedSigns.remove(item.offset)
                        } else {
                            checkedSigns.insert(item.offset)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(checked ? palette.coralDeep : palette.inkTertiary)
                            Text(item.element.value)
                                .font(.subheadline)
                                .foregroundStyle(palette.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(checked ? .isSelected : [])
                }
            }
            if let note = germ.doctorNote {
                Text(note.value)
                    .font(.subheadline)
                    .foregroundStyle(palette.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(tr("In an emergency, call your local emergency number."))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.coralInk)
            if let kid = germ.kidReference, let url = URL(string: kid.url) {
                Divider()
                Link(destination: url) {
                    HStack(spacing: 12) {
                        Image(systemName: "figure.and.child.holdinghands")
                            .font(.body.weight(.semibold))
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("Is it your kid?"))
                                .font(.subheadline.weight(.semibold))
                            Text(tr("Advice for children: %@", kid.name))
                                .font(.footnote)
                                .foregroundStyle(palette.inkSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(palette.inkTertiary)
                    }
                    .foregroundStyle(palette.ink)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.coral.opacity(palette.isDark ? 0.2 : 0.12),
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    /// The germ as a boss: a joke health bar, its signature move, and the weakness from its notes.
    private var bossSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Boss card"), trailing: germ.rarity.label)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(tr("HP"))
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(palette.ink)
                    ProgressView(value: Double(germ.rarity.bossHealth), total: 100)
                        .tint(palette.isDark ? germ.rarity.color : germ.rarity.inkColor)
                    Text(verbatim: String(germ.rarity.bossHealth))
                        .font(.footnote.weight(.heavy).monospacedDigit())
                        .foregroundStyle(palette.ink)
                }
                .accessibilityElement(children: .combine)
                bossRow(symbol: "bolt.fill", tint: palette.coralDeep, label: tr("Special attack"), text: germ.boss.attack.value)
                bossRow(symbol: "shield.lefthalf.filled", tint: palette.sky, label: tr("Weakness"), text: germ.boss.weakness.value)
                bossRow(symbol: "gift.fill", tint: palette.limeDeep, label: tr("Loot"),
                        text: tr("+%lld Sick Points", germ.rarity.basePoints))
                if caught > 0 {
                    Button {
                        showBossShare = true
                    } label: {
                        Label(tr("Share the boss card"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost, height: 44))
                }
            }
            .petriCard()
        }
    }

    private func bossRow(symbol: String, tint: Color, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            IconTile(symbol: symbol, background: tint, foreground: Color(hex: Swatch.night))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// One claim to judge, answered from the germ's own notes.
    private var mythSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Myth or fact?"))
            VStack(alignment: .leading, spacing: 12) {
                Text(germ.myth.claim.value)
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let answer = mythAnswer {
                    let right = answer == germ.myth.isTrue
                    Label {
                        Text(right ? tr("Right!") : tr("Not quite."))
                            .foregroundStyle(palette.ink)
                    } icon: {
                        Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(right ? palette.successInk : palette.coralDeep)
                    }
                    .font(.subheadline.weight(.bold))
                    Text((germ.myth.isTrue ? tr("Fact.") : tr("Myth.")) + " " + germ.myth.explanation.value)
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(spacing: 10) {
                        Button(tr("Myth")) {
                            answer(false)
                        }
                        .buttonStyle(PillButtonStyle(kind: .ghost, height: 46))
                        Button(tr("Fact")) {
                            answer(true)
                        }
                        .buttonStyle(PillButtonStyle(kind: .ink, height: 46))
                    }
                }
            }
            .petriCard()
        }
    }

    private func answer(_ value: Bool) {
        if value == germ.myth.isTrue { Haptics.success() } else { Haptics.tap() }
        withAnimation(.snappy) {
            mythAnswer = value
        }
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

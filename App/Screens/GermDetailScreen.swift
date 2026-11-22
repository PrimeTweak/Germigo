import SwiftUI

/// One germ's case file: the health sheet, always open, then the card and the parent's history with it.
struct GermDetailScreen: View {
    let germ: Germ
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showShare = false
    @State private var showBossShare = false
    @State private var checkedSigns: Set<Int> = []
    @State private var showsSigns = false
    @State private var mythAnswer: Bool?

    private var caught: Int { model.count(of: germ.id) }
    private var finish: GermCardView.Finish { model.cardFinish(for: germ) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GermHero(germ: germ, finish: finish, caught: caught)
                doctorBanner
                aboutSection
                symptomsSection
                timeline
                spreadSection
                helps
                quickFacts
                mythSection
                deepDive
                bossSection
                history
                sources
                Text(HealthNotice.text)
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, Spacing.page)
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
        .sheet(isPresented: $showBossShare) {
            SharePreviewSheet(title: tr("Boss card")) {
                BossShareCard(germ: germ, survived: caught)
            }
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        if let about = germ.about {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("What it is"))
                HStack(alignment: .top, spacing: 13) {
                    IconTile(symbol: "microbe.fill", size: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(about.value)
                            .font(.body)
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if let more = germ.aboutMore {
                            Text(more.value)
                                .font(.subheadline)
                                .foregroundStyle(palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .germilyCard()
            }
        }
    }

    @ViewBuilder
    private var symptomsSection: some View {
        if !germ.symptoms.isEmpty {
            let symptoms = germ.symptoms
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("Symptoms"), trailing: tr("What you'll feel"))
                VStack(alignment: .leading, spacing: 10) {
                    Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(Array(stride(from: 0, to: symptoms.count, by: 2)), id: \.self) { start in
                            GridRow {
                                symptomChip(symptoms[start])
                                if start + 1 < symptoms.count {
                                    symptomChip(symptoms[start + 1])
                                } else {
                                    Color.clear
                                        .gridCellUnsizedAxes([.horizontal, .vertical])
                                }
                            }
                        }
                    }
                    if let note = germ.symptomsNote {
                        Text(note.value)
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 2)
                    }
                }
                .germilyCard(padding: 12)
            }
        }
    }

    private func symptomChip(_ symptom: GermSymptom) -> some View {
        HStack(spacing: 9) {
            IconTile(symbol: symptom.icon, size: 32)
            Text(symptom.text.value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(palette.background, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
    }

    /// Exposure, first symptoms and length, from the timings in the notes.
    private var timeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Timeline"))
            VStack(alignment: .leading, spacing: 12) {
                TimelineTrack(split: TimelineTrack.split)
                HStack(alignment: .top, spacing: 0) {
                    timelineLabel(tr("Exposed"), tr("Day 0"), alignment: .leading)
                        .frame(width: TimelineTrack.split, alignment: .leading)
                    timelineLabel(tr("Symptoms start"), germ.showsUp.value, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    timelineLabel(tr("Lasts"), germ.lasts.value, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                Divider()
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        IncubationStripes()
                            .frame(width: 18, height: 8)
                            .clipShape(Capsule())
                        Text(tr("Incubating, no symptoms yet"))
                    }
                    HStack(spacing: 6) {
                        Capsule()
                            .fill(palette.accent)
                            .frame(width: 18, height: 8)
                        Text(tr("Sick"))
                    }
                }
                .font(.caption)
                .foregroundStyle(palette.inkSecondary)
            }
            .germilyCard()
        }
    }

    private func timelineLabel(_ title: String, _ value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
            Text(value)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.trailing, alignment == .leading ? 6 : 0)
    }

    @ViewBuilder
    private var spreadSection: some View {
        if !germ.spreads.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("How it spreads"))
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(germ.spreads.enumerated()), id: \.offset) { item in
                        if item.offset > 0 {
                            Divider()
                        }
                        HStack(alignment: .top, spacing: 13) {
                            IconTile(symbol: item.element.icon)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.element.title.value)
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let detail = item.element.detail {
                                    Text(detail.value)
                                        .font(.subheadline)
                                        .foregroundStyle(palette.inkSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    if let note = germ.spreadNote {
                        Divider()
                        Text(note.value)
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 16)
                .germilyCard(padding: 0)
            }
        }
    }

    private var helps: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("What helps"))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(germ.tips.enumerated()), id: \.offset) { item in
                    if item.offset > 0 {
                        Divider()
                    }
                    HStack(alignment: .top, spacing: 13) {
                        IconTile(symbol: item.element.icon)
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
            .germilyCard(padding: 0)
        }
    }

    private var quickFacts: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Quick facts"))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(germ.facts.enumerated()), id: \.offset) { item in
                    if item.offset > 0 {
                        Divider()
                    }
                    HStack(alignment: .top, spacing: 13) {
                        IconTile(symbol: item.element.icon)
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
            .germilyCard(padding: 0)
        }
    }

    /// The "when to call" advice, right under the hero: one row that opens on the signs to go down.
    private var doctorBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                Haptics.tap()
                withAnimation(Tempo.quick) {
                    showsSigns.toggle()
                }
            } label: {
                HStack(spacing: 13) {
                    IconTile(symbol: "stethoscope", size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("When to call"))
                            .font(.headline)
                            .foregroundStyle(palette.ink)
                        Text(showsSigns ? germ.doctorLead.value
                                        : trCount(germ.doctorSigns.count, one: "%lld sign to watch for", other: "%lld signs to watch for"))
                            .font(.subheadline.weight(showsSigns ? .semibold : .regular))
                            .foregroundStyle(palette.ink.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(palette.inkSecondary)
                        .rotationEffect(.degrees(showsSigns ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(showsSigns ? tr("Hides the signs") : tr("Shows the signs"))
            if showsSigns {
                signs
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.accent.opacity(palette.isDark ? 0.2 : 0.12),
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    /// The signs to check off, the note, the emergency line and the page that covers children.
    @ViewBuilder
    private var signs: some View {
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
                            .foregroundStyle(checked ? palette.accent : palette.inkTertiary)
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
            .foregroundStyle(palette.ink)
        if let kid = germ.kidReference, let url = kid.link {
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

    /// The germ as a boss: a joke health bar, the fight in phases, and the weakness from its notes.
    private var bossSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Boss card"), trailing: germ.rarity.label)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(tr("HP"))
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(palette.ink)
                    ProgressView(value: Double(germ.rarity.bossHealth), total: 100)
                        .tint(palette.isDark ? germ.rarity.color : germ.rarity.inkColor)
                    Text(verbatim: String(germ.rarity.bossHealth))
                        .font(.footnote.weight(.bold).monospacedDigit())
                        .foregroundStyle(palette.ink)
                }
                .accessibilityElement(children: .combine)
                ForEach(Array(germ.bossPhases.enumerated()), id: \.offset) { item in
                    phaseRow(number: item.offset + 1, phase: item.element)
                }
                bossRow(symbol: "shield.lefthalf.filled", label: tr("Weakness"), text: germ.boss.weakness.value)
                bossRow(symbol: "gift.fill", label: tr("Loot"),
                        text: tr("+%lld Sick Points", germ.rarity.basePoints))
                if caught > 0 {
                    ShareCapsule(title: tr("Share the boss card")) {
                        showBossShare = true
                    }
                }
            }
            .germilyCard()
        }
    }

    private func phaseRow(number: Int, phase: BossPhase) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(verbatim: String(number))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.onAccent)
                .frame(width: 32, height: 32)
                .background(palette.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Text(phase.detail)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tr("Phase %1$lld: %2$@. %3$@", number, phase.name, phase.detail))
    }

    private func bossRow(symbol: String, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            IconTile(symbol: symbol)
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
                            .foregroundStyle(right ? palette.accent : palette.accent)
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
            .germilyCard()
        }
    }

    private func answer(_ value: Bool) {
        if value == germ.myth.isTrue { Haptics.success() } else { Haptics.tap() }
        withAnimation(Tempo.quick) {
            mythAnswer = value
        }
    }

    @ViewBuilder
    private var deepDive: some View {
        if !germ.deepDive.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("Deep dive"))
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(germ.deepDive.enumerated()), id: \.offset) { item in
                        Text(item.element.value)
                            .font(.callout)
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .germilyCard()
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
                .germilyCard(padding: 0)
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
                if let url = item.element.link {
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
        .germilyCard(padding: 0)
    }
}

/// The exposure-to-recovery bar: striped while incubating, coral while sick.
private struct TimelineTrack: View {
    static let split: CGFloat = 92
    let split: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(spacing: 0) {
                IncubationStripes()
                    .frame(width: split)
                LinearGradient(colors: [palette.accent, palette.accent.opacity(0.35)],
                               startPoint: .leading, endPoint: .trailing)
            }
            .frame(height: 12)
            .clipShape(Capsule())
            .padding(.horizontal, 8)
            HStack(spacing: 0) {
                dot(palette.ink)
                Color.clear
                    .frame(width: max(0, split - 22))
                dot(palette.accent)
                Spacer(minLength: 0)
                dot(palette.inkTertiary)
            }
        }
        .frame(height: 22)
        .accessibilityHidden(true)
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay {
                Circle().stroke(palette.surface, lineWidth: 4)
            }
    }
}

/// Diagonal stripes for the time a germ incubates without symptoms.
private struct IncubationStripes: View {
    @Environment(\.palette) private var palette

    var body: some View {
        let base = palette.ink.opacity(0.08)
        let stripe = palette.ink.opacity(0.2)
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(base))
            var x = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + 3, y: 0))
                path.addLine(to: CGPoint(x: x + 3, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(stripe))
                x += 8
            }
        }
        .accessibilityHidden(true)
    }
}

/// The head of a case file: the card, the illness, its rarity and how often it was caught.
struct GermHero: View {
    let germ: Germ
    var finish = GermCardView.Finish.standard
    let caught: Int
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 16) {
            LivelyCharacter(mood: germ.restMood) {
                GermCardView(germ: germ, width: 104, finish: finish, count: caught)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(germ.illness.value)
                    .font(.title.weight(.bold))
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(germ.scientific.value)
                    .font(.subheadline.italic())
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    PillLabel(text: germ.rarity.label, foreground: germ.rarity.pillForeground, background: germ.rarity.pillBackground)
                    PillLabel(text: tr("Card %@", germ.numberLabel), foreground: palette.ink,
                              background: palette.ink.opacity(0.08))
                }
                Text(caught > 0 ? tr("%1$@ · caught %2$@", germ.name, trCount(caught, one: "%lld time", other: "%lld times"))
                                : tr("Not caught yet"))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background {
            ZStack {
                LinearGradient(colors: [germ.lightTint.opacity(0.55), germ.lightTint.opacity(0.15)],
                               startPoint: .top, endPoint: .bottom)
                RingsBackground(color: Color.white.opacity(palette.isDark ? 0.06 : 0.5), spacing: 26)
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        }
    }
}

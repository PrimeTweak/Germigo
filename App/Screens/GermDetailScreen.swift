import SwiftUI

/// One germ's case file: in short, how it travels, what helps and the life of a germ, then its myths, its boss card,
/// the parent's history with it, when to call and the sources.
struct GermDetailScreen: View {
    let germ: Germ
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showShare = false
    @State private var showBossShare = false
    @State private var checkedSigns: Set<Int> = []
    @State private var showsSigns = false
    @AppStorage(GuideKeys.myths) private var mythsText = ""

    private var caught: Int { model.count(of: germ.id) }
    private var finish: GermCardView.Finish { model.cardFinish(for: germ) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GermHero(germ: germ, finish: finish, caught: caught)
                inShort
                symptomsSection
                spreadSection
                helps
                lifeOfAGerm
                mythSection
                bossSection
                history
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: tr("Good to know"))
                    doctorBanner
                }
                sources
                HealthLineNote()
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

    /// What it is, when it shows up and how long it lasts, in one card.
    private var inShort: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("In short"))
            VStack(alignment: .leading, spacing: 14) {
                if let about = germ.about {
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
                HStack(alignment: .bottom, spacing: 12) {
                    timelineEnd(tr("Shows up"), germ.showsUp.value, alignment: .leading)
                    Capsule()
                        .fill(LinearGradient(colors: [palette.accent.opacity(0.3), palette.accent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(minWidth: 32, maxWidth: .infinity)
                        .frame(height: 6)
                        .padding(.bottom, 8)
                        .accessibilityHidden(true)
                    timelineEnd(tr("Lasts"), germ.lasts.value, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
            }
            .germilyCard()
        }
    }

    private func timelineEnd(_ title: String, _ value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            Text(title)
                .font(.caption)
                .foregroundStyle(palette.inkSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 136, alignment: alignment == .trailing ? .trailing : .leading)
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

    /// How it travels, one way per line.
    @ViewBuilder
    private var spreadSection: some View {
        if !germ.spreads.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: tr("How it travels"))
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(germ.spreads.enumerated()), id: \.offset) { item in
                        HStack(alignment: .top, spacing: 13) {
                            IconTile(symbol: item.element.icon, size: 32, tint: palette.accent)
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
                            .padding(.top, 5)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if let note = germ.spreadNote {
                        Text(note.value)
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 4)
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

    /// The facts as big colored cards, the first across, the next two side by side, then the deep dive.
    private var lifeOfAGerm: some View {
        let facts = germ.facts
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Life of a germ"))
            if let first = facts.first {
                factCard(first, tone: 0, large: true)
            }
            if facts.count > 1 {
                Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                    ForEach(Array(stride(from: 1, to: facts.count, by: 2)), id: \.self) { start in
                        GridRow {
                            factCard(facts[start], tone: start, large: false)
                            if start + 1 < facts.count {
                                factCard(facts[start + 1], tone: start + 1, large: false)
                            } else {
                                Color.clear
                                    .gridCellUnsizedAxes([.horizontal, .vertical])
                            }
                        }
                    }
                }
            }
            ForEach(Array(germ.deepDive.enumerated()), id: \.offset) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Label(tr("Did you know?"), systemImage: "lightbulb.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(palette.accent)
                    Text(item.element.value)
                        .font(.callout)
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .germilyCard()
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The three soft colors the fact cards take turns with.
    private static let factTones: [UInt32] = [Swatch.lilac, Swatch.gold, Swatch.sky]

    private func factCard(_ fact: GermFact, tone: Int, large: Bool) -> some View {
        let color = Color(hex: Self.factTones[tone % Self.factTones.count])
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: fact.icon)
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
                Text(fact.label.value)
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.leading)
            }
            .foregroundStyle(palette.inkSecondary)
            Text(fact.value.value)
                .font(large ? .title3.weight(.bold) : .headline)
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(color.opacity(palette.isDark ? 0.22 : 0.2),
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// The "when to call" advice: one row that opens on the signs to go down.
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
        if let kid = germ.parentReference, let url = kid.link {
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

    /// The germ's claims to judge, answered from its own notes. Each answer joins the myth busters.
    private var mythSection: some View {
        let answers = MythAnswers(mythsText)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Myth or fact?"))
            ForEach(germ.mythCards) { myth in
                mythCard(myth, right: answers.right(myth.id))
            }
        }
    }

    private func mythCard(_ myth: Myth, right: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(myth.claim)
                .font(.headline)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, right == nil ? 0 : 70)
            if let right {
                Label {
                    Text(right ? tr("Right!") : tr("Not quite."))
                        .foregroundStyle(palette.ink)
                } icon: {
                    Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(palette.accent)
                }
                .font(.subheadline.weight(.bold))
                Text(myth.explanation)
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 10) {
                    Button(tr("Myth")) {
                        answer(myth, fact: false)
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost, height: 46))
                    Button(tr("Fact")) {
                        answer(myth, fact: true)
                    }
                    .buttonStyle(PillButtonStyle(kind: .ink, height: 46))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.accent.opacity(palette.isDark ? 0.2 : 0.1),
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if right != nil {
                MythStamp(isTrue: myth.isTrue)
                    .padding(12)
                    .motionTransition(.scale)
            }
        }
    }

    private func answer(_ myth: Myth, fact: Bool) {
        let right = fact == myth.isTrue
        if right { Haptics.success() } else { Haptics.tap() }
        var answers = MythAnswers(mythsText)
        answers.record(myth.id, right: right)
        withAnimation(Tempo.pop) {
            mythsText = answers.text
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
                SourceList(references: germ.sources, reviewedOn: germ.reviewedOn)
            }
        }
    }
}

/// Tappable references for a germ or an article, and the month a health professional reviewed it.
struct SourceList: View {
    let references: [GermReference]
    var reviewedOn: String?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            list
            if let text = reviewedOn, let day = LessonEngine.calendarDay(text) {
                Label(tr("Reviewed %@", day.formatted(.dateTime.month(.abbreviated).year())), systemImage: "checkmark.seal")
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var list: some View {
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

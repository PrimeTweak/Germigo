import SwiftUI

/// A shelf of the Guide: the illnesses of one part of the body.
enum GuideShelf: String, Hashable, CaseIterable, Identifiable {
    case airways
    case skin
    case gut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .airways: return tr("Nose, throat and lungs")
        case .skin: return tr("Skin, eyes and hair")
        case .gut: return tr("Tummy and others")
        }
    }

    /// The germ families shelved here, in reading order.
    private var families: [GermFamily] {
        switch self {
        case .airways: return [.airways]
        case .skin: return [.skin]
        case .gut: return [.gut, .other]
        }
    }

    /// The shelf's germs: family by family, the everyday ones first, then in album order.
    func germs(in catalog: [Germ]) -> [Germ] {
        families.flatMap { family in
            let members = catalog.filter { $0.family == family }
            return members.filter { $0.quickPick } + members.filter { !$0.quickPick }
        }
    }
}

/// Where the Guide remembers what it has already shown: the weekly unmasking, the caught germs
/// revealed, and the answer to the myth of the week.
enum GuideKeys {
    static let revealedWeek = "lab.revealedWeek"
    static let revealedGerms = "guide.revealedGerms"
    static let mythWeek = "guide.mythWeek"
    static let mythAnswer = "guide.mythAnswer"
}

/// The Guide tab: a search over illnesses and lessons, the daily quiz, what is new this week,
/// every illness shelved by part of the body, then the lessons.
struct LabScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .footnote) private var tileWidth: CGFloat = 88
    @State private var showQuiz = false
    @State private var query = ""

    private var needle: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if needle.isEmpty {
                        home
                    } else {
                        results
                    }
                    Text(HealthNotice.text)
                        .font(.footnote)
                        .foregroundStyle(palette.inkTertiary)
                        .padding(.horizontal, 4)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(CharacterWash(tint: TabWash.lab))
            .navigationTitle(tr("Guide"))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: tr("Search an illness or a lesson"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SettingsButton()
                }
            }
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleScreen(article: article)
            }
            .navigationDestination(for: GuideShelf.self) { shelf in
                ShelfScreen(shelf: shelf)
            }
            .fullScreenCover(isPresented: $showQuiz) {
                QuizScreen()
            }
        }
    }

    @ViewBuilder
    private var home: some View {
        let germs = model.catalog.germs
        let studied = model.studiedGermIDs
        QuizBanner(showQuiz: $showQuiz)
        SectionHeader(title: tr("This week"))
        WeekShelf()
        SectionHeader(title: tr("Illnesses"),
                      trailing: tr("%1$lld of %2$lld caught", model.caughtGermIDs.count, germs.count))
        if let sample = germs.first {
            GuideLegend(sample: sample)
        }
        ForEach(GuideShelf.allCases) { shelf in
            shelfRow(shelf, germs: shelf.germs(in: germs), studied: studied)
        }
        lessons
        extras
    }

    /// One shelf: its name and count, which open the whole shelf, then its tiles in a row to swipe.
    private func shelfRow(_ shelf: GuideShelf, germs: [Germ], studied: Set<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            NavigationLink(value: shelf) {
                HStack(spacing: 4) {
                    Text(shelf.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(palette.ink)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Text(verbatim: "\(germs.count)")
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.inkTertiary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, 4)
                .frame(minHeight: 32)
                .hitTarget(height: 32)
            }
            .buttonStyle(.plain)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(germs) { germ in
                        NavigationLink(value: germ) {
                            GuideTile(germ: germ, count: model.count(of: germ.id), studied: studied.contains(germ.id))
                                .frame(width: min(tileWidth, 128))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollIndicators(.hidden)
            .padding(.horizontal, -20)
        }
        .padding(.top, 2)
    }

    /// The next three lessons to read, and the way to all of them.
    @ViewBuilder
    private var lessons: some View {
        let all = model.lessonsToRead()
        if !all.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text(tr("Lessons"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.ink)
                Spacer()
                NavigationLink {
                    LessonsScreen()
                } label: {
                    HStack(spacing: 4) {
                        Text(tr("See all %lld", all.count))
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(palette.inkSecondary)
                    .hitTarget(height: 20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            .padding(.top, 8)
            LessonCard(articles: Array(all.prefix(3)))
        }
    }

    /// What is worth having at hand: the help lines.
    @ViewBuilder
    private var extras: some View {
        SectionHeader(title: tr("Good to have"))
        NavigationLink {
            HelpLinesScreen()
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: "phone.fill", size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Help lines"))
                        .font(.body)
                        .foregroundStyle(palette.ink)
                    Text(tr("Emergency and health lines"))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                RowChevron()
            }
            .frame(minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .germigoCard(padding: 0)
    }

    /// What the search finds, among the illnesses and the lessons.
    @ViewBuilder
    private var results: some View {
        let germs = model.catalog.germs.filter { germ in
            [germ.illness.value, germ.name, germ.scientific.value].contains { $0.localizedStandardContains(needle) }
        }
        let found = model.catalog.articles.filter { article in
            article.title.value.localizedStandardContains(needle) || article.summary.value.localizedStandardContains(needle)
        }
        if germs.isEmpty && found.isEmpty {
            Text(tr("Nothing matches your search."))
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 12)
        }
        if !germs.isEmpty {
            SectionHeader(title: tr("Illnesses"))
            GuideGrid(germs: germs)
        }
        if !found.isEmpty {
            SectionHeader(title: tr("Lessons"))
            LessonCard(articles: found)
        }
    }
}

/// One whole shelf of the Guide, as a grid.
struct ShelfScreen: View {
    let shelf: GuideShelf
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let germs = model.catalog.germs
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let sample = germs.first {
                    GuideLegend(sample: sample)
                }
                GuideGrid(germs: shelf.germs(in: germs))
                Text(HealthNotice.text)
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(shelf.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Germ {
    /// The quiet tint behind a caught germ: its pale tint by day, a deep wash of it by night.
    func tileTint(_ palette: Palette) -> Color {
        palette.isDark ? deepTint.opacity(0.3) : lightTint
    }
}

/// What the three looks of a tile mean. Each tile says its own state to VoiceOver.
private struct GuideLegend: View {
    let sample: Germ
    @Environment(\.palette) private var palette

    var body: some View {
        ChipRows(spacing: 12) {
            entry(tr("Not met yet"), known: false, tinted: false)
            entry(tr("Studied in the quiz"), known: true, tinted: false)
            entry(tr("Caught"), known: true, tinted: true)
        }
        .padding(.horizontal, 4)
        .accessibilityHidden(true)
    }

    private func entry(_ title: String, known: Bool, tinted: Bool) -> some View {
        HStack(spacing: 6) {
            GermImage(germ: sample, size: 18, silhouette: !known)
                .foregroundStyle(palette.ink.opacity(palette.isDark ? 0.24 : 0.16))
                .frame(width: 24, height: 24)
                .background(tinted ? sample.tileTint(palette) : palette.surface,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
        }
    }
}

/// Illness tiles in a grid, for a whole shelf or for what the search finds.
private struct GuideGrid: View {
    let germs: [Germ]
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .footnote) private var tileWidth: CGFloat = 88

    var body: some View {
        let studied = model.studiedGermIDs
        let column = GridItem(.adaptive(minimum: min(tileWidth, 128)), spacing: 12, alignment: .top)
        LazyVGrid(columns: [column], alignment: .leading, spacing: 18) {
            ForEach(germs) { germ in
                NavigationLink(value: germ) {
                    GuideTile(germ: germ, count: model.count(of: germ.id), studied: studied.contains(germ.id))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
    }
}

/// One illness in the Guide: a gray shape until it is met, in color once studied in the quiz,
/// on its tint with a badge once caught. A caught germ pops out of the gray the first time it is seen.
private struct GuideTile: View {
    let germ: Germ
    let count: Int
    let studied: Bool
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(GuideKeys.revealedGerms) private var revealedList = ""
    @State private var onScreen = false
    /// True while a caught germ waits under its gray shape for its reveal.
    @State private var masked = false

    /// Set once any tile hears from its scroll view, which tells an unseen tile from a silent scroll view.
    private static var visibilityReported = false
    /// One chime for germs revealed together.
    private static var lastChime = Date.distantPast

    private var caught: Bool { count > 0 }
    private var revealed: Bool { revealedList.split(separator: ",").contains { $0 == germ.id } }
    private var pending: Bool { caught && !revealed }
    private var tinted: Bool { caught && !masked }
    private var known: Bool { studied || tinted }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tinted ? germ.tileTint(palette) : palette.surface)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        GermImage(germ: germ, size: proxy.size.width * 0.76, silhouette: !known)
                            .foregroundStyle(palette.ink.opacity(palette.isDark ? 0.2 : 0.13))
                            .scaleEffect(masked ? 0.8 : 1)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if tinted {
                        badge
                            .offset(x: 8, y: -8)
                            .motionTransition(.scale)
                    }
                }
            Text(germ.illness.value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.leading)
                .padding(.top, 7)
            Text(germ.name)
                .font(.caption)
                .foregroundStyle(palette.inkSecondary)
                .lineLimit(1)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(caught ? tr("Caught") : (studied ? tr("Studied in the quiz") : tr("Not met yet")))
        .onAppear {
            if pending && !reduceMotion { masked = true }
        }
        .onScrollVisibilityChange(threshold: 0.2) { visible in
            Self.visibilityReported = true
            onScreen = visible
        }
        .task(id: caught && onScreen) {
            await reveal()
        }
        .task(id: masked) {
            await release()
        }
    }

    /// A check for one catch, the count from the second one on, ringed in the page color.
    private var badge: some View {
        Group {
            if count > 1 {
                Text(verbatim: "×\(count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 7)
            } else {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.heavy))
            }
        }
        .foregroundStyle(palette.onAccent)
        .frame(minWidth: 24, minHeight: 24)
        .background(palette.accent, in: Capsule())
        .padding(3)
        .background(palette.background, in: Capsule())
    }

    /// The first time a caught germ is seen: a moment under its gray shape, then it pops out on its tint.
    private func reveal() async {
        guard pending, onScreen else { return }
        guard !reduceMotion else {
            markRevealed()
            return
        }
        masked = true
        try? await Task.sleep(nanoseconds: 600_000_000)
        guard !Task.isCancelled else { return }
        markRevealed()
        withAnimation(Tempo.pop) {
            masked = false
        }
        Haptics.tap()
        if Date().timeIntervalSince(Self.lastChime) > 1 {
            Self.lastChime = Date()
            SoundPlayer.shared.play(.reveal)
        }
    }

    /// A caught germ never stays gray: left unseen for a few seconds, it takes its colors back and keeps
    /// its reveal for later. When no scroll view reports at all, the reveal is spent instead.
    private func release() async {
        guard masked else { return }
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        guard !Task.isCancelled, masked else { return }
        if !Self.visibilityReported { markRevealed() }
        withAnimation(Tempo.quick) {
            masked = false
        }
    }

    private func markRevealed() {
        guard !revealed else { return }
        revealedList = revealedList.isEmpty ? germ.id : revealedList + "," + germ.id
    }
}

/// The daily quiz as a banner: the mascot, the streak, what the quiz pays and the way in.
private struct QuizBanner: View {
    @Binding var showQuiz: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    private var ground: Color {
        palette.isDark ? Color(hex: Swatch.irisDeep) : palette.accent
    }

    var body: some View {
        let plan = model.quizPlan()
        let answers = model.quizAnswers()
        let done = model.quizDone()
        let rightToday = zip(plan, answers).filter { $0.0.answer == $0.1 }.count
        let points = (done ? rightToday : plan.count) * RewardEngine.quizAnswerPoints
        let streak = model.labStreak()
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(done ? tr("Done for today") : tr("Daily quiz"))
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption.weight(.bold))
                    Text(trCount(streak, one: "%lld day", other: "%lld days") + " · " + tr("+%lld pts", points))
                        .font(.subheadline)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .opacity(0.92)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(trCount(streak, one: "Quiz streak: %lld day", other: "Quiz streak: %lld days")
                                    + ", " + tr("+%lld pts", points))
                if done {
                    note(tr("%1$lld of %2$lld right. A new quiz tomorrow.", rightToday, plan.count))
                } else if model.onSickLeave {
                    note(tr("Sick leave: your streak waits for you."))
                }
            }
            Spacer(minLength: 0)
            if !done {
                Button {
                    showQuiz = true
                } label: {
                    Text(answers.isEmpty ? tr("Start") : tr("Keep going"))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(ground)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(PressableStyle())
            }
        }
        .foregroundStyle(Color.white)
        .padding(.leading, 80)
        .padding(.trailing, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(ground, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .topLeading) {
            LivelyCharacter(mood: done ? .resting : .stalking, phase: 1.3) {
                Image(done ? "mascot-asleep" : "mascot-awake")
                    .resizable()
                    .scaledToFit()
            }
            .frame(width: 70, height: 70)
            .rotationEffect(.degrees(-7))
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 6)
            .offset(x: 8, y: -12)
            .accessibilityHidden(true)
        }
        .padding(.top, 12)
        .animation(Tempo.quick, value: answers.count)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .opacity(0.92)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }
}

/// What is new this week, side by side: the germ of the week, a myth to judge, a lesson to open.
private struct WeekShelf: View {
    private static let mythAnchor = "myth"

    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .headline) private var cardWidth: CGFloat = 186
    @AppStorage(GuideKeys.mythWeek) private var answeredWeek = -1

    var body: some View {
        let now = Date()
        let week = QuizEngine.weekIndex(now)
        let germs = model.catalog.germs
        let width = min(cardWidth, 260)
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    if let germ = QuizEngine.germOfTheWeek(germs, now: now) {
                        NavigationLink(value: germ) {
                            WeekGermCard(germ: germ, week: week)
                                .frame(width: width)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    if let germ = QuizEngine.mythOfTheWeek(germs, now: now) {
                        WeekMythCard(germ: germ, week: week)
                            .frame(width: answeredWeek == week ? width * 1.45 : width)
                            .id(Self.mythAnchor)
                    }
                    if let article = model.lessonsToRead(now: now).first, !model.data.readArticles.contains(article.id) {
                        WeekLessonCard(article: article)
                            .frame(width: width)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollIndicators(.hidden)
            .padding(.horizontal, -20)
            .onChange(of: answeredWeek) {
                withAnimation(Tempo.quick) {
                    proxy.scrollTo(Self.mythAnchor, anchor: .center)
                }
            }
        }
    }
}

/// The frame shared by the cards of the week: as tall as the tallest one.
private struct WeekCardFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 126, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The germ of the week, in color on its tint. It unmasks itself the first time the Guide opens that week.
private struct WeekGermCard: View {
    let germ: Germ
    let week: Int
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(GuideKeys.revealedWeek) private var revealedWeek = -1

    private var unmasked: Bool { revealedWeek == week }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tr("Germ of the week"))
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.ink.opacity(0.72))
            Text(germ.illness.value)
                .font(.headline)
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            Text(germ.name)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .padding(.top, 2)
        }
        .modifier(WeekCardFrame())
        .background(alignment: .bottomTrailing) {
            LivelyCharacter(mood: germ.restMood, touch: nil) {
                GermImage(germ: germ, size: 72, silhouette: !unmasked)
                    .foregroundStyle(palette.ink.opacity(palette.isDark ? 0.2 : 0.13))
            }
            .scaleEffect(unmasked ? 1 : 0.8)
            .padding(.trailing, 6)
            .padding(.bottom, 4)
        }
        .background(unmasked ? germ.tileTint(palette) : palette.surface,
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .task {
            await reveal()
        }
    }

    /// The first time this week: a short pause on the gray shape, then the germ pops out in color.
    private func reveal() async {
        guard !unmasked else { return }
        if !reduceMotion {
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        guard !Task.isCancelled else { return }
        withAnimation(Tempo.pop) {
            revealedWeek = week
        }
        Haptics.tap()
    }
}

/// One claim a week to judge on the spot. The answer stays up until the next claim.
private struct WeekMythCard: View {
    let germ: Germ
    let week: Int
    @Environment(\.palette) private var palette
    @AppStorage(GuideKeys.mythWeek) private var answeredWeek = -1
    @AppStorage(GuideKeys.mythAnswer) private var answeredFact = false

    private var answer: Bool? {
        answeredWeek == week ? answeredFact : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tr("Myth or fact?"))
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent)
            Text(germ.myth.claim.value)
                .font(.callout.weight(.bold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            Spacer(minLength: 10)
            if let answer {
                verdict(answer)
            } else {
                HStack(spacing: 6) {
                    choice(tr("Myth"), value: false)
                    choice(tr("Fact"), value: true)
                }
            }
        }
        .modifier(WeekCardFrame())
        .background(palette.accent.opacity(palette.isDark ? 0.22 : 0.11),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(palette.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func verdict(_ answer: Bool) -> some View {
        let right = answer == germ.myth.isTrue
        return VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(right ? tr("Right!") : tr("Not quite."))
                    .foregroundStyle(palette.ink)
            } icon: {
                Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(palette.accent)
            }
            .font(.subheadline.weight(.bold))
            Text((germ.myth.isTrue ? tr("Fact.") : tr("Myth.")) + " " + germ.myth.explanation.value)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .transition(.opacity)
    }

    private func choice(_ title: String, value: Bool) -> some View {
        Button {
            if value == germ.myth.isTrue { Haptics.success() } else { Haptics.tap() }
            withAnimation(Tempo.quick) {
                answeredFact = value
                answeredWeek = week
            }
        } label: {
            Text(title)
                .font(.footnote.weight(.bold))
                .foregroundStyle(palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(palette.background, in: Capsule())
                .hitTarget(height: 30)
        }
        .buttonStyle(PressableStyle())
    }
}

/// The lesson to open next: new this week, ready to read, or the next one the quiz unlocks.
private struct WeekLessonCard: View {
    let article: Article
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let now = Date()
        let open = model.isArticleUnlocked(article, now: now)
        let fresh = LessonEngine.isOpenToAll(article, now: now)
        Group {
            if open {
                NavigationLink(value: article) {
                    card(open: open, fresh: fresh, now: now)
                }
            } else {
                NavigationLink {
                    LessonsScreen()
                } label: {
                    card(open: open, fresh: fresh, now: now)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private func card(open: Bool, fresh: Bool, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(fresh ? tr("New lesson") : (open ? tr("Lesson to read") : tr("Next lesson")))
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent)
            Text(article.title.value)
                .font(.headline)
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            if fresh {
                let left = LessonEngine.daysLeft(article, now: now)
                footer(trCount(left, one: "Open to all · %lld day", other: "Open to all · %lld days"), symbol: "clock")
                    .foregroundStyle(palette.accent)
            } else if !open {
                let remaining = max(1, article.unlockAtAnswers - model.data.quiz.rightTotal)
                footer(trCount(remaining, one: "%lld more right answer", other: "%lld more right answers"), symbol: "lock.fill")
                    .foregroundStyle(palette.inkSecondary)
            }
        }
        .modifier(WeekCardFrame())
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func footer(_ text: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: symbol)
                .accessibilityHidden(true)
            Text(text)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption.weight(.semibold))
        .padding(.top, 8)
    }
}

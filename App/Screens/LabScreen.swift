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

/// Without the Season Pass: what a holo card looks like, on the germ caught most, and the way to the offer.
private struct HoloPreview: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showPaywall = false

    var body: some View {
        if let germ = model.catalog.germs.max(by: { model.count(of: $0.id) < model.count(of: $1.id) }) {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 16) {
                    GermCardView(germ: germ, width: 64, finish: .holo)
                        .rotationEffect(.degrees(-5))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PassReason.holo.gain)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(palette.ink)
                        Text(PassReason.holo.detail)
                            .font(.subheadline)
                            .foregroundStyle(palette.inkSecondary)
                            .multilineTextAlignment(.leading)
                        PassOfferTag()
                            .padding(.top, 2)
                    }
                    Spacer(minLength: 0)
                }
                .germilyCard(padding: 14)
            }
            .buttonStyle(PressableStyle())
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: .holo)
            }
        }
    }
}

/// Where the Guide remembers what it has already shown: the weekly unmasking, the caught germs
/// booked, and every myth answered.
enum GuideKeys {
    static let revealedWeek = "lab.revealedWeek"
    static let revealedGerms = "guide.revealedGerms"
    static let myths = "guide.myths"
}

/// The Guide tab: a search over illnesses, myths and lessons, what is new this week, the daily quiz,
/// the microbe cards shelved by part of the body, the myths, the lessons, then the help lines.
struct LabScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @ScaledMetric(relativeTo: .footnote) private var tileWidth: CGFloat = 88
    @State private var showQuiz = false
    @State private var query = ""
    @State private var mythStart: MythStart?
    @AppStorage(GuideKeys.myths) private var mythsText = ""

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
                .padding(.horizontal, Spacing.page)
                .padding(.bottom, 28)
            }
            .background(CharacterWash(tint: TabWash.lab))
            .navigationTitle(tr("Guide"))
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: tr("Search an illness, a myth or a lesson"))
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
            .navigationDestination(for: GoingAroundReport.self) { report in
                GoingAroundScreen(report: report)
            }
            .fullScreenCover(isPresented: $showQuiz) {
                QuizScreen()
            }
            .fullScreenCover(item: $mythStart) { start in
                MythDeckScreen(start: start.id)
            }
        }
    }

    @ViewBuilder
    private var home: some View {
        let germs = model.catalog.germs
        SectionHeader(title: tr("This week"))
        WeekShelf()
        QuizBanner(showQuiz: $showQuiz)
        SectionHeader(title: tr("Microbe cards"),
                      trailing: tr("%1$lld of %2$lld caught", model.caughtGermIDs.count, germs.count))
        ForEach(GuideShelf.allCases) { shelf in
            shelfRow(shelf, germs: shelf.germs(in: germs))
        }
        if !model.hasPass {
            HoloPreview()
        }
        mythBusters(model.catalog.myths)
        lessons
        extras
    }

    /// One shelf: its name and count, which open the whole shelf, then its tiles in a row to swipe.
    private func shelfRow(_ shelf: GuideShelf, germs: [Germ]) -> some View {
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
                            GuideTile(germ: germ, count: model.count(of: germ.id))
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

    /// Every myth in a row, and the way into the deck at the first one not answered.
    @ViewBuilder
    private func mythBusters(_ myths: [Myth]) -> some View {
        if !myths.isEmpty {
            seeAllHeader(tr("Myth busters")) {
                Button {
                    let answers = MythAnswers(mythsText)
                    let first = myths.first { answers.right($0.id) == nil } ?? myths[0]
                    mythStart = MythStart(id: first.id)
                } label: {
                    seeAllLabel(count: myths.count)
                }
            }
            MythShelf(myths: myths) { id in
                mythStart = MythStart(id: id)
            }
        }
    }

    /// The next three lessons to read, and the way to all of them.
    @ViewBuilder
    private var lessons: some View {
        let all = model.lessonsToRead()
        if !all.isEmpty {
            seeAllHeader(tr("Understand")) {
                NavigationLink {
                    LessonsScreen()
                } label: {
                    seeAllLabel(count: all.count)
                }
            }
            LessonCard(articles: Array(all.prefix(3)))
        }
    }

    private func seeAllHeader<Action: View>(_ title: String, @ViewBuilder link: () -> Action) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.ink)
            Spacer()
            link()
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }

    private func seeAllLabel(count: Int) -> some View {
        HStack(spacing: 4) {
            Text(tr("See all %lld", count))
                .font(.subheadline)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(palette.inkSecondary)
        .hitTarget(height: 20)
    }

    /// What is worth having at hand: the help lines, and who to ask when unsure.
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
        .germilyCard(padding: 0)
        HealthLineNote()
    }

    /// What the search finds: illnesses by any of their names, myths by their claim, lessons by title or summary.
    @ViewBuilder
    private var results: some View {
        let germs = model.catalog.germs.filter { $0.matches(needle) }
        let myths = model.catalog.myths.filter { $0.claim.localizedStandardContains(needle) }
        let found = model.catalog.articles.filter { article in
            article.title.value.localizedStandardContains(needle) || article.summary.value.localizedStandardContains(needle)
        }
        if germs.isEmpty && myths.isEmpty && found.isEmpty {
            Text(tr("Nothing matches your search."))
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 12)
        }
        if !germs.isEmpty {
            SectionHeader(title: tr("Microbe cards"))
            GuideGrid(germs: germs)
        }
        if !myths.isEmpty {
            SectionHeader(title: tr("Myth busters"))
            MythShelf(myths: myths) { id in
                mythStart = MythStart(id: id)
            }
        }
        if !found.isEmpty {
            SectionHeader(title: tr("Understand"))
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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GuideGrid(germs: shelf.germs(in: model.catalog.germs))
                HealthLineNote()
                Text(HealthNotice.text)
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(shelf.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Germ {
    /// The quiet tint behind a germ: its pale tint by day, a deep wash of it by night.
    func tileTint(_ palette: Palette) -> Color {
        palette.isDark ? deepTint.opacity(0.3) : lightTint
    }
}

/// Illness tiles in a grid, for a whole shelf or for what the search finds.
private struct GuideGrid: View {
    let germs: [Germ]
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .footnote) private var tileWidth: CGFloat = 88

    var body: some View {
        let column = GridItem(.adaptive(minimum: min(tileWidth, 128)), spacing: 12, alignment: .top)
        LazyVGrid(columns: [column], alignment: .leading, spacing: 18) {
            ForEach(germs) { germ in
                NavigationLink(value: germ) {
                    GuideTile(germ: germ, count: model.count(of: germ.id))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 10)
    }
}

/// One microbe card: in color on its tint, and booked like a mugshot once caught, with the catches
/// tallied on its plate. The first time a caught germ is seen, a camera flash books it.
private struct GuideTile: View {
    let germ: Germ
    let count: Int
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(GuideKeys.revealedGerms) private var revealedList = ""
    @State private var onScreen = false
    /// True while a caught germ waits on its plain card for its booking.
    @State private var masked = false
    @State private var flash = false

    /// Set once any tile hears from its scroll view, which tells an unseen tile from a silent scroll view.
    private static var visibilityReported = false
    /// One chime for germs booked together.
    private static var lastChime = Date.distantPast

    private var caught: Bool { count > 0 }
    private var revealed: Bool { revealedList.split(separator: ",").contains { $0 == germ.id } }
    private var pending: Bool { caught && !revealed }
    private var booked: Bool { caught && !masked }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            card
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
        .accessibilityValue(caught ? trCount(count, one: "Caught %lld time", other: "Caught %lld times")
                                   : tr("Not caught yet"))
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

    private var card: some View {
        MicrobeCard(germ: germ, count: booked ? count : 0)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .fill(Color.white)
                    .opacity(flash ? 0.95 : 0)
                    .allowsHitTesting(false)
            }
    }

    /// The first time a caught germ is seen: a moment on its plain card, then a camera flash and its mugshot.
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
        flash = true
        masked = false
        Haptics.tap()
        if Date().timeIntervalSince(Self.lastChime) > 1 {
            Self.lastChime = Date()
            SoundPlayer.shared.play(.reveal)
        }
        try? await Task.sleep(nanoseconds: 70_000_000)
        withAnimation(Tempo.settle) {
            flash = false
        }
    }

    /// A caught germ never waits long: left unseen for a few seconds, it gets its mugshot and keeps
    /// its booking for later. When no scroll view reports at all, the booking is spent instead.
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

/// A microbe card's picture: the germ in color on its tint, or booked as a mugshot once caught.
struct MicrobeCard: View {
    let germ: Germ
    let count: Int
    @Environment(\.palette) private var palette

    var body: some View {
        if count > 0 {
            Mugshot(germ: germ, count: count)
        } else {
            GeometryReader { proxy in
                let side = proxy.size.width
                let shape = RoundedRectangle(cornerRadius: side * 0.27, style: .continuous)
                shape
                    .fill(germ.tileTint(palette))
                    .overlay {
                        GermImage(germ: germ, size: side * 0.74)
                    }
                    .overlay {
                        shape.strokeBorder(germ.deepTint.opacity(palette.isDark ? 0.3 : 0.22), lineWidth: 1)
                    }
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }
}

/// A caught germ booked like a mugshot: the height wall, the germ raised a little, its catches tallied on the plate.
struct Mugshot: View {
    let germ: Germ
    let count: Int
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let side = proxy.size.width
            let shape = RoundedRectangle(cornerRadius: side * 0.27, style: .continuous)
            ZStack {
                MugshotWall()
                GermImage(germ: germ, size: side * 0.6)
                    .offset(y: -side * 0.09)
                CatchPlate(count: count)
                    .scaleEffect(min(1, side / 88), anchor: .bottom)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, side * 0.08)
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(palette.ink.opacity(0.12), lineWidth: 1)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The wall behind a mugshot: chalk with the height lines, marked 4, 3 and 2.
private struct MugshotWall: View {
    @Environment(\.palette) private var palette

    var body: some View {
        let ground = palette.isDark ? Color(hex: Swatch.navyRaised) : Color(hex: Swatch.chalk)
        let ink = palette.isDark ? Color(hex: Swatch.frost) : Color(hex: Swatch.ink)
        Canvas { context, size in
            for (index, mark) in ["4", "3", "2"].enumerated() {
                let y = size.height * (0.17 + 0.18 * CGFloat(index))
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(ink.opacity(0.13)), lineWidth: 1)
                let label = context.resolve(Text(verbatim: mark)
                    .font(.system(size: max(6, size.width * 0.08), weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.32)))
                context.draw(label, at: CGPoint(x: size.width * 0.07, y: y - 1), anchor: .bottomLeading)
            }
        }
        .background(ground)
        .accessibilityHidden(true)
    }
}

/// The booking plate under a mugshot: one stick per catch, the fifth crossing the four, then the number.
private struct CatchPlate: View {
    let count: Int

    var body: some View {
        Group {
            if count > 5 {
                Text(verbatim: "×\(count)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
            } else {
                TallyMarks(count: count)
            }
        }
        .frame(minWidth: 34, minHeight: 17)
        .padding(.horizontal, 5)
        .background(Color(hex: Swatch.night), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Up to four sticks, struck through in gold at five.
private struct TallyMarks: View {
    let count: Int

    var body: some View {
        let sticks = min(count, 4)
        HStack(spacing: 3) {
            ForEach(0..<sticks, id: \.self) { _ in
                Capsule()
                    .fill(Color.white)
                    .frame(width: 2.2, height: 11)
            }
        }
        .overlay {
            if count >= 5 {
                Capsule()
                    .fill(Color(hex: Swatch.goldFoil))
                    .frame(width: CGFloat(sticks) * 5.2 + 6, height: 2.2)
                    .rotationEffect(.degrees(-24))
            }
        }
    }
}

/// The daily quiz as a slim bar: the mascot, what today's quiz holds, the streak and the way in.
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
        let streak = model.labStreak()
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(done ? tr("Done for today") : tr("Daily quiz"))
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail(plan: plan.count, rightToday: rightToday, done: done))
                    .font(.footnote)
                    .monospacedDigit()
                    .opacity(0.92)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.bold))
                Text(verbatim: "\(streak)")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }
            .foregroundStyle(Color(hex: Swatch.goldFoil))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(trCount(streak, one: "Quiz streak: %lld day", other: "Quiz streak: %lld days"))
            if !done {
                Button {
                    showQuiz = true
                } label: {
                    Text(answers.isEmpty ? tr("Start") : tr("Keep going"))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(ground)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Color.white, in: Capsule())
                        .hitTarget(height: 38)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .foregroundStyle(Color.white)
        .padding(.leading, 66)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(ground, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay(alignment: .topLeading) {
            LivelyCharacter(mood: done ? .resting : .stalking, phase: 1.3) {
                Image(done ? "mascot-asleep" : "mascot-awake")
                    .resizable()
                    .scaledToFit()
            }
            .frame(width: 56, height: 56)
            .rotationEffect(.degrees(-7))
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 6)
            .offset(x: 6, y: -8)
            .accessibilityHidden(true)
        }
        .padding(.top, 6)
        .animation(Tempo.quick, value: answers.count)
    }

    private func detail(plan: Int, rightToday: Int, done: Bool) -> String {
        if done { return tr("%1$lld of %2$lld right. A new quiz tomorrow.", rightToday, plan) }
        if model.onSickLeave { return tr("Sick leave: your streak waits for you.") }
        return trCount(plan, one: "%lld question", other: "%lld questions") + " · "
            + tr("+%lld pts", plan * RewardEngine.quizAnswerPoints)
    }
}

/// What is new this week, side by side: what is going around, a myth to judge, a lesson to open, the germ of the week.
private struct WeekShelf: View {
    private static let mythAnchor = "myth"

    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .headline) private var cardWidth: CGFloat = 186
    @AppStorage(GuideKeys.myths) private var mythsText = ""

    var body: some View {
        let now = Date()
        let week = QuizEngine.weekIndex(now)
        let germs = model.catalog.germs
        let width = min(cardWidth, 260)
        let answers = MythAnswers(mythsText)
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    if let report = model.goingAround(now: now) {
                        NavigationLink(value: report) {
                            GoingAroundCard(report: report)
                                .frame(width: width)
                        }
                        .buttonStyle(PressableStyle())
                    }
                    if let myth = QuizEngine.mythOfTheWeek(model.catalog.myths, germs: germs, now: now) {
                        WeekMythCard(myth: myth)
                            .frame(width: answers.right(myth.id) != nil ? width * 1.45 : width)
                            .id(Self.mythAnchor)
                    }
                    if let article = lesson(now: now) {
                        WeekLessonCard(article: article)
                            .frame(width: width)
                    }
                    if let germ = QuizEngine.germOfTheWeek(germs, now: now) {
                        NavigationLink(value: germ) {
                            WeekGermCard(germ: germ, week: week)
                                .frame(width: width)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollIndicators(.hidden)
            .padding(.horizontal, -20)
            .onChange(of: mythsText) {
                withAnimation(Tempo.quick) {
                    proxy.scrollTo(Self.mythAnchor, anchor: .leading)
                }
            }
        }
    }

    /// This week's new lesson while unread, open or not; otherwise the next one to read.
    private func lesson(now: Date) -> Article? {
        let read = Set(model.data.readArticles)
        return model.lessonsThisWeek(now: now).first { !read.contains($0.id) }
            ?? model.lessonsToRead(now: now).first { !read.contains($0.id) }
    }
}

/// This week's public health report for the phone's country: its headline and the germs it names.
private struct GoingAroundCard: View {
    let report: GoingAroundReport
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let blue = Color(hex: Swatch.azure)
        VStack(alignment: .leading, spacing: 0) {
            Label(tr("Going around · %@", GoingAroundText.country(report.region)), systemImage: "dot.radiowaves.left.and.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color(hex: palette.isDark ? Swatch.skyLight : Swatch.azureInk))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(report.headline.value)
                .font(.callout.weight(.bold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            Spacer(minLength: 10)
            HStack(spacing: 8) {
                ForEach(report.germs.prefix(3), id: \.germID) { item in
                    if let germ = model.catalog.germ(item.germID) {
                        TrendFace(germ: germ, trend: item.trend)
                    }
                }
            }
        }
        .modifier(WeekCardFrame())
        .background(blue.opacity(palette.isDark ? 0.22 : 0.12), in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .background(palette.background, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A germ's face with an arrow for where it is heading.
private struct TrendFace: View {
    let germ: Germ
    let trend: GoingAroundTrend
    @Environment(\.palette) private var palette

    var body: some View {
        GermImage(germ: germ, size: 30)
            .frame(width: 38, height: 38)
            .background(palette.background, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Image(systemName: trend.symbol)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .frame(width: 17, height: 17)
                    .background(trend.ink(palette), in: Circle())
                    .offset(x: 5, y: -5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(germ.illness.value + ", " + trend.title)
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
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
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

/// One claim a week to judge on the spot. Its answer joins the myth busters and keeps its stamp.
private struct WeekMythCard: View {
    let myth: Myth
    @Environment(\.palette) private var palette
    @AppStorage(GuideKeys.myths) private var mythsText = ""

    /// What was answered, worked out from whether it was right.
    private var answer: Bool? {
        MythAnswers(mythsText).right(myth.id).map { $0 == myth.isTrue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tr("Myth or fact?"))
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent)
            Text(myth.claim)
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
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .background(palette.background, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    private func verdict(_ answer: Bool) -> some View {
        let right = answer == myth.isTrue
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Label {
                    Text(right ? tr("Right!") : tr("Not quite."))
                        .foregroundStyle(palette.ink)
                } icon: {
                    Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(palette.accent)
                }
                .font(.subheadline.weight(.bold))
                Spacer(minLength: 6)
                MythStamp(isTrue: myth.isTrue)
            }
            Text(myth.explanation)
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .transition(.opacity)
    }

    private func choice(_ title: String, value: Bool) -> some View {
        Button {
            let right = value == myth.isTrue
            if right { Haptics.success() } else { Haptics.tap() }
            var answers = MythAnswers(mythsText)
            answers.record(myth.id, right: right)
            withAnimation(Tempo.quick) {
                mythsText = answers.text
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

/// The lesson to open next: new this week, ready to read, or the next one the quiz or the Season Pass opens.
private struct WeekLessonCard: View {
    let article: Article
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showPaywall = false

    var body: some View {
        let open = model.isArticleUnlocked(article)
        let fresh = LessonEngine.isNew(article, now: Date())
        Group {
            if open {
                NavigationLink(value: article) {
                    card(open: open, fresh: fresh)
                }
            } else if article.needsPass {
                Button {
                    showPaywall = true
                } label: {
                    card(open: open, fresh: fresh)
                }
            } else {
                NavigationLink {
                    LessonsScreen()
                } label: {
                    card(open: open, fresh: fresh)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .sheet(isPresented: $showPaywall) {
            PaywallView(reason: .library)
        }
    }

    private func card(open: Bool, fresh: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(fresh ? tr("New this week") : (open ? tr("Lesson to read") : tr("Next lesson")))
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent)
            Text(article.title.value)
                .font(.headline)
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            if open {
                footer(tr("%lld min read", article.minutes), symbol: "clock")
                    .foregroundStyle(palette.inkSecondary)
            } else if article.needsPass {
                PassOfferTag()
                    .padding(.top, 8)
            } else {
                let remaining = max(1, article.unlockAtAnswers - model.data.quiz.rightTotal)
                footer(trCount(remaining, one: "%lld more right answer", other: "%lld more right answers"), symbol: "lock.fill")
                    .foregroundStyle(palette.inkSecondary)
            }
        }
        .modifier(WeekCardFrame())
        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
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


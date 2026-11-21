import SwiftUI

/// The learning tab: the daily quiz and all the germs with their case files, the germ of the week first.
/// The lessons sit in the toolbar.
struct LabScreen: View {
    private enum Filter: Hashable {
        case all
        case caught
        case studied
    }

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showQuiz = false
    @State private var filter = Filter.all
    @State private var query = ""

    /// Germs studied in the Lab and not caught yet.
    private var studiedOnly: Set<String> {
        model.studiedGermIDs.subtracting(model.caughtGermIDs)
    }

    private var weekly: Germ? {
        QuizEngine.germOfTheWeek(model.catalog.germs, now: Date())
    }

    /// The germs the filter and the search keep; the germ of the week leads the full list.
    private var germs: [Germ] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let kept = model.catalog.germs.filter { germ in
            switch filter {
            case .all: break
            case .caught: if !model.caughtGermIDs.contains(germ.id) { return false }
            case .studied: if !studiedOnly.contains(germ.id) { return false }
            }
            guard !needle.isEmpty else { return true }
            return germ.name.lowercased().contains(needle) || germ.illness.value.lowercased().contains(needle)
                || germ.scientific.value.lowercased().contains(needle)
        }
        guard filter == .all, needle.isEmpty, let weekly else { return kept }
        return [weekly] + kept.filter { $0.id != weekly.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    QuizCard(showQuiz: $showQuiz)
                    SectionHeader(title: tr("All %lld", model.catalog.germs.count),
                                  trailing: tr("%lld caught", model.caughtGermIDs.count))
                        .padding(.top, 8)
                    chips
                    grid
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
            .navigationTitle(tr("Lab"))
            .searchable(text: $query, prompt: tr("Search an illness"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    lessonsLink
                }
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
            .fullScreenCover(isPresented: $showQuiz) {
                QuizScreen()
            }
        }
    }

    /// The lessons, drawn like the gear next to it, with a small ring that fills as they open
    /// and a dot while a new lesson is unread.
    private var lessonsLink: some View {
        let articles = model.catalog.articles
        let open = articles.filter { model.isArticleUnlocked($0) }.count
        let fresh = model.hasNewLesson
        return NavigationLink {
            LessonsScreen()
        } label: {
            Image(systemName: "graduationcap")
                .overlay(alignment: .bottomTrailing) {
                    ProgressRing(fraction: articles.isEmpty ? 0 : Double(open) / Double(articles.count), lineWidth: 2)
                        .frame(width: 10, height: 10)
                        .offset(x: 5, y: 4)
                }
                .overlay(alignment: .topTrailing) {
                    if fresh {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 8, height: 8)
                            .padding(1.5)
                            .background(palette.background, in: Circle())
                            .offset(x: 6, y: -4)
                            .transition(.scale)
                    }
                }
                .animation(.spring(duration: 0.3), value: fresh)
        }
        .accessibilityLabel(tr("Lessons"))
        .accessibilityValue(fresh ? tr("New lesson, %1$lld of %2$lld", open, articles.count)
                                  : tr("%1$lld of %2$lld", open, articles.count))
    }

    private var chips: some View {
        HStack(spacing: 8) {
            chip(tr("All %lld", model.catalog.germs.count), .all)
            chip(tr("Caught %lld", model.caughtGermIDs.count), .caught)
            chip(tr("Studied %lld", studiedOnly.count), .studied)
            Spacer(minLength: 0)
        }
    }

    private func chip(_ title: String, _ value: Filter) -> some View {
        let selected = filter == value
        return Button {
            filter = value
        } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? palette.background : palette.inkSecondary)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(selected ? palette.ink : palette.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        let shown = germs
        if shown.isEmpty {
            Text(query.isEmpty ? tr("Nothing here yet. It won't last.") : tr("No illness matches your search."))
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 12)
        }
        let week = QuizEngine.weekIndex(Date())
        let weeklyID = filter == .all && query.isEmpty ? weekly?.id : nil
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(shown) { germ in
                NavigationLink(value: germ) {
                    GermTile(germ: germ, count: model.count(of: germ.id), studied: studiedOnly.contains(germ.id),
                             week: germ.id == weeklyID ? week : nil)
                }
                .buttonStyle(.plain)
                .scrollTransition { content, phase in
                    content
                        .scaleEffect(phase.isIdentity ? 1 : 0.88)
                        .opacity(phase.isIdentity ? 1 : 0.4)
                }
            }
        }
    }
}

extension Germ {
    /// The quiet tint behind a caught germ: its pale tint by day, a deep wash of it by night.
    func tileTint(_ palette: Palette) -> Color {
        palette.isDark ? deepTint.opacity(0.3) : lightTint
    }
}

/// One germ in the Lab grid: a gray shape to find, in color once studied, on its tint once caught.
/// The germ of the week shows in color with a tag, and unmasks itself the first time the Lab opens that week.
private struct GermTile: View {
    private static let revealKey = "lab.revealedWeek"

    let germ: Germ
    let count: Int
    let studied: Bool
    /// The week number when this is the germ of the week.
    let week: Int?
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var unmasked: Bool

    init(germ: Germ, count: Int, studied: Bool, week: Int?) {
        self.germ = germ
        self.count = count
        self.studied = studied
        self.week = week
        let seen = UserDefaults.standard.object(forKey: Self.revealKey) as? Int
        _unmasked = State(initialValue: week == nil || seen == week)
    }

    private var caught: Bool { count > 0 }
    private var weekly: Bool { week != nil }
    private var known: Bool { caught || studied || (weekly && unmasked) }

    var body: some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(caught || (weekly && unmasked) ? germ.tileTint(palette) : palette.surface)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { proxy in
                        art(side: proxy.size.width)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .offset(y: weekly ? proxy.size.width * 0.07 : 0)
                    }
                }
                .overlay {
                    if weekly {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(palette.accent, lineWidth: 3)
                    }
                }
                .overlay(alignment: .top) {
                    if weekly {
                        Label(tr("This week"), systemImage: "sparkles")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.onAccent)
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(palette.accent, in: Capsule())
                            .padding(.top, 8)
                    }
                }
                .padding(.bottom, 6)
            HStack(spacing: 4) {
                Text(germ.name)
                    .font(.subheadline.weight(known ? .semibold : .regular))
                    .foregroundStyle(known ? palette.ink : palette.inkSecondary)
                if count > 1 {
                    Text(verbatim: "×\(count)")
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                }
            }
            .lineLimit(1)
            Text(germ.illness.value)
                .font(.caption)
                .foregroundStyle(palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityValue(weekly ? tr("Germ of the week")
                            : (caught ? tr("Caught") : (studied ? tr("Studied") : tr("Not caught yet"))))
        .task {
            await reveal()
        }
    }

    @ViewBuilder
    private func art(side: CGFloat) -> some View {
        let image = GermImage(germ: germ, size: side * (weekly ? 0.64 : 0.78), silhouette: !known)
            .foregroundStyle(palette.ink.opacity(palette.isDark ? 0.2 : 0.13))
        if weekly {
            LivelyCharacter(mood: .stalking, pokes: false) {
                image
            }
            .scaleEffect(unmasked ? 1 : 0.8)
        } else {
            image
        }
    }

    /// The first time this week: a short pause on the gray shape, then the germ pops out in color.
    private func reveal() async {
        guard let week, !unmasked else { return }
        UserDefaults.standard.set(week, forKey: Self.revealKey)
        if !reduceMotion {
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
            unmasked = true
        }
        Haptics.tap()
    }
}

/// The daily quiz: a bright card with the mascot, where the quiz stands, what it pays and the way in.
private struct QuizCard: View {
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
        VStack(alignment: .leading, spacing: 0) {
            Text(done ? tr("Done for today") : tr("Daily quiz"))
                .font(.title2.weight(.bold))
            Text(done ? tr("%1$lld of %2$lld right. A new quiz tomorrow.", rightToday, plan.count)
                      : trCount(plan.count, one: "%lld question · about a minute", other: "%lld questions · about a minute"))
                .font(.subheadline)
                .opacity(0.92)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
                .padding(.trailing, 118)
            HStack(spacing: 7) {
                HStack(spacing: 6) {
                    ForEach(Array(plan.enumerated()), id: \.offset) { item in
                        segment(index: item.offset, question: item.element, answers: answers)
                    }
                }
                .accessibilityHidden(true)
                Spacer(minLength: 8)
                chip(trCount(streak, one: "%lld day", other: "%lld days"), symbol: "flame.fill")
                    .accessibilityLabel(trCount(streak, one: "Lab streak: %lld day", other: "Lab streak: %lld days"))
                chip(tr("+%lld pts", points), symbol: nil)
            }
            .padding(.top, 18)
            if model.onSickLeave && !done {
                Text(tr("Sick leave: your streak waits for you."))
                    .font(.footnote)
                    .opacity(0.92)
                    .padding(.top, 10)
            }
            if !done {
                Button {
                    showQuiz = true
                } label: {
                    Text(answers.isEmpty ? tr("Start") : tr("Keep going"))
                        .font(.headline)
                        .foregroundStyle(ground)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 16)
            }
        }
        .foregroundStyle(Color.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ground, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(alignment: .topTrailing) {
            LivelyCharacter(mood: done ? .asleep : .idle, phase: 1.3) {
                Image(done ? "mascot-asleep" : "mascot-awake")
                    .resizable()
                    .scaledToFit()
            }
            .frame(width: 112, height: 112)
            .rotationEffect(.degrees(7))
            .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 8)
            .offset(x: -14, y: -34)
            .accessibilityHidden(true)
        }
        .padding(.top, 30)
        .animation(.snappy, value: answers.count)
    }

    /// One question of the day: waiting, right, or wrong.
    @ViewBuilder
    private func segment(index: Int, question: QuizQuestion, answers: [Int]) -> some View {
        if index >= answers.count {
            Capsule()
                .fill(Color.white.opacity(0.32))
                .frame(width: 30, height: 8)
        } else if answers[index] == question.answer {
            Capsule()
                .fill(Color.white)
                .frame(width: 30, height: 8)
        } else {
            Capsule()
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                .frame(width: 30, height: 8)
        }
    }

    private func chip(_ text: String, symbol: String?) -> some View {
        HStack(spacing: 5) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
            }
            Text(text)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(Color.white.opacity(0.14), in: Capsule())
    }
}

/// Every lesson: open ones to read, locked ones with what opens them.
struct LessonsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var nudged: [String: Int] = [:]

    var body: some View {
        let fresh = model.lessonsThisWeek()
        let ladder = model.catalog.articles.filter { !fresh.contains($0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !fresh.isEmpty {
                    SectionHeader(title: tr("This week"))
                    card(fresh)
                    SectionHeader(title: tr("All lessons"))
                }
                card(ladder)
                Text(AppConfig.lessonsURL == nil
                     ? tr("Lessons open with right answers in the daily quiz.")
                     : tr("New lessons come out regularly. Each one is open to everyone for 7 days, then opens with right answers in the daily quiz."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Lessons"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ articles: [Article]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { item in
                if item.offset > 0 {
                    Divider()
                }
                row(item.element)
            }
        }
        .padding(.horizontal, 18)
        .germigoCard(padding: 0)
    }

    @ViewBuilder
    private func row(_ article: Article) -> some View {
        if model.isArticleUnlocked(article) {
            NavigationLink(value: article) {
                label(article, locked: false)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Haptics.tap()
                nudged[article.id, default: 0] += 1
            } label: {
                label(article, locked: true)
            }
            .buttonStyle(.plain)
        }
    }

    private func label(_ article: Article, locked: Bool) -> some View {
        let now = Date()
        let remaining = max(1, article.unlockAtAnswers - model.data.quiz.rightTotal)
        let openWeek = LessonEngine.isOpenToAll(article, now: now)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(article.title.value)
                    .font(.body)
                    .foregroundStyle(locked ? palette.inkSecondary : palette.ink)
                    .multilineTextAlignment(.leading)
                Text(locked ? trCount(remaining, one: "%lld more right answer", other: "%lld more right answers")
                            : article.summary.value)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if openWeek {
                    let left = LessonEngine.daysLeft(article, now: now)
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(trCount(left, one: "Open to everyone · %lld day left", other: "Open to everyone · %lld days left"))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .padding(.top, 5)
                }
            }
            Spacer(minLength: 4)
            if locked {
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .symbolEffect(.wiggle, value: nudged[article.id, default: 0])
                    .accessibilityHidden(true)
            } else if !model.data.readArticles.contains(article.id) {
                Circle()
                    .fill(palette.accent)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(tr("New"))
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct ArticleScreen: View {
    let article: Article
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(article.title.value)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(article.summary.value)
                    .font(.title3)
                    .foregroundStyle(palette.inkSecondary)
                ForEach(Array(article.paragraphs.enumerated()), id: \.offset) { item in
                    Text(item.element.value)
                        .font(.body)
                        .foregroundStyle(palette.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !article.sources.isEmpty {
                    SectionHeader(title: tr("Sources"))
                    SourceList(references: article.sources)
                }
                Text(HealthNotice.text)
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.markArticleRead(article.id)
        }
    }
}

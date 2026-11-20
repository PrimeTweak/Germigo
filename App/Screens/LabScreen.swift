import SwiftUI

/// The learning tab: the daily quiz, the germ of the day, the lessons and every germ's case file.
struct LabScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var showQuiz = false
    @State private var showPaywall = false
    @State private var query = ""

    private var germs: [Germ] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let sorted = model.catalog.germs.sorted { $0.illness.value < $1.illness.value }
        guard !needle.isEmpty else { return sorted }
        return sorted.filter {
            $0.illness.value.lowercased().contains(needle) || $0.scientific.value.lowercased().contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(tr("Learn it before you catch it."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.horizontal, 4)
                    QuizCard(showQuiz: $showQuiz)
                    germOfTheDay
                    lessons
                    caseFiles
                    Text(HealthNotice.text)
                        .font(.footnote)
                        .foregroundStyle(palette.inkTertiary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("Lab"))
            .navigationDestination(for: Germ.self) { germ in
                GermDetailScreen(germ: germ)
            }
            .navigationDestination(for: Article.self) { article in
                ArticleScreen(article: article)
            }
            .fullScreenCover(isPresented: $showQuiz) {
                QuizScreen()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    @ViewBuilder
    private var germOfTheDay: some View {
        if let germ = QuizEngine.germOfTheDay(model.catalog.germs, now: Date()) {
            let locked = model.count(of: germ.id) == 0
            SectionHeader(title: tr("Germ of the day"))
            NavigationLink(value: germ) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(germ.lightTint)
                        GermImage(germ: germ, size: 66, silhouette: locked)
                            .foregroundStyle(germ.deepTint)
                        if locked {
                            Text(verbatim: "?")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: Swatch.night, opacity: 0.6))
                        }
                    }
                    .frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(germ.illness.value)
                            .font(.headline)
                            .foregroundStyle(palette.ink)
                        if let fact = germ.facts.first {
                            Text(tr("%1$@: %2$@", fact.label.value, fact.value.value))
                                .font(.subheadline)
                                .foregroundStyle(palette.inkSecondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(tr("Open the case file"))
                            .font(.subheadline.weight(.semibold))
                            .underline()
                            .foregroundStyle(palette.ink)
                    }
                    Spacer(minLength: 0)
                }
                .petriCard(padding: 12)
            }
            .buttonStyle(.plain)
        }
    }

    private var lessons: some View {
        let articles = model.catalog.articles
        let open = articles.filter { model.isArticleUnlocked($0) }.count
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Lessons"), trailing: tr("%1$lld of %2$lld", open, articles.count))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(articles.enumerated()), id: \.element.id) { item in
                    if item.offset > 0 {
                        Divider()
                    }
                    lessonRow(item.element)
                }
            }
            .padding(.horizontal, 16)
            .petriCard(padding: 0)
            Text(tr("Lessons open with right answers in the daily quiz. The Season Pass opens them all."))
                .font(.footnote)
                .foregroundStyle(palette.inkSecondary)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func lessonRow(_ article: Article) -> some View {
        if model.isArticleUnlocked(article) {
            NavigationLink(value: article) {
                lessonLabel(article, locked: false)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                showPaywall = true
            } label: {
                lessonLabel(article, locked: true)
            }
            .buttonStyle(.plain)
        }
    }

    private func lessonLabel(_ article: Article, locked: Bool) -> some View {
        let remaining = max(1, article.unlockAtAnswers - model.data.quiz.rightTotal)
        return HStack(spacing: 12) {
            IconTile(symbol: locked ? "lock.fill" : article.icon,
                     background: locked ? palette.surfaceAlt : palette.lilac,
                     foreground: locked ? palette.inkSecondary : .white, size: 34)
            VStack(alignment: .leading, spacing: 1) {
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
            }
            Spacer(minLength: 4)
            if !locked && !model.data.readArticles.contains(article.id) {
                Circle()
                    .fill(palette.coral)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel(tr("New"))
            }
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var caseFiles: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: tr("Case files"), trailing: String(model.catalog.germs.count))
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(palette.inkSecondary)
                    .accessibilityHidden(true)
                TextField(tr("Search an illness"), text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(palette.ink)
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(palette.inkTertiary)
                    }
                    .accessibilityLabel(tr("Clear"))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(palette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 0) {
                if germs.isEmpty {
                    Text(tr("No illness matches your search."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .padding(.vertical, 14)
                }
                ForEach(Array(germs.enumerated()), id: \.element.id) { item in
                    if item.offset > 0 {
                        Divider()
                    }
                    NavigationLink(value: item.element) {
                        caseFileRow(item.element)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .petriCard(padding: 0)
        }
    }

    private func caseFileRow(_ germ: Germ) -> some View {
        HStack(spacing: 12) {
            GermImage(germ: germ, size: 34, silhouette: model.count(of: germ.id) == 0)
                .foregroundStyle(germ.deepTint)
            VStack(alignment: .leading, spacing: 1) {
                Text(germ.illness.value)
                    .font(.body)
                    .foregroundStyle(palette.ink)
                Text(germ.scientific.value)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(palette.inkTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

/// The dark daily-quiz card: progress, points, the Lab streak, and the way in.
private struct QuizCard: View {
    @Binding var showQuiz: Bool
    @Environment(AppModel.self) private var model

    private let chalk = Color(hex: Swatch.chalk)
    private let lime = Color(hex: Swatch.lime)

    var body: some View {
        let plan = model.quizPlan()
        let answers = model.quizAnswers()
        let done = model.quizDone()
        let rightToday = zip(plan, answers).filter { $0.0.answer == $0.1 }.count
        let points = (done ? rightToday : plan.count) * RewardEngine.quizAnswerPoints
        VStack(alignment: .leading, spacing: 0) {
            HazardStripes()
                .frame(height: 13)
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("Daily quiz"))
                    .font(.caption.weight(.heavy))
                    .kerning(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(lime)
                Text(done ? tr("Done for today") : trCount(plan.count, one: "%lld question · about a minute",
                                                          other: "%lld questions · about a minute"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(chalk)
                HStack(spacing: 6) {
                    ForEach(Array(plan.enumerated()), id: \.offset) { item in
                        Capsule()
                            .fill(dotColor(index: item.offset, question: item.element, answers: answers))
                            .frame(width: 28, height: 7)
                    }
                    Spacer(minLength: 8)
                    Text(tr("+%lld pts", points))
                        .font(.footnote.weight(.heavy))
                        .foregroundStyle(lime)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(lime.opacity(0.16), in: Capsule())
                }
                Label(trCount(model.labStreak(), one: "Lab streak: %lld day", other: "Lab streak: %lld days"),
                      systemImage: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(chalk.opacity(0.78))
                if done {
                    Text(tr("A new quiz tomorrow."))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(chalk)
                } else {
                    Button(answers.isEmpty ? tr("Start") : tr("Keep going")) {
                        showQuiz = true
                    }
                    .buttonStyle(PillButtonStyle(kind: .accent, height: 50))
                }
            }
            .padding(16)
        }
        .background(Color(hex: Swatch.nightSurface))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func dotColor(index: Int, question: QuizQuestion, answers: [Int]) -> Color {
        guard index < answers.count else { return chalk.opacity(0.25) }
        return answers[index] == question.answer ? lime : Color(hex: Swatch.coral)
    }
}

struct ArticleScreen: View {
    let article: Article
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                IconTile(symbol: article.icon, background: palette.lilac, size: 52)
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

import SwiftUI

/// Every lesson: open ones to read, locked ones with what opens them.
struct LessonsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let fresh = model.lessonsThisWeek()
        let others = model.catalog.articles.filter { !fresh.contains($0) }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !fresh.isEmpty {
                    SectionHeader(title: tr("This week"))
                    LessonCard(articles: fresh)
                    SectionHeader(title: tr("All lessons"))
                }
                LessonCard(articles: others)
                Text(AppConfig.lessonsURL == nil
                     ? tr("Lessons open with right answers in the daily quiz.")
                     : tr("A new lesson comes out every week with the Season Pass. The others open with right answers in the daily quiz."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Lessons"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Lessons stacked in one card, with a hairline between them.
struct LessonCard: View {
    let articles: [Article]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { item in
                if item.offset > 0 {
                    Divider()
                }
                LessonRow(article: item.element)
            }
        }
        .padding(.horizontal, 18)
        .germilyCard(padding: 0)
    }
}

/// One lesson: its title and summary once open, or what opens it. A lesson waiting for right answers
/// wiggles its padlock when tapped; one waiting for the Season Pass leads to the offer.
struct LessonRow: View {
    let article: Article
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var nudges = 0
    @State private var showPaywall = false

    var body: some View {
        if model.isArticleUnlocked(article) {
            NavigationLink(value: article) {
                label(locked: false)
            }
            .buttonStyle(.plain)
        } else {
            Button {
                Haptics.tap()
                if article.needsPass {
                    showPaywall = true
                } else {
                    nudges += 1
                }
            } label: {
                label(locked: true)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showPaywall) {
                PaywallView(reason: .library)
            }
        }
    }

    private func label(locked: Bool) -> some View {
        let remaining = max(1, article.unlockAtAnswers - model.data.quiz.rightTotal)
        let waitsForPass = locked && article.needsPass
        return HStack(spacing: 12) {
            IconTile(symbol: article.icon, size: 36, tint: locked ? nil : palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(article.title.value)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(locked ? palette.inkSecondary : palette.ink)
                    .multilineTextAlignment(.leading)
                Text(locked && !waitsForPass ? trCount(remaining, one: "%lld more right answer", other: "%lld more right answers")
                                             : tr("%lld min read", article.minutes))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            if waitsForPass {
                PassOfferTag()
            } else if locked {
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .symbolEffect(.wiggle, value: nudges)
                    .accessibilityHidden(true)
            } else if !model.data.readArticles.contains(article.id) {
                PillLabel(text: tr("New"), foreground: palette.onAccent, background: palette.accent)
            } else {
                RowChevron()
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
                    SourceList(references: article.sources, reviewedOn: article.reviewedOn)
                }
                HealthLineNote()
                Text(HealthNotice.text)
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.vertical, 16)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.markArticleRead(article.id)
        }
    }
}

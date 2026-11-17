import SwiftUI

/// Every germ's health notes, open to everyone, plus the longer reads.
struct FieldGuideScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var query = ""
    @State private var showPaywall = false

    private var germs: [Germ] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let sorted = model.catalog.germs.sorted { $0.illness.value < $1.illness.value }
        guard !needle.isEmpty else { return sorted }
        return sorted.filter {
            $0.illness.value.lowercased().contains(needle) || $0.scientific.value.lowercased().contains(needle)
        }
    }

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    ForEach(model.catalog.articles) { article in
                        articleRow(article)
                    }
                } header: {
                    Text(tr("Reads"))
                } footer: {
                    Text(tr("Reads unlock as your album grows. The Season Pass opens them all."))
                }
            }
            Section {
                ForEach(germs) { germ in
                    NavigationLink {
                        GermDetailScreen(germ: germ)
                    } label: {
                        HStack(spacing: 12) {
                            GermImage(germ: germ, size: 34, silhouette: model.count(of: germ.id) == 0)
                                .foregroundStyle(palette.ink.opacity(0.28))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(germ.illness.value)
                                    .font(.body)
                                    .foregroundStyle(palette.ink)
                                Text(germ.scientific.value)
                                    .font(.footnote)
                                    .foregroundStyle(palette.inkSecondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            } header: {
                Text(tr("Germs"))
            } footer: {
                Text(tr("General information from public health sources. Not medical advice."))
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.background.ignoresSafeArea())
        .searchable(text: $query, prompt: tr("Search an illness"))
        .navigationTitle(tr("Field Guide"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    @ViewBuilder
    private func articleRow(_ article: Article) -> some View {
        if model.isArticleUnlocked(article) {
            NavigationLink {
                ArticleScreen(article: article)
            } label: {
                articleLabel(article, locked: false)
            }
        } else {
            Button {
                showPaywall = true
            } label: {
                articleLabel(article, locked: true)
            }
        }
    }

    private func articleLabel(_ article: Article, locked: Bool) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: locked ? "lock.fill" : article.icon,
                     background: locked ? palette.surfaceAlt : palette.lilac,
                     foreground: locked ? palette.inkSecondary : .white, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(article.title.value)
                    .font(.body)
                    .foregroundStyle(locked ? palette.inkSecondary : palette.ink)
                    .multilineTextAlignment(.leading)
                Text(locked ? trCount(article.unlockAtGerms, one: "Unlocks at %lld germ", other: "Unlocks at %lld germs")
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
                Text(tr("General information from public health sources. Not medical advice."))
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

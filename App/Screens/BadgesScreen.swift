import SwiftUI

/// Every badge: earned ones filled in, the others with how far along they are.
struct BadgesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    private func progressBar(_ count: BadgeCount) -> some View {
        HStack(spacing: 8) {
            ThinGauge(fraction: count.fraction, fill: palette.accent)
            Text(tr("%1$lld of %2$lld", min(count.progress, count.target), count.target))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(palette.inkSecondary)
        }
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        let counts = BadgeProgress.counts(data: model.data, catalog: model.catalog, now: Date())
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(BadgeCatalog.all) { badge in
                    let earned = model.hasBadge(badge.id)
                    let count = earned ? nil : counts[badge.id].flatMap { $0.target > 0 ? $0 : nil }
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: earned ? badge.symbol : "lock.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(earned ? palette.background : palette.inkTertiary)
                            .frame(width: 46, height: 46)
                            .background(earned ? palette.ink : palette.surfaceAlt, in: Circle())
                        Text(badge.title)
                            .font(.headline)
                            .foregroundStyle(earned ? palette.ink : palette.inkSecondary)
                        Text(badge.detail)
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if let count {
                            progressBar(count)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
                    .petriCard(radius: 22, padding: 14)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(earned ? tr("Earned") : tr("Locked"))
                    .scrollTransition { content, phase in
                        content
                            .scaleEffect(phase.isIdentity ? 1 : 0.9)
                            .opacity(phase.isIdentity ? 1 : 0.4)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Badges"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

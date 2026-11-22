import SwiftUI

/// Five branches of absurd titles earned from the journal, and the one the parent wears.
struct SkillTreeScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let nodes = SkillTree.nodes(data: model.data, catalog: model.catalog)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                ForEach(SkillBranch.allCases) { branch in
                    branchCard(branch, nodes: nodes.filter { $0.branch == branch })
                }
                if let capstone = nodes.first(where: { $0.id == SkillTree.capstoneID }) {
                    capstoneCard(capstone)
                }
                Text(tr("Titles follow your journal: delete a log and its titles can go with it."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkTertiary)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Skill tree"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(spacing: 13) {
            BuddyBadge(look: model.data.hostLook, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayTitle)
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                Text(model.wornTitle == nil ? tr("Tap an unlocked title to wear it.") : tr("Worn on Trophies and on your season recap."))
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .germigoCard()
    }

    private func branchCard(_ branch: SkillBranch, nodes: [SkillNode]) -> some View {
        let count = nodes.first?.progress ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconTile(symbol: branch.symbol)
                VStack(alignment: .leading, spacing: 1) {
                    Text(branch.title)
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(branch.unit)
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                Spacer()
                Text(verbatim: String(count))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(palette.ink)
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(nodes) { node in
                    nodeButton(node, tint: Color(hex: branch.tint))
                        .frame(maxWidth: .infinity)
                }
            }
            .background(alignment: .top) {
                Rectangle()
                    .fill(palette.hairline)
                    .frame(height: 3)
                    .padding(.horizontal, 48)
                    .padding(.top, 25)
                    .accessibilityHidden(true)
            }
        }
        .germigoCard()
    }

    private func nodeButton(_ node: SkillNode, tint: Color) -> some View {
        let worn = model.data.settings.wornTitle == node.id
        return Button {
            guard node.isUnlocked else { return }
            Haptics.tap()
            model.wearTitle(worn ? nil : node.id)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(node.isUnlocked ? tint : palette.surfaceAlt)
                        .frame(width: 52, height: 52)
                    if node.isUnlocked {
                        Text(verbatim: String(node.rank))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color(hex: Swatch.night))
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(palette.inkTertiary)
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(worn ? palette.ink : Color.clear, lineWidth: 3)
                        .frame(width: 60, height: 60)
                }
                Text(node.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(node.isUnlocked ? palette.ink : palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(worn ? tr("Worn") : (node.isUnlocked ? tr("Earned") : tr("%1$lld of %2$lld", node.progress, node.target)))
                    .font(.caption2.weight(worn ? .bold : .regular))
                    .foregroundStyle(palette.inkSecondary)
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(worn ? .isSelected : [])
        .accessibilityHint(node.isUnlocked ? tr("Wears this title") : "")
    }

    private func capstoneCard(_ node: SkillNode) -> some View {
        let worn = model.data.settings.wornTitle == node.id
        return Button {
            guard node.isUnlocked else { return }
            Haptics.tap()
            model.wearTitle(worn ? nil : node.id)
        } label: {
            HStack(spacing: 13) {
                IconTile(symbol: node.isUnlocked ? "star.circle.fill" : "lock.fill", size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.title)
                        .font(.headline)
                        .foregroundStyle(palette.ink)
                    Text(tr("Reach rank 2 in three branches. %1$lld of %2$lld so far.", node.progress, node.target))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if worn {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(palette.ink)
                }
            }
            .germigoCard()
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(worn ? .isSelected : [])
    }
}

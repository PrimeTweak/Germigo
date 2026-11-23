import SwiftUI

/// Titles and badges: the skill tree of absurd titles earned from the journal, then every badge.
struct TitlesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var openTitle: SkillNode?
    @State private var openBadge: Badge?

    var body: some View {
        let nodes = SkillTree.nodes(data: model.data, catalog: model.catalog)
        let earned = nodes.filter { $0.isUnlocked }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                header
                SectionHeader(title: tr("Skill tree"), trailing: tr("%1$lld of %2$lld titles", earned, nodes.count))
                SkillTreeCard(nodes: nodes, worn: model.data.settings.wornTitle) { node in
                    Haptics.tap()
                    openTitle = node
                }
                Text(tr("Titles follow your journal: delete a log and its titles can go with it."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .padding(.horizontal, 4)
                badges
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Titles and badges"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $openTitle) { node in
            TitleSheet(node: node, next: nodes.first { $0.branch != nil && $0.branch == node.branch && $0.rank == node.rank + 1 })
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $openBadge) { badge in
            BadgeSheet(badge: badge)
                .presentationDetents([.medium])
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            BuddyBadge(look: model.data.hostLook, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.displayTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(palette.accent)
                Text(model.wornTitle == nil ? tr("Tap an unlocked title to wear it.") : tr("Worn on Trophies and on your season recap."))
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .germilyCard(padding: 14)
    }

    private var badges: some View {
        let all = BadgeCatalog.all
        let counts = BadgeProgress.counts(data: model.data, catalog: model.catalog, now: Date())
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: tr("Badges"), trailing: tr("%1$lld of %2$lld", all.filter { model.hasBadge($0.id) }.count, all.count))
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(all) { badge in
                    let won = model.hasBadge(badge.id)
                    let shown = badge.shown(earned: won)
                    let count = won ? nil : counts[badge.id].flatMap { $0.target > 0 && $0.progress > 0 ? $0 : nil }
                    Button {
                        Haptics.tap()
                        openBadge = shown
                    } label: {
                        VStack(spacing: 6) {
                            BadgeMedal(badge: shown, won: won, progress: count?.fraction)
                                .frame(width: 58, height: 58)
                            Text(shown.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(won ? palette.ink : palette.inkSecondary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityValue(won ? tr("Earned") : tr("Locked"))
                }
            }
        }
    }
}

/// A title in the skill tree, as a hexagon: full in its branch color once earned, outlined when it is next,
/// faded with a padlock after that.
struct HexNode: View {
    enum Stage {
        case won
        case next
        case locked
    }

    let symbol: String
    let tint: Color
    let stage: Stage
    var size: CGFloat = 38
    @Environment(\.palette) private var palette

    var body: some View {
        let shape = Hexagon()
        ZStack {
            shape.fill(rim)
            shape
                .fill(palette.background)
                .overlay {
                    shape.fill(face)
                }
                .padding(size * 0.07)
            Image(systemName: stage == .locked ? "lock.fill" : symbol)
                .font(.system(size: size * (stage == .locked ? 0.3 : 0.4), weight: .bold))
                .foregroundStyle(ink)
        }
        .frame(width: size, height: size * 1.1)
        .shadow(color: stage == .won ? tint.opacity(0.45) : Color.clear, radius: 5, y: 3)
        .accessibilityHidden(true)
    }

    private var rim: Color {
        switch stage {
        case .won: return tint.mix(with: .black, by: 0.08)
        case .next: return tint
        case .locked: return palette.ink.opacity(0.12)
        }
    }

    private var face: AnyShapeStyle {
        switch stage {
        case .won: return AnyShapeStyle(LinearGradient(colors: [tint.mix(with: .white, by: 0.35), tint], startPoint: .top, endPoint: .bottom))
        case .next: return AnyShapeStyle(tint.opacity(palette.isDark ? 0.24 : 0.18))
        case .locked: return AnyShapeStyle(palette.ink.opacity(0.04))
        }
    }

    private var ink: Color {
        switch stage {
        case .won: return Color.white
        case .next: return palette.isDark ? tint : tint.mix(with: Color(hex: Swatch.ink), by: 0.35)
        case .locked: return palette.ink.opacity(0.35)
        }
    }
}

/// A hexagon standing on a point.
private struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let points = [(0.5, 0.0), (1.0, 0.25), (1.0, 0.75), (0.5, 1.0), (0.0, 0.75), (0.0, 0.25)]
        var path = Path()
        for (index, point) in points.enumerated() {
            let location = CGPoint(x: rect.minX + rect.width * point.0, y: rect.minY + rect.height * point.1)
            if index == 0 {
                path.move(to: location)
            } else {
                path.addLine(to: location)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// The tree: the final title on top, a spine down the side, and the five branches of three titles,
/// their path lit up to the last title earned.
private struct SkillTreeCard: View {
    let nodes: [SkillNode]
    let worn: String?
    let open: (SkillNode) -> Void
    @Environment(\.palette) private var palette

    /// Room on the left of the titles for the spine.
    private static let lead: CGFloat = 30
    /// Where the spine runs: under the middle of the final title's hexagon.
    private static let spine: CGFloat = 19

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let capstone = nodes.first(where: { $0.branch == nil }) {
                capstoneRow(capstone)
            }
            ForEach(SkillBranch.allCases) { branch in
                lane(branch, nodes: nodes.filter { $0.branch == branch }.sorted { $0.rank < $1.rank })
            }
        }
        .background(alignment: .topLeading) {
            Capsule()
                .fill(palette.ink.opacity(0.1))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .padding(.leading, Self.spine - 1.5)
                .padding(.top, 40)
                .padding(.bottom, 58)
        }
        .germilyCard(padding: 14)
    }

    private func capstoneRow(_ node: SkillNode) -> some View {
        Button {
            open(node)
        } label: {
            HStack(spacing: 12) {
                HexNode(symbol: "crown.fill", tint: Color(hex: Swatch.gold), stage: node.isUnlocked ? .won : .locked)
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.ink)
                    Text(tr("Reach rank 2 in three branches. %1$lld of %2$lld so far.", node.progress, node.target))
                        .font(.caption)
                        .foregroundStyle(palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if worn == node.id {
                    wornTag
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(worn == node.id ? .isSelected : [])
    }

    private func lane(_ branch: SkillBranch, nodes: [SkillNode]) -> some View {
        let tint = Color(hex: branch.tint)
        let reached = nodes.filter { $0.isUnlocked }.count
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: branch.symbol)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(hex: Swatch.ink))
                    .frame(width: 20, height: 20)
                    .background(tint.opacity(0.45), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .background(palette.surface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .accessibilityHidden(true)
                Text(branch.unit)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(palette.ink)
                Spacer(minLength: 4)
                Text(tr("%1$lld of %2$lld", reached, nodes.count))
                    .font(.caption)
                    .foregroundStyle(palette.inkSecondary)
            }
            .padding(.leading, Self.spine - 10)
            HStack(spacing: 0) {
                ForEach(nodes) { node in
                    nodeButton(node, tint: tint, isNext: node.rank == reached + 1)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.leading, Self.lead)
            .background {
                Canvas { context, size in
                    let column = (size.width - Self.lead) / 3
                    let centers = (0..<3).map { Self.lead + column * (CGFloat($0) + 0.5) }
                    let starts = [Self.spine] + centers.dropLast()
                    for index in 0..<3 {
                        var path = Path()
                        path.move(to: CGPoint(x: starts[index], y: size.height / 2))
                        path.addLine(to: CGPoint(x: centers[index], y: size.height / 2))
                        if index < reached {
                            context.stroke(path, with: .color(tint), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        } else {
                            context.stroke(path, with: .color(palette.ink.opacity(0.16)),
                                           style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [5, 5]))
                        }
                    }
                }
                .accessibilityHidden(true)
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(nodes) { node in
                    Text(node.title)
                        .font(.caption.weight(node.isUnlocked ? .bold : .semibold))
                        .foregroundStyle(worn == node.id ? palette.accent : (node.isUnlocked ? palette.ink : palette.inkTertiary))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                }
            }
            .padding(.leading, Self.lead)
        }
        .padding(.vertical, 8)
    }

    private func nodeButton(_ node: SkillNode, tint: Color, isNext: Bool) -> some View {
        let isWorn = worn == node.id
        return Button {
            open(node)
        } label: {
            HexNode(symbol: node.branch?.symbol ?? "crown.fill", tint: tint,
                    stage: node.isUnlocked ? .won : (isNext ? .next : .locked))
                .overlay(alignment: .topTrailing) {
                    if isNext {
                        Text(verbatim: "\(node.progress)/\(node.target)")
                            .font(.system(size: 10, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(palette.background)
                            .padding(.horizontal, 5)
                            .frame(height: 17)
                            .background(palette.ink, in: Capsule())
                            .offset(x: 12, y: -5)
                    }
                }
                .overlay(alignment: .top) {
                    if isWorn {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: Swatch.gold))
                            .rotationEffect(.degrees(-8))
                            .offset(y: -14)
                    }
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(node.title)
        .accessibilityValue(isWorn ? tr("Worn") : (node.isUnlocked ? tr("Earned") : tr("%1$lld of %2$lld", node.progress, node.target)))
        .accessibilityAddTraits(isWorn ? .isSelected : [])
    }

    private var wornTag: some View {
        Text(tr("Worn"))
            .font(.caption2.weight(.bold))
            .foregroundStyle(palette.onAccent)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(palette.accent, in: Capsule())
    }
}

/// One title, opened: what it took, a word about it, and the way to wear it once earned.
private struct TitleSheet: View {
    let node: SkillNode
    let next: SkillNode?
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let worn = model.data.settings.wornTitle == node.id
        let tint = Color(hex: node.branch?.tint ?? Swatch.gold)
        ScrollView {
            VStack(spacing: 8) {
                HexNode(symbol: node.branch?.symbol ?? "crown.fill", tint: tint, stage: node.isUnlocked ? .won : .next, size: 70)
                    .padding(.top, 26)
                    .padding(.bottom, 6)
                Text(kicker)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.inkSecondary)
                Text(node.title)
                    .font(.title.weight(.heavy))
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                Text(node.branch?.quip ?? tr("The daycare has nothing left to teach you."))
                    .font(.body)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(progress)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if node.isUnlocked {
                    Button(worn ? tr("Take it off") : tr("Wear this title")) {
                        Haptics.tap()
                        model.wearTitle(worn ? nil : node.id)
                        dismiss()
                    }
                    .buttonStyle(PillButtonStyle(kind: .ink))
                    .padding(.top, 10)
                    if let next, !next.isUnlocked, let branch = next.branch {
                        HStack(spacing: 12) {
                            HexNode(symbol: branch.symbol, tint: tint, stage: .next, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(tr("Next on this branch"))
                                    .font(.caption)
                                    .foregroundStyle(palette.inkSecondary)
                                Text(next.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.ink)
                                Text(tr("%1$lld of %2$lld", next.progress, next.target))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(palette.accent)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 20)
        }
        .background(palette.background.ignoresSafeArea())
    }

    private var kicker: String {
        guard let branch = node.branch else { return tr("The final title") }
        return tr("%1$@ · title %2$lld of %3$lld", branch.unit, node.rank, branch.targets.count)
    }

    private var progress: String {
        guard let branch = node.branch else {
            return tr("Reach rank 2 in three branches. %1$lld of %2$lld so far.", node.progress, node.target)
        }
        return tr("%1$@: %2$lld of %3$lld", branch.unit, min(node.progress, node.target), node.target)
    }
}

/// One badge, opened: what earns it and how far along it is.
private struct BadgeSheet: View {
    let badge: Badge
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let won = model.hasBadge(badge.id)
        let count = won ? nil : BadgeProgress.counts(data: model.data, catalog: model.catalog, now: Date())[badge.id]
            .flatMap { $0.target > 0 ? $0 : nil }
        VStack(spacing: 8) {
            BadgeMedal(badge: badge, won: won, progress: count?.fraction)
                .frame(width: 84, height: 84)
                .padding(.top, 30)
                .padding(.bottom, 6)
            Text(badge.title)
                .font(.title.weight(.heavy))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
            Text(badge.detail)
                .font(.body)
                .foregroundStyle(palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if won {
                Label(tr("Earned"), systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.accent)
                    .padding(.top, 6)
            } else if let count {
                HStack(spacing: 8) {
                    ThinGauge(fraction: count.fraction, fill: Color(hex: badge.tint))
                    Text(tr("%1$lld of %2$lld", min(count.progress, count.target), count.target))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(palette.inkSecondary)
                }
                .padding(.top, 10)
                .padding(.horizontal, 30)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.page)
        .frame(maxWidth: .infinity)
        .background(palette.background.ignoresSafeArea())
    }
}

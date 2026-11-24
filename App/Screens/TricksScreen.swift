import SwiftUI

/// The notebook of the napping germ's ten tricks: a found one shows its face and how to do it again,
/// one still to find keeps its silhouette and a clue. Finding all ten earns the secret Ticklish badge.
struct TricksScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette

    var body: some View {
        let found = Set(model.data.mascotTricks)
        let count = MascotTrick.allCases.filter { found.contains($0.rawValue) }.count
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 2)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CollectionHead(open: count, total: MascotTrick.allCases.count,
                               note: tr("Found on Today, while it naps. Each one left has a clue."))
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(MascotTrick.allCases, id: \.self) { trick in
                        TrickTile(trick: trick, found: found.contains(trick.rawValue))
                    }
                }
                HStack(spacing: 10) {
                    Image(systemName: count == MascotTrick.allCases.count ? "checkmark.seal.fill" : "lock.fill")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(count == MascotTrick.allCases.count ? palette.accent : palette.inkTertiary)
                        .frame(width: 30, height: 30)
                        .background(palette.ink.opacity(0.06), in: Circle())
                    Text(count == MascotTrick.allCases.count ? tr("All ten found. The Ticklish badge is yours.")
                                                             : tr("Find all ten for a secret badge."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, Spacing.page)
            .padding(.top, 10)
            .padding(.bottom, 28)
        }
        .background(palette.background.ignoresSafeArea())
        .navigationTitle(tr("Tricks"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One trick in the notebook.
private struct TrickTile: View {
    let trick: MascotTrick
    let found: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(trick.face)
                .resizable()
                .renderingMode(found ? .original : .template)
                .scaledToFit()
                .foregroundStyle(palette.ink.opacity(0.13))
                .frame(width: 44, height: 44)
            Text(verbatim: found ? trick.title : "???")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(found ? palette.ink : palette.inkTertiary)
                .padding(.top, 2)
            Text(found ? trick.how : trick.clue)
                .font(.caption)
                .italic(!found)
                .foregroundStyle(palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(found ? palette.accent.opacity(palette.isDark ? 0.18 : 0.09) : palette.ink.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if found {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(Color.white)
                    .frame(width: 20, height: 20)
                    .background(Color(hex: Swatch.greenInk), in: Circle())
                    .padding(10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(found ? trick.title + ", " + trick.how : tr("Not found yet") + ", " + trick.clue)
    }
}

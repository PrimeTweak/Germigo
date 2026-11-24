import SwiftUI

/// Every sticker: an earned one goes on the couch with a tap, the others say how to earn them.
struct StickerBookSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        let earned = model.earnedStickers()
        let left = StickerBook.all.count - earned.count
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text(tr("Tap a sticker to put it on the couch. Hold it there to move it."))
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSecondary)
                        .multilineTextAlignment(.center)
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(StickerBook.all, id: \.self) { sticker in
                            tile(sticker, earned: earned.contains(sticker))
                        }
                    }
                    if left > 0 {
                        Text(trCount(left, one: "%lld more to find.", other: "%lld more to find."))
                            .font(.footnote)
                            .foregroundStyle(palette.inkSecondary)
                    }
                }
                .padding(.horizontal, Spacing.page)
                .padding(.vertical, 12)
            }
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(tr("Sticker book"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel(tr("Done"))
                    .tint(palette.ink)
                }
            }
        }
    }

    private func tile(_ sticker: String, earned: Bool) -> some View {
        let placed = model.isOnCouch(sticker)
        return Button {
            Haptics.tap()
            model.toggleCouch(sticker)
        } label: {
            VStack(spacing: 6) {
                art(sticker, earned: earned)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(earned ? palette.accent.opacity(0.1) : palette.ink.opacity(0.04),
                                in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if placed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(palette.accent)
                                .background(palette.background, in: Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                Text(StickerBook.how(sticker))
                    .font(.caption.weight(earned ? .semibold : .regular))
                    .foregroundStyle(earned ? palette.ink : palette.inkTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .buttonStyle(PressableStyle())
        .disabled(!earned)
        .accessibilityLabel(StickerBook.name(sticker))
        .accessibilityValue(earned ? (placed ? tr("On the couch") : "") : StickerBook.how(sticker))
        .animation(Tempo.pop, value: placed)
    }

    /// An earned sticker in color; one still to earn as a pale shape.
    @ViewBuilder
    private func art(_ sticker: String, earned: Bool) -> some View {
        if earned {
            Image("sticker-" + sticker)
                .resizable()
                .scaledToFit()
        } else {
            Image("sticker-" + sticker)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(palette.ink.opacity(0.12))
        }
    }
}

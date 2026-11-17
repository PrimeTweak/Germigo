import SwiftUI

/// Previews a 360 by 640 card, renders it once, and offers the share sheet.
struct SharePreviewSheet<Card: View>: View {
    let title: String
    let card: Card
    @State private var rendered: Image?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    init(title: String, @ViewBuilder card: () -> Card) {
        self.title = title
        self.card = card()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                card
                    .frame(width: 360, height: 640)
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .scaleEffect(0.78)
                    .frame(width: 281, height: 499)
                    .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 12)
                if let rendered {
                    ShareLink(item: rendered, preview: SharePreview(title, image: rendered)) {
                        Label(tr("Share"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PillButtonStyle(kind: .ink))
                } else {
                    ProgressView()
                        .frame(height: 56)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(tr("Close")) {
                        dismiss()
                    }
                }
            }
            .task {
                let renderer = ImageRenderer(content: card.frame(width: 360, height: 640))
                renderer.scale = 3
                if let image = renderer.uiImage {
                    rendered = Image(uiImage: image)
                }
            }
        }
    }
}

private struct ShareWordmark: View {
    var color = Color.white

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: "petri")
                .font(.system(size: 30, weight: .black))
                .kerning(-1.2)
            Text(tr("Daycare germs, collected."))
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.7)
        }
        .foregroundStyle(color)
    }
}

/// A caught germ, sized for stories.
struct GermShareCard: View {
    let germ: Germ
    let count: Int
    let finish: GermCardView.Finish

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2A2140), Color(hex: 0x120F17)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [germ.deepTint.opacity(0.6), Color.clear], center: UnitPoint(x: 0.5, y: 0.42),
                           startRadius: 0, endRadius: 260)
            VStack(spacing: 0) {
                Text(tr("I caught %@!", germ.name))
                    .font(.system(size: 30, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .padding(.top, 54)
                Text(germ.illness.value + " · " + germ.rarity.label)
                    .font(.system(size: 15, weight: .semibold))
                    .opacity(0.65)
                    .padding(.top, 4)
                Spacer(minLength: 0)
                GermCardView(germ: germ, width: 216, finish: finish, count: count)
                    .rotationEffect(.degrees(-3))
                Spacer(minLength: 0)
                Text(tr("Thanks, daycare."))
                    .font(.system(size: 17, weight: .semibold))
                    .opacity(0.8)
                    .padding(.bottom, 22)
                ShareWordmark()
                    .padding(.bottom, 40)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 24)
        }
        .frame(width: 360, height: 640)
    }
}

/// A joke coupon the sick parent sends to the other one.
struct NapCouponCard: View {
    let from: String
    let to: String?
    let germ: Germ

    var body: some View {
        ZStack {
            Color(hex: 0xF6F1E7)
            VStack(spacing: 0) {
                HazardStripes()
                    .frame(height: 22)
                Spacer(minLength: 0)
                GermImage(germ: germ, size: 150)
                Text(tr("Nap coupon").uppercased())
                    .font(.system(size: 40, weight: .black))
                    .kerning(-0.5)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                Text(tr("Good for one uninterrupted nap."))
                    .font(.system(size: 17, weight: .semibold))
                    .opacity(0.65)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 10) {
                    line(tr("Holder"), from)
                    line(tr("Owed by"), to ?? tr("Whoever is still standing"))
                    line(tr("Reason"), germ.illness.value)
                    line(tr("Valid"), tr("Until the germ leaves"))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .padding(.horizontal, 26)
                .padding(.top, 24)
                Spacer(minLength: 0)
                ShareWordmark(color: Color(hex: 0x1E1A26))
                    .padding(.bottom, 26)
                HazardStripes()
                    .frame(height: 22)
            }
            .foregroundStyle(Color(hex: 0x1E1A26))
        }
        .frame(width: 360, height: 640)
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .kerning(0.8)
                .opacity(0.5)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
        }
    }
}

/// The season in numbers, for the recap share.
struct SeasonRecapCard: View {
    let seasonNumber: Int
    let stats: SeasonStats
    let level: LevelInfo
    let germs: [Germ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xC9FA6E), Color(hex: 0x9EDC48)], startPoint: .top, endPoint: .bottom)
            RingsBackground(color: Color.white.opacity(0.35), spacing: 34)
            VStack(spacing: 0) {
                Text(tr("Season %lld", seasonNumber).uppercased())
                    .font(.system(size: 14, weight: .heavy))
                    .kerning(2)
                    .padding(.top, 50)
                Text(tr("I survived."))
                    .font(.system(size: 44, weight: .black))
                    .kerning(-1)
                    .padding(.top, 2)
                HStack(spacing: -14) {
                    ForEach(germs.prefix(5)) { germ in
                        GermImage(germ: germ, size: 76)
                    }
                }
                .padding(.top, 20)
                VStack(spacing: 10) {
                    tile(String(stats.germsCaught), tr("germs caught"))
                    tile(String(stats.daysSick), tr("days sick"))
                    tile(String(stats.dodged), tr("germs dodged"))
                    tile(tr("Lv %lld", level.number), level.title)
                }
                .padding(.horizontal, 30)
                .padding(.top, 22)
                Spacer(minLength: 0)
                ShareWordmark(color: Color(hex: 0x1E1A26))
                    .padding(.bottom, 36)
            }
            .foregroundStyle(Color(hex: 0x1E1A26))
        }
        .frame(width: 360, height: 640)
    }

    private func tile(_ value: String, _ label: String) -> some View {
        HStack {
            Text(value)
                .font(.system(size: 28, weight: .heavy))
            Spacer()
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .opacity(0.7)
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(Color.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

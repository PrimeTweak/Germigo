import SwiftUI

/// The collectible card: tinted background, rings, mascot, name and rarity.
struct GermCardView: View {
    enum Finish {
        case locked
        case standard
        case gold
        case holo
    }

    let germ: Germ
    var width: CGFloat = 124
    var finish = Finish.standard
    var count = 0
    var isNew = false
    @Environment(\.palette) private var palette

    private var height: CGFloat { width * 1.39 }
    private var scale: CGFloat { width / 124 }
    private var radius: CGFloat { 20 * scale }

    var body: some View {
        ZStack {
            background
            RingsBackground(color: finish == .locked ? palette.ink.opacity(0.05) : Color.white.opacity(0.3),
                            spacing: 17 * scale)
            GermImage(germ: germ, size: width * 0.8, silhouette: finish == .locked)
                .foregroundStyle(palette.ink.opacity(0.14))
                .shadow(color: Color.black.opacity(finish == .locked ? 0 : 0.16), radius: 6 * scale, x: 0, y: 5 * scale)
                .offset(y: -height * 0.05)
            if finish == .locked {
                Text(verbatim: "?")
                    .font(.system(size: 30 * scale, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .offset(y: -height * 0.05)
            }
            if finish == .holo {
                HoloSheen()
            }
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                footer
            }
            .padding(9 * scale)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 3 * scale)
        }
        .shadow(color: Color.black.opacity(finish == .locked ? 0 : 0.12), radius: 9 * scale, x: 0, y: 6 * scale)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var background: some View {
        Group {
            if finish == .locked {
                palette.surfaceAlt
            } else {
                RadialGradient(colors: [germ.lightTint, germ.deepTint], center: UnitPoint(x: 0.5, y: 0.38),
                               startRadius: 0, endRadius: height * 0.75)
            }
        }
    }

    private var borderColor: Color {
        switch finish {
        case .locked: return palette.ink.opacity(0.06)
        case .gold, .holo: return Color(hex: 0xFFD978)
        case .standard: return Color.white.opacity(0.75)
        }
    }

    private var header: some View {
        HStack {
            if finish != .locked {
                Text(germ.rarity.label.uppercased())
                    .font(.system(size: 9.5 * scale, weight: .heavy))
                    .kerning(0.6)
                    .foregroundStyle(germ.rarity.color)
                    .padding(.horizontal, 7 * scale)
                    .padding(.vertical, 3 * scale)
                    .background(Color.white.opacity(0.85), in: Capsule())
            }
            Spacer(minLength: 0)
            Text(verbatim: germ.numberLabel)
                .font(.system(size: 12 * scale, weight: .heavy))
                .foregroundStyle(Color(hex: 0x1E1A26, opacity: finish == .locked ? 0.3 : 0.45))
        }
    }

    private var footer: some View {
        VStack(spacing: 4 * scale) {
            HStack {
                Spacer(minLength: 0)
                if isNew {
                    badge(tr("NEW"), background: Color(hex: 0xFF5B4D))
                } else if count > 0 {
                    badge("×\(count)", background: Color(hex: 0x1E1A26))
                }
            }
            Text(finish == .locked ? "???" : germ.name)
                .font(.system(size: 17 * scale, weight: .heavy))
                .foregroundStyle(Color(hex: 0x1E1A26, opacity: finish == .locked ? 0.32 : 1))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(finish == .locked ? tr("Not caught yet") : germ.illness.value)
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(Color(hex: 0x1E1A26, opacity: 0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.bottom, 3 * scale)
    }

    private func badge(_ text: String, background: Color) -> some View {
        Text(text)
            .font(.system(size: 11 * scale, weight: .heavy))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 7 * scale)
            .padding(.vertical, 3 * scale)
            .background(background, in: Capsule())
    }

    private var accessibilityText: String {
        if finish == .locked {
            return tr("Card %@, not caught yet", germ.numberLabel)
        }
        return tr("%1$@, %2$@, %3$@, caught %4$lld times", germ.name, germ.illness.value, germ.rarity.label, count)
    }
}

/// Rainbow sheen for repeat catches.
private struct HoloSheen: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.15),
                .init(color: Color(hex: 0xFF78C8, opacity: 0.55), location: 0.32),
                .init(color: Color(hex: 0x78DCFF, opacity: 0.55), location: 0.45),
                .init(color: Color(hex: 0xC8FF78, opacity: 0.55), location: 0.57),
                .init(color: Color(hex: 0xFFE678, opacity: 0.5), location: 0.68),
                .init(color: .clear, location: 0.84)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }
}

extension AppModel {
    /// The finish a caught card earns from repeat catches.
    func cardFinish(for germ: Germ) -> GermCardView.Finish {
        let caught = count(of: germ.id)
        if caught == 0 { return .locked }
        if caught >= 3 && hasPass { return .holo }
        return caught >= 2 ? .gold : .standard
    }
}

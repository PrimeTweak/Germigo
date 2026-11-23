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

    private var height: CGFloat { width * 1.39 }
    private var scale: CGFloat { width / 124 }
    private var radius: CGFloat { 20 * scale }

    var body: some View {
        ZStack {
            background
            RingsBackground(color: Color.white.opacity(finish == .locked ? 0.55 : 0.3), spacing: 17 * scale)
            GermImage(germ: germ, size: width * 0.8, silhouette: finish == .locked)
                .foregroundStyle(germ.deepTint)
                .shadow(color: Color.black.opacity(finish == .locked ? 0 : 0.16), radius: 6 * scale, x: 0, y: 5 * scale)
                .offset(y: -height * 0.05)
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
                germ.lightTint
            } else {
                RadialGradient(colors: [germ.lightTint, germ.deepTint], center: UnitPoint(x: 0.5, y: 0.38),
                               startRadius: 0, endRadius: height * 0.75)
            }
        }
    }

    private var borderColor: Color {
        switch finish {
        case .locked: return Color(hex: Swatch.night, opacity: 0.06)
        case .gold, .holo: return Color(hex: Swatch.goldFoil)
        case .standard: return Color.white.opacity(0.75)
        }
    }

    private var header: some View {
        HStack {
            if finish != .locked {
                Text(germ.rarity.label)
                    .font(.system(size: max(11, 9.5 * scale), weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .foregroundStyle(germ.rarity.inkColor)
                    .padding(.horizontal, 4 * scale)
                    .padding(.vertical, 3 * scale)
                    .background(Color.white.opacity(0.85), in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    private var lockedInk: Color { Color(hex: Swatch.night, opacity: 0.64) }

    private var footer: some View {
        VStack(spacing: 4 * scale) {
            HStack {
                Text(verbatim: germ.numberLabel)
                    .font(.system(size: max(11, 12 * scale), weight: .bold))
                    .foregroundStyle(Color(hex: Swatch.night, opacity: 0.8))
                Spacer(minLength: 0)
                if isNew {
                    badge(tr("New"), foreground: Color.white, background: Color(hex: Swatch.grape))
                } else if count > 0 {
                    badge("×\(count)", foreground: Color.white, background: Color(hex: Swatch.night))
                }
            }
            Text(germ.name)
                .font(.system(size: 17 * scale, weight: .bold))
                .foregroundStyle(finish == .locked ? lockedInk : Color(hex: Swatch.night))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(finish == .locked ? tr("Not caught yet") : germ.illness.value)
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(finish == .locked ? lockedInk : Color(hex: Swatch.night, opacity: 0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.bottom, 3 * scale)
    }

    private func badge(_ text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 11 * scale, weight: .bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 7 * scale)
            .padding(.vertical, 3 * scale)
            .background(background, in: Capsule())
    }

    private var accessibilityText: String {
        if finish == .locked {
            return tr("Card %1$@, %2$@, not caught yet", germ.numberLabel, germ.name)
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
                .init(color: Color(hex: Swatch.holoPink, opacity: 0.55), location: 0.32),
                .init(color: Color(hex: Swatch.holoBlue, opacity: 0.55), location: 0.45),
                .init(color: Color(hex: Swatch.holoGreen, opacity: 0.55), location: 0.57),
                .init(color: Color(hex: Swatch.holoYellow, opacity: 0.5), location: 0.68),
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

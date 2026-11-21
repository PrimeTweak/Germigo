import SwiftUI

private struct CardBackground: ViewModifier {
    @Environment(\.palette) private var palette
    let radius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    /// The rounded quiet surface used for grouped content.
    func petriCard(radius: CGFloat = 24, padding: CGFloat = 16) -> some View {
        modifier(CardBackground(radius: radius, padding: padding))
    }
}

/// The one health disclaimer, shown wherever health notes appear.
enum HealthNotice {
    static var text: String {
        tr("Petri shares general information from public health sources. It is not medical advice and does not replace a health professional.")
    }
}

/// Full-width capsule buttons: filled for the main action, quiet for the other one.
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        case ink
        case ghost
    }

    var kind = Kind.ink
    var height: CGFloat = 56
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(kind == .ink ? palette.background : palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(kind == .ink ? palette.ink : palette.ink.opacity(0.07), in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.ink)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.subheadline)
                    .foregroundStyle(palette.inkSecondary)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
    }
}

/// A small quiet square holding an SF Symbol.
struct IconTile: View {
    let symbol: String
    var size: CGFloat = 32
    @Environment(\.palette) private var palette

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(palette.ink.opacity(0.07))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(palette.ink)
            }
            .accessibilityHidden(true)
    }
}

struct PillLabel: View {
    let text: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
    }
}

struct AvatarView: View {
    let name: String
    let gradient: LinearGradient
    var size: CGFloat = 40

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(1)).uppercased()
    }

    var body: some View {
        Circle()
            .fill(gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(initial)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color(hex: Swatch.night))
            }
            .accessibilityHidden(true)
    }
}

/// A germ mascot, or its silhouette while the card is still locked.
struct GermImage: View {
    let germ: Germ
    let size: CGFloat
    var silhouette = false

    var body: some View {
        Group {
            if silhouette {
                Image(germ.assetName).renderingMode(.template).resizable()
            } else {
                Image(germ.assetName).resizable()
            }
        }
        .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Concentric rings used behind cards and hero art.
struct RingsBackground: View {
    var color = Color.white.opacity(0.28)
    var spacing: CGFloat = 17

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let limit = max(size.width, size.height)
            var radius = spacing
            while radius < limit {
                let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1.5)
                radius += spacing
            }
        }
        .accessibilityHidden(true)
    }
}

/// A plain row for lists inside cards: a title, an optional value, a chevron.
struct ValueRow: View {
    let title: String
    var value: String?
    var showsChevron = true
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.body)
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.callout)
                    .foregroundStyle(palette.inkSecondary)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.inkTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

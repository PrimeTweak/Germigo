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
            .shadow(color: Color.black.opacity(palette.isDark ? 0 : 0.05), radius: 10, x: 0, y: 4)
    }
}

extension View {
    /// The rounded white surface used for grouped content.
    func petriCard(radius: CGFloat = 26, padding: CGFloat = 16) -> some View {
        modifier(CardBackground(radius: radius, padding: padding))
    }
}

/// Full-width capsule buttons in the four roles the app uses.
struct PillButtonStyle: ButtonStyle {
    enum Kind {
        case ink
        case accent
        case coral
        case ghost
    }

    var kind = Kind.ink
    var height: CGFloat = 56
    @Environment(\.palette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(background, in: Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .ink: return palette.background
        case .accent: return palette.night
        case .coral: return .white
        case .ghost: return palette.ink
        }
    }

    private var background: AnyShapeStyle {
        switch kind {
        case .ink:
            return AnyShapeStyle(palette.ink)
        case .accent:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xC9FA6E), Color(hex: 0xA6EB3A)],
                                                startPoint: .top, endPoint: .bottom))
        case .coral:
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xFF7A63), Color(hex: 0xFF4F42)],
                                                startPoint: .top, endPoint: .bottom))
        case .ghost:
            return AnyShapeStyle(palette.ink.opacity(0.07))
        }
    }
}

struct SectionHeader: View {
    let title: String
    var trailing: String?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
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

/// A small rounded square holding an SF Symbol, as in Settings rows.
struct IconTile: View {
    let symbol: String
    let background: Color
    var foreground = Color.white
    var size: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(background)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(foreground)
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
    var darkText = false

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
                    .foregroundStyle(darkText ? Color(hex: 0x1E1A26) : Color.white)
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

/// A plain row for settings-like lists inside cards.
struct ValueRow: View {
    let symbol: String
    let tint: Color
    let title: String
    var value: String?
    var showsChevron = true
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 14) {
            IconTile(symbol: symbol, background: tint)
            Text(title)
                .font(.body)
                .foregroundStyle(palette.ink)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .font(.body)
                    .foregroundStyle(palette.inkTertiary)
                    .lineLimit(1)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(palette.inkTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

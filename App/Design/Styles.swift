import SwiftUI

private struct CardBackground: ViewModifier {
    @Environment(\.palette) private var palette
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }
}

/// The one shadow of floating controls; none on dark surfaces.
private struct LiftShadow: ViewModifier {
    @Environment(\.palette) private var palette

    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(palette.isDark ? 0 : 0.1), radius: 10, x: 0, y: 4)
    }
}

extension View {
    /// Lifts a floating control off the page.
    func liftShadow() -> some View {
        modifier(LiftShadow())
    }

    /// The rounded quiet surface used for grouped content.
    func germilyCard(padding: CGFloat = 16) -> some View {
        modifier(CardBackground(padding: padding))
    }

    /// Keeps a text field's content within a number of characters while it is typed.
    func characterLimit(_ limit: Int, text: Binding<String>) -> some View {
        onChange(of: text.wrappedValue) { _, value in
            if value.count > limit { text.wrappedValue = String(value.prefix(limit)) }
        }
    }

    /// Gives a control smaller than 44 points a 44-point touch area without moving what surrounds it.
    func hitTarget(width: CGFloat = 44, height: CGFloat) -> some View {
        let across = max(0, (44 - width) / 2)
        let reach = max(0, (44 - height) / 2)
        return padding(.horizontal, across)
            .padding(.vertical, reach)
            .contentShape(Rectangle())
            .padding(.horizontal, -across)
            .padding(.vertical, -reach)
    }
}

/// The one health disclaimer, shown wherever health notes appear.
enum HealthNotice {
    static var text: String {
        tr("Germily shares general information from public health sources. It is not medical advice and does not replace a health professional.")
    }
}

/// The margin between the screen edges and a page's content.
enum Spacing {
    static let page: CGFloat = 20
}

/// The three corner radii of the app. Bars, thumbnails sized by their side and capsules keep their own shape.
enum Radius {
    /// Cards, sheets and large panels.
    static let large: CGFloat = 24
    /// Tiles, rows and what sits inside a card.
    static let medium: CGFloat = 20
    /// Chips and small marks.
    static let small: CGFloat = 12
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
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Tempo.press, value: configuration.isPressed)
    }

    /// A disabled pill keeps a readable label instead of fading as a whole.
    private var foreground: Color {
        guard isEnabled else { return palette.ink.opacity(0.6) }
        return kind == .ink ? palette.background : palette.ink
    }

    private var fill: Color {
        guard isEnabled, kind == .ink else { return palette.ink.opacity(isEnabled ? 0.07 : 0.1) }
        return palette.ink
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

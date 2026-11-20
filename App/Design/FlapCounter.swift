import SwiftUI

/// The split-flap day counter. Digits flip when the value changes.
struct FlapCounter: View {
    let value: Int
    var hot = false
    var tileWidth: CGFloat = 92
    var spacing: CGFloat = 8

    private var digits: [Int] {
        let capped = max(0, min(value, 999))
        let text = capped < 10 ? "0\(capped)" : "\(capped)"
        return text.compactMap { $0.wholeNumberValue }
    }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(digits.enumerated()), id: \.offset) { item in
                FlapDigit(digit: item.element, hot: hot, width: tileWidth)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trCount(value, one: "%lld day", other: "%lld days"))
    }
}

private struct FlapDigit: View {
    let digit: Int
    let hot: Bool
    let width: CGFloat
    @State private var from: Int
    @State private var progress: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(digit: Int, hot: Bool, width: CGFloat) {
        self.digit = digit
        self.hot = hot
        self.width = width
        _from = State(initialValue: digit)
    }

    var body: some View {
        FlapFace(from: from, to: digit, progress: progress, hot: hot, width: width)
            .onChange(of: digit) { oldValue, _ in
                from = oldValue
                guard !reduceMotion else {
                    progress = 1
                    return
                }
                progress = 0
                Task { @MainActor in
                    withAnimation(.easeIn(duration: 0.34)) {
                        progress = 1
                    }
                }
            }
    }
}

/// One flap mid-turn; `progress` runs from 0 (old digit) to 1 (new digit).
private struct FlapFace: View, Animatable {
    let from: Int
    let to: Int
    var progress: Double
    let hot: Bool
    let width: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private var height: CGFloat { width * 1.28 }

    var body: some View {
        ZStack {
            half(to, top: true)
            half(progress >= 1 ? to : from, top: false)
            if progress < 0.5 {
                half(from, top: true)
                    .rotation3DEffect(.degrees(-180 * progress), axis: (x: 1, y: 0, z: 0),
                                      anchor: .center, perspective: 0.45)
            } else if progress < 1 {
                half(to, top: false)
                    .rotation3DEffect(.degrees(180 * (1 - progress)), axis: (x: 1, y: 0, z: 0),
                                      anchor: .center, perspective: 0.45)
            }
            Rectangle()
                .fill(Color.black.opacity(0.6))
                .frame(height: 2)
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(0.22), radius: width * 0.09, x: 0, y: width * 0.09)
    }

    private func half(_ digit: Int, top: Bool) -> some View {
        FlapTile(digit: digit, hot: hot, width: width, height: height)
            .mask(alignment: top ? .top : .bottom) {
                Rectangle().frame(height: height / 2)
            }
    }
}

private struct FlapTile: View {
    let digit: Int
    let hot: Bool
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.14, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: Swatch.tileTop), Color(hex: Swatch.tileBottom)],
                                     startPoint: .top, endPoint: .bottom))
            Text(verbatim: "\(digit)")
                .font(.system(size: width * 1.02, weight: .heavy))
                .foregroundStyle(hot ? Color(hex: Swatch.coralHot) : Color(hex: Swatch.cream))
        }
        .frame(width: width, height: height)
    }
}

/// Black and yellow warning stripes across the top of the sign.
struct HazardStripes: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: Swatch.night)))
            let band: CGFloat = 11
            var x = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + band, y: 0))
                path.addLine(to: CGPoint(x: x + band, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(Color(hex: Swatch.hazard)))
                x += band * 2
            }
        }
        .accessibilityHidden(true)
    }
}

/// The "days without a germ" workplace-safety sign, full size or as a one-row strip.
struct CounterSign: View {
    let days: Int
    let isSick: Bool
    let leadingNote: String
    let trailingNote: String
    var tileWidth: CGFloat = 92
    var isStrip = false
    @Environment(\.palette) private var palette

    private var label: String {
        trCount(days, one: "day without a germ", other: "days without a germ").uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            HazardStripes()
                .frame(height: isStrip ? 10 : 14)
            if isStrip {
                strip
            } else {
                full
            }
        }
        .frame(maxWidth: .infinity)
        .background(palette.sign)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(palette.isDark ? 0 : 0.08), radius: 14, x: 0, y: 8)
    }

    private var full: some View {
        let roomy = tileWidth >= 78
        let gap: CGFloat = roomy ? 12 : (tileWidth >= 66 ? 10 : 8)
        let inset: CGFloat = roomy ? 16 : (tileWidth >= 66 ? 14 : 12)
        return VStack(spacing: gap) {
            Text(tr("This household has gone").uppercased())
                .font(.footnote.weight(.heavy))
                .kerning(1.6)
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
            FlapCounter(value: days, hot: isSick, tileWidth: tileWidth)
            Text(label)
                .font(roomy ? Font.title2.weight(.black) : Font.title3.weight(.black))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
            Rectangle()
                .fill(palette.hairline)
                .frame(height: 1)
            HStack {
                Text(leadingNote)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.ink)
                Spacer()
                Text(trailingNote)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, inset)
    }

    private var strip: some View {
        HStack(spacing: 14) {
            FlapCounter(value: days, hot: isSick, tileWidth: 38, spacing: 5)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.headline.weight(.black))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(isSick ? leadingNote + " · " + trailingNote : leadingNote)
                    .font(.footnote)
                    .foregroundStyle(palette.inkSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

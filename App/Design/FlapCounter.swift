import SwiftUI

/// The split-flap day counter. Digits flip when the value changes.
struct FlapCounter: View {
    let value: Int
    var hot = false
    var tileWidth: CGFloat = 92

    private var digits: [Int] {
        let capped = max(0, min(value, 999))
        let text = capped < 10 ? "0\(capped)" : "\(capped)"
        return text.compactMap { $0.wholeNumberValue }
    }

    var body: some View {
        HStack(spacing: 8) {
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
        .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 8)
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
                .fill(LinearGradient(colors: [Color(hex: 0x34303D), Color(hex: 0x1F1C26)],
                                     startPoint: .top, endPoint: .bottom))
            Text(verbatim: "\(digit)")
                .font(.system(size: width * 1.02, weight: .heavy))
                .foregroundStyle(hot ? Color(hex: 0xFF6A5A) : Color(hex: 0xFFF6E2))
        }
        .frame(width: width, height: height)
    }
}

/// Black and yellow warning stripes across the top of the sign.
struct HazardStripes: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x1E1A26)))
            let band: CGFloat = 11
            var x = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + band, y: 0))
                path.addLine(to: CGPoint(x: x + band, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(Color(hex: 0xFFC93C)))
                x += band * 2
            }
        }
        .accessibilityHidden(true)
    }
}

/// The "days without a germ" workplace-safety sign.
struct CounterSign: View {
    let days: Int
    let isSick: Bool
    let leadingNote: String
    let trailingNote: String
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            HazardStripes()
                .frame(height: 14)
            VStack(spacing: 12) {
                Text(tr("This household has gone").uppercased())
                    .font(.footnote.weight(.heavy))
                    .kerning(1.6)
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                FlapCounter(value: days, hot: isSick)
                Text(trCount(days, one: "day without a germ", other: "days without a germ").uppercased())
                    .font(.title2.weight(.black))
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
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .background(palette.sign)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(color: Color.black.opacity(palette.isDark ? 0 : 0.08), radius: 14, x: 0, y: 8)
    }
}

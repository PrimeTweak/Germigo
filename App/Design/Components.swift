import SwiftUI

/// The coral "I'm sick" button. Holding it for a moment opens the log sheet.
struct HoldToLogButton: View {
    let action: () -> Void
    @State private var progress: CGFloat = 0
    @Environment(\.palette) private var palette

    private let holdDuration = 0.9

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: "thermometer.medium")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(palette.coralDeep)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(tr("I'm sick"))
                    .font(.title3.weight(.bold))
                Text(tr("Hold to log it"))
                    .font(.footnote.weight(.medium))
            }
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .stroke(palette.night.opacity(0.25), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(palette.night, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 18, weight: .semibold))
            }
            .frame(width: 44, height: 44)
        }
        .foregroundStyle(palette.night)
        .padding(.horizontal, 10)
        .frame(height: 66)
        .background {
            ZStack(alignment: .leading) {
                LinearGradient(colors: [Color(hex: Swatch.coralLight), Color(hex: Swatch.coralDeep)], startPoint: .top, endPoint: .bottom)
                GeometryReader { proxy in
                    Color(hex: Swatch.ember, opacity: 0.22)
                        .frame(width: proxy.size.width * progress)
                }
            }
        }
        .clipShape(Capsule())
        .shadow(color: Color(hex: Swatch.coralDeep, opacity: 0.32), radius: 13, x: 0, y: 10)
        .scaleEffect(progress > 0 ? 0.975 : 1)
        .contentShape(Capsule())
        .onLongPressGesture(minimumDuration: holdDuration, maximumDistance: 60) {
            Haptics.thud()
            progress = 0
            action()
        } onPressingChanged: { pressing in
            withAnimation(pressing ? .linear(duration: holdDuration) : .easeOut(duration: 0.2)) {
                progress = pressing ? 1 : 0
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("I'm sick"))
        .accessibilityHint(tr("Opens the log sheet"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            action()
        }
    }
}

/// The exposure timeline: elapsed time, the incubation window, and now.
struct IncubationBar: View {
    let exposedAt: Date
    let opens: Date
    let closes: Date
    let now: Date
    let tint: Color
    @Environment(\.palette) private var palette

    private func fraction(_ date: Date) -> CGFloat {
        let total = max(1, closes.timeIntervalSince(exposedAt))
        let value = date.timeIntervalSince(exposedAt) / total
        return CGFloat(min(1, max(0, value)))
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let openX = width * fraction(opens)
            let nowX = width * fraction(now)
            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    palette.ink.opacity(0.07)
                    DangerStripes()
                        .frame(width: max(0, width - openX))
                        .offset(x: openX)
                    tint.frame(width: nowX)
                }
                .clipShape(Capsule())
                RoundedRectangle(cornerRadius: 2)
                    .fill(palette.ink)
                    .frame(width: 4, height: 22)
                    .offset(x: max(0, nowX - 2))
            }
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

private struct DangerStripes: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: Swatch.coral, opacity: 0.12)))
            var x = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + 5, y: 0))
                path.addLine(to: CGPoint(x: x + 5, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .color(Color(hex: Swatch.coral, opacity: 0.3)))
                x += 10
            }
        }
    }
}

/// One of the five severity faces in the log sheet.
struct SeverityFace: View {
    let level: Int
    let selected: Bool

    private var fillColor: Color {
        if selected { return Color(hex: Swatch.coral) }
        let tints: [UInt32] = [Swatch.blushFaint, Swatch.blushLight, Swatch.blush, Swatch.blushDeep, Swatch.linen]
        return Color(hex: tints[max(0, min(tints.count - 1, level - 1))])
    }

    var body: some View {
        Canvas { context, size in
            let ink = selected ? Color.white : Color(hex: Swatch.night)
            let w = size.width
            let h = size.height
            context.fill(Path(ellipseIn: CGRect(x: 0, y: 0, width: w, height: h)), with: .color(fillColor))
            let stroke = StrokeStyle(lineWidth: w * 0.055, lineCap: .round, lineJoin: .round)
            let leftEye = CGPoint(x: w * 0.36, y: h * 0.42)
            let rightEye = CGPoint(x: w * 0.64, y: h * 0.42)
            let eye = w * 0.05

            if level == 5 {
                for center in [leftEye, rightEye] {
                    var cross = Path()
                    cross.move(to: CGPoint(x: center.x - eye, y: center.y - eye))
                    cross.addLine(to: CGPoint(x: center.x + eye, y: center.y + eye))
                    cross.move(to: CGPoint(x: center.x + eye, y: center.y - eye))
                    cross.addLine(to: CGPoint(x: center.x - eye, y: center.y + eye))
                    context.stroke(cross, with: .color(ink), style: stroke)
                }
            } else {
                for center in [leftEye, rightEye] {
                    let rect = CGRect(x: center.x - eye, y: center.y - eye, width: eye * 2, height: eye * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(ink))
                }
            }

            var mouth = Path()
            let left = CGPoint(x: w * 0.34, y: h * 0.64)
            let right = CGPoint(x: w * 0.66, y: h * 0.64)
            switch level {
            case 1:
                mouth.move(to: left)
                mouth.addQuadCurve(to: right, control: CGPoint(x: w * 0.5, y: h * 0.8))
            case 2:
                mouth.move(to: left)
                mouth.addLine(to: right)
            case 3:
                mouth.move(to: CGPoint(x: left.x, y: h * 0.7))
                mouth.addQuadCurve(to: CGPoint(x: right.x, y: h * 0.7), control: CGPoint(x: w * 0.5, y: h * 0.56))
            case 4:
                mouth.move(to: left)
                let step = (right.x - left.x) / 4
                for index in 0..<4 {
                    let startX = left.x + step * CGFloat(index)
                    let bump = index % 2 == 0 ? -h * 0.07 : h * 0.07
                    mouth.addQuadCurve(to: CGPoint(x: startX + step, y: left.y),
                                       control: CGPoint(x: startX + step / 2, y: left.y + bump))
                }
            default:
                let rect = CGRect(x: w * 0.42, y: h * 0.6, width: w * 0.16, height: h * 0.14)
                context.fill(Path(ellipseIn: rect), with: .color(ink))
            }
            context.stroke(mouth, with: .color(ink), style: stroke)
        }
        .accessibilityHidden(true)
    }
}

/// A short burst of tissues and dots behind the reward card.
struct ConfettiView: View {
    let start: Date

    private struct Piece {
        let dx: Double
        let dy: Double
        let spin: Double
        let delay: Double
        let size: Double
        let isTissue: Bool
        let color: Color
    }

    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64

        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    private static let pieces: [Piece] = {
        var generator = SeededGenerator(state: 7)
        let colors = [Color(hex: Swatch.lime), Color(hex: Swatch.coral), Color(hex: Swatch.lilac), Color(hex: Swatch.hazard), Color(hex: Swatch.sky)]
        return (0..<56).map { index in
            let angle = Double.random(in: -2.9 ... -0.25, using: &generator)
            let speed = Double.random(in: 320...760, using: &generator)
            return Piece(dx: cos(angle) * speed, dy: sin(angle) * speed,
                         spin: Double.random(in: -420...420, using: &generator),
                         delay: Double.random(in: 0...0.1, using: &generator),
                         size: Double.random(in: 8...17, using: &generator),
                         isTissue: index % 3 == 0, color: colors[index % colors.count])
        }
    }()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                if elapsed < 0 || elapsed > 3.4 { return }
                for piece in Self.pieces {
                    let time = elapsed - piece.delay
                    if time < 0 { continue }
                    let x = Double(size.width) / 2 + piece.dx * time
                    let y = Double(size.height) * 0.38 + piece.dy * time + 520 * time * time
                    var layer = context
                    layer.opacity = max(0, min(1, 1.8 - time * 0.62))
                    layer.translateBy(x: CGFloat(x), y: CGFloat(y))
                    layer.rotate(by: .degrees(piece.spin * time))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 2, width: piece.size, height: piece.size)
                    if piece.isTissue {
                        layer.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(Color.white))
                    } else {
                        layer.fill(Path(ellipseIn: rect), with: .color(piece.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

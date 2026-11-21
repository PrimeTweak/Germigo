import SwiftUI

/// Shrinks a little under the finger.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// One of the two answers at the bottom of Today: a face and what it says.
struct FaceTile<Face: View>: View {
    let title: String
    let action: () -> Void
    let face: Face
    @Environment(\.palette) private var palette

    init(_ title: String, action: @escaping () -> Void, @ViewBuilder face: () -> Face) {
        self.title = title
        self.action = action
        self.face = face()
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                face
                    .frame(width: 62, height: 62)
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 14)
            .padding(.bottom, 16)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

/// The page background: the top takes the color of the character on screen.
struct CharacterWash: View {
    let tint: Color
    @Environment(\.palette) private var palette

    var body: some View {
        palette.background
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    LinearGradient(colors: [tint.opacity(palette.isDark ? 0.3 : 0.46), tint.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: proxy.size.height * 0.62)
                }
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// A thin gauge: how much is left, or how far along.
struct ThinGauge: View {
    let fraction: Double
    var fill: Color?
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.ink.opacity(0.12))
                Capsule()
                    .fill(fill ?? palette.ink)
                    .frame(width: proxy.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// One of the five severity faces in the log sheet.
struct SeverityFace: View {
    let level: Int
    let selected: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        let fillColor = selected ? palette.ink : palette.ink.opacity(0.07)
        let ink = selected ? palette.background : palette.ink
        Canvas { context, size in
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
        let colors = [Color(hex: Swatch.irisSoft), Color(hex: Swatch.lilac), Color(hex: Swatch.lilacPale), Color(hex: Swatch.sky), Color(hex: Swatch.skyPale)]
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

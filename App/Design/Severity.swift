import SwiftUI

/// The five answers to "How bad?", each with its name.
enum Severity {
    static func name(_ level: Int) -> String {
        switch level {
        case ...1: return tr("Sniffles")
        case 2: return tr("Meh")
        case 3: return tr("Couch day")
        case 4: return tr("Bathroom floor")
        default: return tr("Send soup")
        }
    }
}

extension AppModel {
    /// The characters to draw for whoever was sick.
    func looks(of sufferer: Sufferer) -> [Int] {
        switch sufferer {
        case .me: return [look(of: .me)]
        case .partner: return [look(of: .partner)]
        case .both: return [look(of: .me), look(of: .partner)]
        }
    }
}

/// "How bad?" as a scene above a five-notch slider, with the level's name between them.
struct SeverityPicker: View {
    @Binding var level: Int
    let looks: [Int]
    let germ: Germ?
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            InvasionScene(level: level, looks: looks, germ: germ)
                .frame(height: 170)
                .background(germ?.tileTint(palette) ?? palette.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
            Text(Severity.name(level))
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.ink)
                .contentTransition(.opacity)
            NotchSlider(level: $level)
            HStack {
                Text(Severity.name(1))
                Spacer()
                Text(Severity.name(5))
            }
            .font(.caption)
            .foregroundStyle(palette.inkTertiary)
            .accessibilityHidden(true)
        }
        .animation(Tempo.pop, value: level)
        .onChange(of: level) { _, _ in
            Haptics.tick()
        }
    }
}

/// Whoever was sick, in the middle, with more germs around them the worse it was.
struct InvasionScene: View {
    let level: Int
    let looks: [Int]
    let germ: Germ?

    /// Where each germ lands, as fractions of the scene, with its size next to the person and its tilt.
    private static let spots: [(x: CGFloat, y: CGFloat, scale: CGFloat, tilt: Double)] = [
        (0.74, 0.32, 0.50, -12), (0.26, 0.38, 0.46, 10), (0.82, 0.72, 0.52, -6), (0.18, 0.74, 0.50, 14),
        (0.52, 0.17, 0.46, 0), (0.64, 0.56, 0.42, -18), (0.36, 0.58, 0.42, 8)
    ]

    /// One germ at the mildest level, a crowd at the worst.
    private static func crowd(_ level: Int) -> Int {
        [1, 2, 3, 5, 7][min(max(level, 1), 5) - 1]
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let person = min(size.height * 0.4, size.width * 0.24) * (looks.count > 1 ? 0.85 : 1)
            let ground = size.height * 0.9
            ZStack {
                ForEach(Array(looks.enumerated()), id: \.offset) { item in
                    let x = size.width * (looks.count == 1 ? 0.5 : (item.offset == 0 ? 0.42 : 0.58))
                    Ellipse()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: person * 0.9, height: person * 0.16)
                        .blur(radius: 3)
                        .position(x: x, y: ground)
                    BuddyView(look: item.element, sick: level >= 3, size: person, lively: true)
                        .position(x: x, y: ground - person * 0.46)
                }
                ForEach(0..<Self.crowd(level), id: \.self) { index in
                    let spot = Self.spots[index]
                    Image(germ?.assetName ?? "germ-" + GermCatalog.mysteryID)
                        .resizable()
                        .scaledToFit()
                        .frame(width: person * 1.5 * spot.scale, height: person * 1.5 * spot.scale)
                        .rotationEffect(.degrees(spot.tilt))
                        .position(x: size.width * spot.x, y: size.height * spot.y)
                        .transition(.scale(scale: 0.2).combined(with: .opacity))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Five notches on a track: drag or tap to pick one, or swipe up and down with VoiceOver.
private struct NotchSlider: View {
    @Binding var level: Int
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 14
            let width = proxy.size.width - inset * 2
            let mid = proxy.size.height / 2
            let x = { (step: Int) -> CGFloat in inset + width * CGFloat(step - 1) / 4 }
            ZStack {
                Capsule()
                    .fill(palette.surfaceAlt)
                    .frame(width: width, height: 6)
                    .position(x: proxy.size.width / 2, y: mid)
                Capsule()
                    .fill(palette.accent)
                    .frame(width: x(level) - inset, height: 6)
                    .position(x: inset + (x(level) - inset) / 2, y: mid)
                ForEach(1...5, id: \.self) { step in
                    Circle()
                        .fill(step <= level ? palette.accent : palette.inkTertiary.opacity(0.45))
                        .frame(width: 9, height: 9)
                        .position(x: x(step), y: mid)
                }
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
                    .position(x: x(level), y: mid)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let raw = (value.location.x - inset) / max(width, 1) * 4 + 1
                let step = min(5, max(1, Int(raw.rounded())))
                if step != level { level = step }
            })
        }
        .frame(height: 36)
        .accessibilityElement()
        .accessibilityLabel(tr("How bad?"))
        .accessibilityValue(Severity.name(level))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: level = min(5, level + 1)
            case .decrement: level = max(1, level - 1)
            @unknown default: break
            }
        }
    }
}

/// How bad a germ was, in a list: the germ once per level, a faint dot for the rest.
struct SeverityGauge: View {
    let level: Int
    let germ: Germ?
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { step in
                let side = 14 + CGFloat(step)
                ZStack {
                    if step <= level {
                        Image(germ?.assetName ?? "germ-" + GermCatalog.mysteryID)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Circle()
                            .fill(palette.inkTertiary.opacity(0.35))
                            .frame(width: 4 + CGFloat(step) * 0.6, height: 4 + CGFloat(step) * 0.6)
                    }
                }
                .frame(width: side, height: side)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(tr("How bad?"))
        .accessibilityValue(Severity.name(level))
    }
}

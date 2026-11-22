import SwiftUI

/// Shrinks a little under the finger.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Tempo.press, value: configuration.isPressed)
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

/// Places chips side by side and starts a new row when the width runs out.
struct ChipRows: Layout {
    var spacing: CGFloat = 8

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map { $0.width }.max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !row.indices.isEmpty, row.width + spacing + size.width > width {
                rows.append(row)
                row = Row()
            }
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

/// The wash color of each tab after Today, whose color follows its character.
enum TabWash {
    static let family = Color(hex: Swatch.peach)
    static let lab = Color(hex: Swatch.aqua)
    static let trophies = Color(hex: Swatch.goldFoil)
    static let crew = Color(hex: Swatch.skyLight)
}

/// The page background: the top takes the color of the character on screen.
struct CharacterWash: View {
    let tint: Color
    /// How far down the page the color reaches.
    var reach: CGFloat = 0.62
    @Environment(\.palette) private var palette

    var body: some View {
        palette.background
            .overlay(alignment: .top) {
                GeometryReader { proxy in
                    LinearGradient(colors: [tint.opacity(palette.isDark ? 0.3 : 0.46), tint.opacity(0)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: proxy.size.height * reach)
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

/// Entries older than the free week: how many there are, and the way to the Season Pass.
struct LockedHistoryRow: View {
    let count: Int
    @Environment(\.palette) private var palette
    @State private var showPaywall = false

    var body: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.inkSecondary)
                    .frame(width: 44, height: 44)
                    .background(palette.ink.opacity(0.07), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(trCount(count, one: "%lld older entry", other: "%lld older entries"))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.ink)
                    Text(tr("The whole history comes with the Season Pass."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkSecondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(palette.inkTertiary)
            }
            .germigoCard(radius: 24, padding: 12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

/// The small padlock on something the Season Pass opens.
struct PassLock: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Image(systemName: "lock.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(palette.onAccent)
            .frame(width: 28, height: 28)
            .background(palette.accent, in: Circle())
            .overlay { Circle().strokeBorder(palette.surface, lineWidth: 2.5) }
            .accessibilityLabel(tr("Needs the Season Pass"))
    }
}

/// The share button inside a card: a quiet capsule in the accent color.
struct ShareCapsule: View {
    let title: String
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "square.and.arrow.up")
                .font(.callout.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(palette.background, in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }
}

/// One place on a podium: a character, a name, and what earned the place.
struct PodiumPlace: Identifiable {
    let id: String
    let look: Int
    var sick = false
    let name: String
    var title: String?
    let detail: String
    /// The rank shared by tied places; nil ranks by position.
    var rank: Int?
}

/// The first three places on steps with the winner in the middle, then the others in rows.
struct Podium: View {
    let places: [PodiumPlace]
    @Environment(\.palette) private var palette

    private static let heights: [CGFloat] = [78, 52, 34]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach([1, 0, 2].filter { $0 < places.count }, id: \.self) { index in
                    step(places[index], rank: places[index].rank ?? index + 1)
                        .cascadeIn(index)
                }
            }
            ForEach(Array(places.enumerated()).dropFirst(3), id: \.element.id) { item in
                row(item.element, rank: item.element.rank ?? item.offset + 1)
            }
        }
    }

    private func step(_ place: PodiumPlace, rank: Int) -> some View {
        VStack(spacing: 0) {
            BuddyView(look: place.look, sick: place.sick, size: rank == 1 ? 62 : 52, leads: rank == 1)
                .padding(.bottom, 4)
            Text(verbatim: String(rank))
                .font(.title3.weight(.bold))
                .foregroundStyle(palette.ink)
                .padding(.top, 6)
                .frame(maxWidth: .infinity, minHeight: Self.heights[rank - 1], alignment: .top)
                .background(palette.accent.opacity(rank == 1 ? 0.42 : 0.22),
                            in: UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 8,
                                                       bottomTrailingRadius: 8, topTrailingRadius: 16))
            Text(place.name)
                .font(.callout.weight(.bold))
                .foregroundStyle(palette.ink)
                .lineLimit(1)
                .padding(.top, 8)
            Text(place.title ?? " ")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(place.detail)
                .font(.caption)
                .foregroundStyle(palette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func row(_ place: PodiumPlace, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: String(rank))
                .font(.headline.monospacedDigit())
                .foregroundStyle(palette.inkTertiary)
                .frame(width: 22)
            BuddyView(look: place.look, sick: place.sick, size: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(place.name)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(palette.ink)
                if let title = place.title {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.accent)
                }
            }
            Spacer(minLength: 8)
            Text(place.detail)
                .font(.subheadline)
                .foregroundStyle(palette.inkSecondary)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.ink.opacity(0.08))
                .frame(height: 1)
        }
        .padding(.top, rank == 4 ? 12 : 0)
        .accessibilityElement(children: .combine)
    }
}

/// A person to pick: their character, as healthy or sick as they are today, and their name.
struct PersonChip: View {
    let look: Int
    let sick: Bool
    let name: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                BuddyView(look: look, sick: sick, size: 28)
                Text(name)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? palette.background : palette.ink)
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .frame(height: 44)
            .background(selected ? palette.ink : palette.ink.opacity(0.07), in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A choice without a character, such as the illness a photo belongs to.
struct ChoiceChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(selected ? palette.background : palette.ink)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(selected ? palette.ink : palette.ink.opacity(0.07), in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

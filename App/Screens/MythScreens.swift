import SwiftUI

/// The myths answered, in the order they were answered: the germ's id and whether the answer was right.
struct MythAnswers {
    private(set) var entries: [(id: String, right: Bool)]

    init(_ text: String) {
        entries = text.split(separator: ",").compactMap { part in
            let bits = part.split(separator: ":")
            guard bits.count == 2 else { return nil }
            return (id: String(bits[0]), right: bits[1] == "1")
        }
    }

    var text: String {
        entries.map { $0.id + ":" + ($0.right ? "1" : "0") }.joined(separator: ",")
    }

    /// Nil until the myth is answered.
    func right(_ id: String) -> Bool? {
        entries.first { $0.id == id }?.right
    }

    mutating func record(_ id: String, right: Bool) {
        guard self.right(id) == nil else { return }
        entries.append((id: id, right: right))
    }

    /// Right answers in a row, counting back from the last one.
    var streak: Int {
        entries.reversed().prefix { $0.right }.count
    }
}

/// Which myth the deck opens on.
struct MythStart: Identifiable {
    let id: String
}

/// The verdict as a rubber stamp: "Myth!" in red or "Fact!" in green, a little crooked.
struct MythStamp: View {
    let isTrue: Bool
    var large = false

    var body: some View {
        let ink = Color(hex: isTrue ? Swatch.greenInk : Swatch.coralInk)
        Text(isTrue ? tr("Fact!") : tr("Myth!"))
            .font(.system(size: large ? 30 : 16, weight: .heavy, design: .rounded))
            .foregroundStyle(ink)
            .padding(.horizontal, large ? 16 : 9)
            .padding(.vertical, large ? 4 : 2)
            .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: large ? 12 : 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: large ? 12 : 9, style: .continuous)
                    .strokeBorder(ink, lineWidth: large ? 4 : 3)
            }
            .rotationEffect(.degrees(-11))
            .accessibilityLabel(isTrue ? tr("Fact.") : tr("Myth."))
    }
}

/// A myth on the Guide's shelf: the claim on the germ's tint, with its stamp once answered.
struct MythTile: View {
    let germ: Germ
    let answered: Bool
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GermImage(germ: germ, size: 40)
                .frame(width: 44, height: 44, alignment: .leading)
            Text(germ.myth.claim.value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 150, alignment: .topLeading)
        .frame(minHeight: 166, maxHeight: .infinity, alignment: .topLeading)
        .background(germ.tileTint(palette), in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if answered {
                MythStamp(isTrue: germ.myth.isTrue)
                    .padding(10)
            } else {
                Text(verbatim: "?")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(palette.background)
                    .frame(width: 32, height: 32)
                    .background(palette.ink, in: Circle())
                    .padding(10)
                    .accessibilityLabel(tr("Myth or fact?"))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The myths in a row on the Guide, and the way into the deck.
struct MythShelf: View {
    let germs: [Germ]
    let open: (String) -> Void
    @AppStorage(GuideKeys.myths) private var answersText = ""

    var body: some View {
        let answers = MythAnswers(answersText)
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(germs) { germ in
                    Button {
                        open(germ.id)
                    } label: {
                        MythTile(germ: germ, answered: answers.right(germ.id) != nil)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
    }
}

/// Every myth as a deck of cards: judge it, see the stamp, the explanation and the source, then the next one.
struct MythDeckScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(GuideKeys.myths) private var answersText = ""
    @State private var currentID: String
    @State private var sharing: Germ?

    init(start: String) {
        _currentID = State(initialValue: start)
    }

    private var germs: [Germ] { model.catalog.germs }

    var body: some View {
        let answers = MythAnswers(answersText)
        let index = germs.firstIndex { $0.id == currentID } ?? 0
        NavigationStack {
            VStack(spacing: 20) {
                if index < germs.count {
                    let germ = germs[index]
                    let right = answers.right(germ.id)
                    card(germ, right: right)
                        .id(germ.id)
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                    actions(germ, right: right, streak: answers.streak)
                }
            }
            .padding(.horizontal, Spacing.page)
            .padding(.bottom, 12)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(CharacterWash(tint: Color(hex: Swatch.lilac), reach: 0.9))
            .navigationTitle(tr("Myth busters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(tr("Close"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text(tr("%1$lld of %2$lld", index + 1, germs.count))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(palette.inkSecondary)
                }
            }
            .sheet(item: $sharing) { germ in
                SharePreviewSheet(title: tr("Myth busters")) {
                    MythShareCard(germ: germ)
                }
            }
        }
    }

    private func card(_ germ: Germ, right: Bool?) -> some View {
        let shape = RoundedRectangle(cornerRadius: 34, style: .continuous)
        return VStack(spacing: 12) {
            if right != nil {
                MythStamp(isTrue: germ.myth.isTrue, large: true)
                    .transition(reduceMotion ? .opacity : .scale(scale: 1.8).combined(with: .opacity))
                    .padding(.top, 8)
            } else {
                LivelyCharacter(mood: germ.restMood, touch: nil) {
                    GermImage(germ: germ, size: 140)
                }
                .frame(width: 150, height: 150)
            }
            Text(tr("Myth or fact?"))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.accent)
            Text(germ.myth.claim.value)
                .font(.title2.weight(.bold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if right != nil {
                Text(germ.myth.explanation.value)
                    .font(.body)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let source = germ.sources.first, let url = source.link {
                    Link(destination: url) {
                        Label(source.name, systemImage: "info.circle")
                            .font(.footnote.weight(.semibold))
                            .multilineTextAlignment(.leading)
                    }
                    .tint(palette.accent)
                }
                Spacer(minLength: 0)
                Image(right == true ? "mascot-laugh" : "mascot-gasp")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 110, height: 110)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity, minHeight: 440, maxHeight: .infinity)
        .background(palette.background, in: shape)
        .background {
            shape
                .fill(palette.background.opacity(0.55))
                .rotationEffect(.degrees(3))
                .offset(y: 8)
        }
        .shadow(color: Color.black.opacity(palette.isDark ? 0 : 0.12), radius: 18, y: 10)
        .padding(.top, 12)
    }

    @ViewBuilder
    private func actions(_ germ: Germ, right: Bool?, streak: Int) -> some View {
        if let right {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        sharing = germ
                    } label: {
                        Label(tr("Share"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(PillButtonStyle(kind: .ghost))
                    Button(tr("Next myth")) {
                        next(after: germ)
                    }
                    .buttonStyle(PillButtonStyle(kind: .ink))
                }
                Text(right ? (streak > 1 ? trCount(streak, one: "%lld myth busted in a row", other: "%lld myths busted in a row") : tr("Right!"))
                           : tr("Not quite."))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(right ? Color(hex: palette.isDark ? Swatch.green : Swatch.greenInk) : palette.inkSecondary)
            }
        } else {
            HStack(spacing: 10) {
                verdictButton(tr("Myth"), color: Swatch.coralInk) {
                    answer(germ, fact: false)
                }
                verdictButton(tr("Fact"), color: Swatch.greenInk) {
                    answer(germ, fact: true)
                }
            }
        }
    }

    private func verdictButton(_ title: String, color: UInt32, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Color(hex: color), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    private func answer(_ germ: Germ, fact: Bool) {
        let right = fact == germ.myth.isTrue
        if right { Haptics.success() } else { Haptics.tap() }
        var answers = MythAnswers(answersText)
        answers.record(germ.id, right: right)
        withAnimation(reduceMotion ? nil : Tempo.pop) {
            answersText = answers.text
        }
    }

    /// The next myth not answered yet, after this one; when all are answered, simply the next one.
    private func next(after germ: Germ) {
        let answers = MythAnswers(answersText)
        let index = germs.firstIndex { $0.id == germ.id } ?? 0
        let order = Array(germs[(index + 1)...]) + Array(germs[..<index])
        let target = order.first { answers.right($0.id) == nil } ?? order.first ?? germ
        withAnimation(reduceMotion ? nil : Tempo.quick) {
            currentID = target.id
        }
    }
}

/// A busted myth, sized for stories: the stamp, the claim and the answer.
struct MythShareCard: View {
    let germ: Germ

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.plum), Color(hex: Swatch.plumDeep)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [germ.deepTint.opacity(0.55), Color.clear], center: UnitPoint(x: 0.5, y: 0.3),
                           startRadius: 0, endRadius: 260)
            VStack(spacing: 18) {
                GermImage(germ: germ, size: 130)
                    .padding(.top, 50)
                MythStamp(isTrue: germ.myth.isTrue, large: true)
                Text(germ.myth.claim.value)
                    .font(.system(size: 26, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(germ.myth.explanation.value)
                    .font(.system(size: 17, weight: .medium))
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                ShareWordmark()
                    .padding(.bottom, 36)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 30)
        }
    }
}

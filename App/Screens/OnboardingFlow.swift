import SwiftUI

/// First launch: splash, welcome, the first kid, a practice hold, then the Season Pass offer.
struct OnboardingFlow: View {
    private enum Step: Int {
        case splash
        case welcome
        case kid
        case practice
    }

    @Environment(AppModel.self) private var model
    @Environment(\.palette) private var palette
    @State private var step = Step.splash
    @State private var kidName = ""
    @State private var practiced = false
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            switch step {
            case .splash:
                SplashView {
                    step = .welcome
                }
            case .welcome:
                page(back: nil) {
                    welcome
                }
            case .kid:
                page(back: .welcome) {
                    kidPage
                }
            case .practice:
                page(back: .kid) {
                    practicePage
                }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
        .fullScreenCover(isPresented: $showPaywall, onDismiss: finish) {
            PaywallView(onFinish: {
                showPaywall = false
            })
        }
    }

    private func finish() {
        let name = kidName.trimmingCharacters(in: .whitespaces)
        let kid = name.isEmpty ? nil : Kid(name: name, colorIndex: 0)
        model.completeOnboarding(kid: kid)
    }

    private func page<Content: View>(back: Step?, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack {
                if let back {
                    Button {
                        step = back
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.bold))
                            .frame(width: 44, height: 44)
                            .background(palette.ink.opacity(0.06), in: Circle())
                    }
                    .accessibilityLabel(tr("Back"))
                }
                Spacer()
                Button(tr("Skip")) {
                    finish()
                }
                .font(.callout.weight(.semibold))
                .frame(minHeight: 44)
            }
            .foregroundStyle(palette.ink)
            .padding(.horizontal, 20)
            content()
        }
        .transition(.opacity)
    }

    // MARK: - Welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)
            cardFan
            Spacer(minLength: 20)
            VStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(tr("Daycare germs are"))
                    Text(tr("coming home."))
                        .foregroundStyle(palette.accent)
                }
                .font(.system(.largeTitle).weight(.bold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.center)
                Text(tr("In their first year of daycare, kids catch 12 to 15 respiratory bugs. You'll catch your share. Petri turns each one into a card, points and a good laugh."))
                    .font(.body)
                    .foregroundStyle(palette.inkSecondary)
                    .multilineTextAlignment(.center)
                Text(tr("Source: Clinical Microbiology Reviews, 2026"))
                    .font(.caption)
                    .foregroundStyle(palette.inkTertiary)
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 20)
            Button(tr("Start my season")) {
                step = .kid
            }
            .buttonStyle(PillButtonStyle(kind: .ink))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private var cardFan: some View {
        ZStack {
            if let left = model.catalog.germ("rhino") {
                GermCardView(germ: left, width: 132)
                    .rotationEffect(.degrees(-10))
                    .offset(x: -88, y: 14)
            }
            if let right = model.catalog.germ("noro") {
                GermCardView(germ: right, width: 132)
                    .rotationEffect(.degrees(10))
                    .offset(x: 88, y: 14)
            }
            if let center = model.catalog.germ("flu") {
                GermCardView(germ: center, width: 154, finish: .holo)
            }
        }
        .frame(height: 240)
        .accessibilityHidden(true)
    }

    // MARK: - First kid

    private var kidPage: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text(tr("Who's patient zero?"))
                            .font(.system(.largeTitle).weight(.bold))
                            .foregroundStyle(palette.ink)
                        Text(tr("The little one who brings it all home."))
                            .font(.body)
                            .foregroundStyle(palette.inkSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
                    ZStack(alignment: .bottom) {
                        AvatarView(name: kidName, gradient: AvatarColors.gradient(0), size: 108)
                            .padding(.bottom, 12)
                        PillLabel(text: tr("Patient zero"), foreground: palette.background, background: palette.ink)
                    }
                    TextField(tr("First name"), text: $kidName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .frame(minHeight: 54)
                        .foregroundStyle(palette.ink)
                        .padding(.horizontal, 16)
                        .petriCard(padding: 0)
                    Text(tr("Only a first name, and it never leaves this phone. More kids? Add them later in Settings."))
                        .font(.footnote)
                        .foregroundStyle(palette.inkTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            Button(tr("Next")) {
                step = .practice
            }
            .buttonStyle(PillButtonStyle(kind: .ink))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Practice

    private var practicePage: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text(tr("Sick? Tap this."))
                    .font(.system(.largeTitle).weight(.bold))
                    .foregroundStyle(palette.ink)
                Text(tr("When a germ gets you, tap the tile and pick it. Try it now. Nothing gets logged."))
                    .font(.body)
                    .foregroundStyle(palette.inkSecondary)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
            .padding(.top, 8)
            Spacer()
            VStack(spacing: 16) {
                FaceTile(tr("I'm sick")) {
                    Haptics.thud()
                    practiced = true
                } face: {
                    Image("mascot-awake").resizable().scaledToFit()
                }
                .frame(maxWidth: 190)
                Label(practiced ? tr("That's it. Nothing was logged.") : tr("Tap the tile to try."),
                      systemImage: practiced ? "checkmark.circle.fill" : "hand.tap")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(practiced ? palette.accent : palette.inkSecondary)
            }
            .padding(.horizontal, 24)
            Spacer()
            Button(tr("Continue")) {
                showPaywall = true
            }
            .buttonStyle(PillButtonStyle(kind: .ink))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

/// The animated intro: germs landing in the dish, then the wordmark.
private struct SplashView: View {
    private struct Resident: Identifiable {
        let id: String
        let size: CGFloat
        let x: CGFloat
        let y: CGFloat
        let angle: Double
    }

    let onDone: () -> Void
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dishIn = false
    @State private var landed = 0
    @State private var wordIn = false

    private let residents = [
        Resident(id: "germ-rhino", size: 104, x: -46, y: -40, angle: -12),
        Resident(id: "germ-noro", size: 96, x: 48, y: -50, angle: 10),
        Resident(id: "germ-flu", size: 112, x: 2, y: 34, angle: 0),
        Resident(id: "germ-coxy", size: 70, x: -71, y: 41, angle: -8),
        Resident(id: "germ-pinky", size: 64, x: 78, y: 32, angle: 12)
    ]

    var body: some View {
        VStack(spacing: 34) {
            ZStack {
                Image("dish")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .scaleEffect(dishIn ? 1 : 0.7)
                    .opacity(dishIn ? 1 : 0)
                ForEach(Array(residents.enumerated()), id: \.element.id) { item in
                    Image(item.element.id)
                        .resizable()
                        .scaledToFit()
                        .frame(width: item.element.size, height: item.element.size)
                        .rotationEffect(.degrees(item.element.angle))
                        .scaleEffect(landed > item.offset ? 1 : 0.01)
                        .opacity(landed > item.offset ? 1 : 0)
                        .offset(x: item.element.x, y: item.element.y)
                }
            }
            .frame(width: 300, height: 300)
            .accessibilityHidden(true)
            VStack(spacing: 10) {
                Wordmark(size: 68)
                Text(tr("Daycare germs, collected."))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(palette.inkSecondary)
            }
            .opacity(wordIn ? 1 : 0)
            .offset(y: wordIn ? 0 : 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            onDone()
        }
        .task {
            await play()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tr("Petri. Daycare germs, collected."))
    }

    private func play() async {
        if reduceMotion {
            dishIn = true
            landed = residents.count
            wordIn = true
            await pause(1.4)
            if !Task.isCancelled { onDone() }
            return
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            dishIn = true
        }
        await pause(0.28)
        for index in residents.indices {
            if Task.isCancelled { return }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) {
                landed = index + 1
            }
            Haptics.tap()
            await pause(0.13)
        }
        if Task.isCancelled { return }
        withAnimation(.easeOut(duration: 0.4)) {
            wordIn = true
        }
        await pause(1.3)
        if !Task.isCancelled { onDone() }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

/// The "petri" wordmark, with a germ as the dot of the i.
struct Wordmark: View {
    let size: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: "petr")
            Text(verbatim: "ı")
                .overlay(alignment: .top) {
                    dot
                        .offset(y: size * 0.1)
                }
        }
        .font(.system(size: size, weight: .bold))
        .kerning(-size * 0.03)
        .foregroundStyle(palette.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Petri"))
    }

    private var dot: some View {
        let diameter = size * 0.3
        return Circle()
            .fill(RadialGradient(colors: [Color(hex: Swatch.lilacPale), Color(hex: Swatch.lilac), Color(hex: Swatch.violetSoft)],
                                 center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: diameter * 0.7))
            .frame(width: diameter, height: diameter)
            .overlay {
                HStack(spacing: diameter * 0.14) {
                    Capsule().fill(Color(hex: Swatch.night)).frame(width: diameter * 0.16, height: diameter * 0.22)
                    Capsule().fill(Color(hex: Swatch.night)).frame(width: diameter * 0.16, height: diameter * 0.22)
                }
            }
            .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 2)
    }
}

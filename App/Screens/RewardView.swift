import SwiftUI

/// The payoff: the card drops in, points count up, badges and level follow.
struct RewardView: View {
    let reward: RewardResult

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var cardIn = false
    @State private var detailsIn = false
    @State private var shownPoints = 0
    @State private var levelFraction = 0.0
    @State private var confettiStart: Date?
    @State private var showShare = false
    /// The points figure, following the text size set in iOS up to a cap.
    @ScaledMetric(relativeTo: .largeTitle) private var pointsSize: CGFloat = 56

    private var germ: Germ { reward.germ }
    /// The worst severity gets a softer welcome: no confetti, a word of care.
    private var gentle: Bool { reward.log.severity >= 5 }
    private var finish: GermCardView.Finish { model.cardFinish(for: germ) }

    private var startFraction: Double {
        reward.levelAfter.number > reward.levelBefore.number ? 0 : reward.levelBefore.fraction
    }

    var body: some View {
        ZStack {
            background
            if let confettiStart, !reduceMotion {
                ConfettiView(start: confettiStart)
                    .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                heading
                    .opacity(detailsIn ? 1 : 0)
                    .offset(y: detailsIn ? 0 : 14)
                Spacer(minLength: 12)
                GermCardView(germ: germ, width: 220, finish: finish, count: model.count(of: germ.id), isNew: false)
                    .rotation3DEffect(.degrees(cardIn ? 0 : 540), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    .rotationEffect(.degrees(cardIn ? -3 : -20))
                    .scaleEffect(cardIn ? 1 : 0.6)
                    .offset(y: cardIn ? 0 : -640)
                    .opacity(cardIn ? 1 : 0)
                Spacer(minLength: 12)
                points
                    .opacity(detailsIn ? 1 : 0)
                extras
                    .opacity(detailsIn ? 1 : 0)
                    .offset(y: detailsIn ? 0 : 24)
                buttons
                    .opacity(detailsIn ? 1 : 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
        }
        .foregroundStyle(Color.white)
        .preferredColorScheme(.dark)
        .environment(\.palette, Palette.make(theme: .agar, scheme: .dark))
        .onAppear(perform: play)
        .sheet(isPresented: $showShare) {
            SharePreviewSheet(title: tr("Share card")) {
                GermShareCard(germ: germ, count: model.count(of: germ.id), finish: finish)
            }
        }
    }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.navyRaised), Color(hex: Swatch.navy)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [germ.deepTint.opacity(0.55), Color.clear], center: UnitPoint(x: 0.5, y: 0.4),
                           startRadius: 0, endRadius: 300)
            RingsBackground(color: Color.white.opacity(0.05), spacing: 36)
        }
        .ignoresSafeArea()
    }

    private var heading: some View {
        VStack(spacing: 8) {
            PillLabel(text: reward.isNewCard ? tr("New card") : tr("Repeat catch"),
                      foreground: Color(hex: Swatch.navy), background: Color(hex: Swatch.irisSoft))
            Text(reward.log.sufferer == .partner ? tr("%1$@ caught %2$@!", model.partnerDisplayName, germ.name)
                                                 : tr("You caught %@!", germ.name))
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
            Text(tr("Card %1$@ · %2$@ · From %3$@", germ.numberLabel, germ.rarity.label, model.sourceName(reward.log.source)))
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
            if gentle {
                Text(tr("Rough one. The points are banked, now go lie down."))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: Swatch.irisSoft))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var points: some View {
        VStack(spacing: 6) {
            Text(verbatim: "+\(shownPoints)")
                .font(.system(size: min(pointsSize, 84), weight: .bold))
                .foregroundStyle(Color(hex: Swatch.irisSoft))
                .contentTransition(.numericText())
                .monospacedDigit()
            Text(tr("Sick Points"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.65))
            HStack(spacing: 8) {
                ForEach(Array(reward.log.bonuses.enumerated()), id: \.offset) { item in
                    Text(bonusLabel(item.element))
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.1), in: Capsule())
                }
            }
            .padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
    }

    private func bonusLabel(_ bonus: LogBonus) -> String {
        switch bonus.kind {
        case .rarity: return tr("%1$@ catch +%2$lld", germ.rarity.label, bonus.points)
        case .nightShift: return tr("Night shift +%lld", bonus.points)
        case .recovery: return tr("Recovery +%lld", bonus.points)
        }
    }

    private var extras: some View {
        VStack(spacing: 10) {
            ForEach(reward.newBadges) { badge in
                unlockRow(symbol: badge.symbol, tint: Color(hex: badge.tint),
                          title: tr("Badge unlocked: %@", badge.title), detail: badge.detail)
            }
            ForEach(reward.unlockedIcons) { icon in
                unlockRow(symbol: "app.badge.fill", tint: Color(hex: Swatch.irisSoft),
                          title: tr("App icon unlocked: %@", icon.title), detail: tr("Find it in Settings."))
            }
            VStack(spacing: 7) {
                HStack {
                    Text(tr("Level %1$lld · %2$@", reward.levelAfter.number, reward.levelAfter.title))
                        .font(.footnote.weight(.semibold))
                    Spacer()
                    Text(tr("%1$lld / %2$lld pts", reward.levelAfter.progress, reward.levelAfter.span))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                ProgressView(value: levelFraction)
                    .tint(Color(hex: Swatch.irisSoft))
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
        .padding(.top, 16)
    }

    private func unlockRow(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay {
                    Circle().strokeBorder(tint, lineWidth: 2)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 68)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var buttons: some View {
        HStack(spacing: 10) {
            Button {
                showShare = true
            } label: {
                Label(tr("Share card"), systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.glass)
            Button {
                dismiss()
            } label: {
                Text(tr("Done"))
            }
            .buttonStyle(PillButtonStyle(kind: .ink))
        }
        .padding(.top, 18)
    }

    private func play() {
        levelFraction = startFraction
        guard !reduceMotion else {
            cardIn = true
            detailsIn = true
            shownPoints = reward.log.points
            levelFraction = reward.levelAfter.fraction
            return
        }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
            cardIn = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 650_000_000)
            if !gentle {
                confettiStart = Date()
            }
            SoundPlayer.shared.play(.reveal)
            Haptics.success()
            withAnimation(.easeOut(duration: 0.4)) {
                detailsIn = true
            }
            withAnimation(.easeOut(duration: 0.8)) {
                shownPoints = reward.log.points
            }
            try? await Task.sleep(nanoseconds: 750_000_000)
            if !reward.newBadges.isEmpty {
                SoundPlayer.shared.play(.badge)
            }
            withAnimation(.easeInOut(duration: 0.7)) {
                levelFraction = reward.levelAfter.fraction
            }
        }
    }
}

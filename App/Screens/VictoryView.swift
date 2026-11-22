import SwiftUI

/// After "I'm better": the boss knocked out, its phases cleared, the recovery points.
struct VictoryView: View {
    let victory: Victory

    @Environment(AppModel.self) private var model
    @Environment(CrewStore.self) private var crew
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var showShare = false
    /// The points figure, following the text size set in iOS up to a cap.
    @ScaledMetric(relativeTo: .largeTitle) private var pointsSize: CGFloat = 56

    private var germ: Germ { victory.germ }
    private var days: Int { victory.log.dayCount() }

    private var headline: String {
        switch victory.log.sufferer {
        case .me: return tr("You beat %@!", germ.name)
        case .partner: return tr("%1$@ beat %2$@!", model.partnerDisplayName, germ.name)
        case .both: return tr("You both beat %@!", germ.name)
        }
    }

    /// How this fight compares with the usual length, when the case file gives one.
    private var usualText: String? {
        guard let upTo = germ.lastsUpToDays else { return nil }
        return days > upTo ? tr("Longer than usual: %@", germ.lasts.value) : tr("Usual length: %@", germ.lasts.value)
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.navyRaised), Color(hex: Swatch.navy)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                PillLabel(text: tr("Boss defeated"), foreground: Color(hex: Swatch.navy),
                          background: Color(hex: Swatch.irisSoft))
                Text(headline)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                Text(germ.illness.value + " · " + trCount(days, one: "%lld day", other: "%lld days"))
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.65))
                BossKnockout(germ: germ)
                    .padding(.top, 6)
                Spacer(minLength: 8)
                Text(verbatim: "+\(victory.points)")
                    .font(.system(size: min(pointsSize, 84), weight: .bold))
                    .foregroundStyle(Color(hex: Swatch.irisSoft))
                    .monospacedDigit()
                Text(tr("Recovery points"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.65))
                if let usualText {
                    Text(usualText)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .background(Color.white.opacity(0.1), in: Capsule())
                }
                Spacer(minLength: 8)
                HStack(spacing: 10) {
                    Button {
                        showShare = true
                    } label: {
                        Label(tr("Share the win"), systemImage: "square.and.arrow.up")
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
            .scaleEffect(shown || reduceMotion ? 1 : 0.94)
            .opacity(shown || reduceMotion ? 1 : 0)
        }
        .foregroundStyle(Color.white)
        .preferredColorScheme(.dark)
        .environment(\.palette, Palette.make(theme: .nightShift, scheme: .dark))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                shown = true
            }
            SoundPlayer.shared.play(.badge)
            Haptics.success()
        }
        .task {
            await crew.reportWin(germ.id, logID: victory.log.id)
        }
        .sheet(isPresented: $showShare) {
            SharePreviewSheet(title: tr("Boss defeated")) {
                VictoryShareCard(germ: germ, days: days)
            }
        }
    }
}

/// The beaten boss: knocked-out art, an empty health bar and every phase checked.
private struct BossKnockout: View {
    let germ: Germ

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                LivelyCharacter(mood: .dizzy, pokes: false) {
                    GermImage(germ: germ, size: 140)
                        .saturation(0.6)
                }
                .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(germ.lightTint, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text(verbatim: "K.O.")
                    .font(.title3.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: Swatch.irisSoft), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .rotationEffect(.degrees(8))
                    .padding(12)
            }
            HStack(spacing: 10) {
                Text(tr("HP"))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Color(hex: Swatch.frost))
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 10)
                Text(verbatim: "0 / \(germ.rarity.bossHealth)")
                    .font(.footnote.weight(.bold))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 8) {
                ForEach(Array(germ.bossPhases.enumerated()), id: \.offset) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(hex: Swatch.irisSoft))
                        Text(item.element.name)
                            .font(.footnote.weight(.bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.1))
        }
    }
}

/// After a kid is marked better: their character over the knocked-out germ, and the score between them.
struct KidVictoryView: View {
    let victory: KidVictory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var confettiStart: Date?
    @State private var showShare = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: Swatch.navyRaised), Color(hex: Swatch.navy)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if let confettiStart, !reduceMotion {
                ConfettiView(start: confettiStart)
                    .ignoresSafeArea()
            }
            VStack(spacing: 12) {
                PillLabel(text: tr("Boss defeated"), foreground: Color(hex: Swatch.navy),
                          background: Color(hex: Swatch.irisSoft))
                Text(tr("%1$@ beat %2$@!", victory.kid.name, victory.germ.name))
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .lineLimit(2)
                Text(victory.germ.illness.value + " · " + trCount(victory.days, one: "%lld day", other: "%lld days"))
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.65))
                Spacer(minLength: 8)
                KidKnockout(look: victory.kid.colorIndex, germ: victory.germ, size: 150, lively: true)
                KidScore(name: victory.kid.name, wins: victory.wins, germ: victory.germ.name)
                    .padding(.top, 18)
                Text(tr("Back to full volume."))
                    .font(.title3.weight(.heavy))
                    .padding(.top, 10)
                Spacer(minLength: 8)
                HStack(spacing: 10) {
                    Button {
                        showShare = true
                    } label: {
                        Label(tr("Share the win"), systemImage: "square.and.arrow.up")
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
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)
            .scaleEffect(shown || reduceMotion ? 1 : 0.94)
            .opacity(shown || reduceMotion ? 1 : 0)
        }
        .foregroundStyle(Color.white)
        .preferredColorScheme(.dark)
        .environment(\.palette, Palette.make(theme: .nightShift, scheme: .dark))
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                shown = true
            }
            confettiStart = Date()
            SoundPlayer.shared.play(.badge)
            Haptics.success()
        }
        .sheet(isPresented: $showShare) {
            SharePreviewSheet(title: tr("Boss defeated")) {
                KidVictoryShareCard(victory: victory)
            }
        }
    }
}

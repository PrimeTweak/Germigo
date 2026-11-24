import StoreKit
import SwiftUI

/// After the first illness, once: the Season Pass's free trial, offered while the need is real.
/// "Not now" closes it with nothing else asked.
struct TrialOfferSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var legal: LegalKind?

    private let frost = Color(hex: Swatch.frost)
    private let glow = Color(hex: Swatch.irisSoft)

    var body: some View {
        Group {
            if let yearly = purchases.yearly, let days = purchases.trialDays {
                content(yearly, days: days)
            } else {
                Color.clear
                    .onAppear { dismiss() }
            }
        }
        .foregroundStyle(frost)
        .background(Color(hex: Swatch.navy).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .environment(\.palette, Palette.make(theme: .agar, scheme: .dark))
        .presentationDragIndicator(.visible)
        .sheet(item: $legal) { kind in
            NavigationStack {
                LegalScreen(kind: kind)
            }
        }
        .alert(tr("Purchase"), isPresented: errorBinding) {
            Button(tr("OK"), role: .cancel) {}
        } message: {
            Text(purchases.lastError ?? "")
        }
        .alert(tr("Waiting for approval"), isPresented: pendingBinding) {
            Button(tr("OK"), role: .cancel) {}
        } message: {
            Text(tr("Your purchase needs an approval. The Season Pass turns on by itself once it's approved."))
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { purchases.lastError != nil }, set: { if !$0 { purchases.lastError = nil } })
    }

    private var pendingBinding: Binding<Bool> {
        Binding(get: { purchases.pendingNotice }, set: { purchases.pendingNotice = $0 })
    }

    private func content(_ yearly: Product, days: Int) -> some View {
        let price = yearly.displayPrice + " " + tr("per year")
        let latest = latestIllness
        return ScrollView {
            VStack(spacing: 0) {
                hero(latest?.germ)
                Text(headline(for: latest?.person))
                    .font(.title2.weight(.bold))
                    .padding(.top, 26)
                Text(tr("Follow this one all the way, with the whole Season Pass. Free for %lld days.", days))
                    .font(.subheadline)
                    .opacity(0.72)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 12) {
                    benefit("camera.fill", tr("Photos, kept by illness"), tr("The rash on day 1, the thermometer on day 3"))
                    benefit("stethoscope", tr("A clean file for the doctor"), tr("Dates, signs and photos in one PDF"))
                    benefit("calendar", tr("The whole season"), tr("Every week stays, not just the last 7 days"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
                Button {
                    Task {
                        if await purchases.purchase(yearly) {
                            Haptics.success()
                            dismiss()
                        }
                    }
                } label: {
                    if purchases.isPurchasing {
                        ProgressView()
                            .tint(Color(hex: Swatch.navy))
                    } else {
                        Text(tr("Start my %lld-day free trial", days))
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .ink))
                .disabled(purchases.isPurchasing)
                .padding(.top, 22)
                Text(tr("%1$lld days free, then %2$@.", days, price) + " " + tr("Cancel anytime."))
                    .font(.footnote.weight(.semibold))
                    .opacity(0.85)
                    .padding(.top, 9)
                Button(tr("Not now")) {
                    dismiss()
                }
                .font(.callout.weight(.semibold))
                .foregroundStyle(frost.opacity(0.75))
                .frame(minHeight: 44)
                .padding(.top, 4)
                HStack(spacing: 18) {
                    Button(tr("Terms")) {
                        legal = .terms
                    }
                    Button(tr("Privacy")) {
                        legal = .privacy
                    }
                }
                .font(.footnote)
                .foregroundStyle(frost.opacity(0.6))
                .frame(minHeight: 44)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.page)
            .padding(.top, 34)
            .padding(.bottom, 16)
        }
        .buttonStyle(.plain)
    }

    /// The germ in a spotlight, with the stub of the Pass.
    private func hero(_ germ: Germ?) -> some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(frost)
                .frame(width: 120, height: 120)
                .shadow(color: glow.opacity(0.55), radius: 23)
            if let germ {
                GermImage(germ: germ, size: 100)
                    .frame(width: 120, height: 120)
            }
            Label(tr("Season Pass"), systemImage: "ticket.fill")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color(hex: Swatch.navy))
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(glow, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
                .rotationEffect(.degrees(-3))
                .offset(y: 15)
        }
        .accessibilityHidden(true)
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(glow)
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.08), in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .opacity(0.65)
            }
            .multilineTextAlignment(.leading)
        }
        .accessibilityElement(children: .combine)
    }

    /// The newest illness in the journal, and whose it is.
    private var latestIllness: (person: Person, germ: Germ?)? {
        let log = model.data.logs.max { $0.startedAt < $1.startedAt }
        let kid = model.data.kidIllnesses.max { $0.startedAt < $1.startedAt }
        if let kid, kid.startedAt >= (log?.startedAt ?? .distantPast) {
            return (.kid(kid.kidID), model.catalog.germ(kid.germID))
        }
        guard let log else { return nil }
        return (log.sufferer == .partner ? .partner : .me, model.catalog.germ(log.germID))
    }

    private func headline(for person: Person?) -> String {
        guard let person, person != .me else { return tr("Your first germ of the season.") }
        return tr("%@'s first germ of the season.", model.name(for: person))
    }
}

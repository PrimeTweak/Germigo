import StoreKit
import SwiftUI

/// The Season Pass offer. Prices and terms come from the App Store.
struct PaywallView: View {
    var onFinish: (() -> Void)?

    @Environment(PurchaseManager.self) private var purchases
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = PassProduct.yearlyID
    @State private var legal: LegalKind?

    private let backdrop = Color(hex: Swatch.nightBase)
    private let panel = Color(hex: Swatch.nightSurface)
    private let chalk = Color(hex: Swatch.chalk)
    private let lime = Color(hex: Swatch.lime)
    private let night = Color(hex: Swatch.night)

    private var selected: Product? {
        purchases.products.first { $0.id == selectedID }
    }

    /// The trial applies to the yearly plan only.
    private var trialDays: Int? {
        selectedID == PassProduct.yearlyID ? purchases.trialDays : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ticket
                VStack(spacing: 4) {
                    Text(tr("Survive the season."))
                    Text(tr("Together."))
                        .foregroundStyle(lime)
                }
                .font(.system(.title, design: .rounded).weight(.heavy))
                .multilineTextAlignment(.center)
                benefits
                if model.hasPass {
                    ownedCard
                } else if purchases.products.isEmpty {
                    unavailableCard
                } else {
                    plans
                    purchaseButton
                    disclosure
                }
                footerLinks
            }
            .foregroundStyle(chalk)
            .padding(.horizontal, 22)
            .padding(.top, 56)
            .padding(.bottom, 24)
        }
        .background(backdrop.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(chalk)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel(tr("Close"))
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
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

    private func close() {
        if let onFinish {
            onFinish()
        } else {
            dismiss()
        }
    }

    private var seasonYears: String {
        let year = Season.startYear(for: Date())
        return String(year) + "–" + String((year + 1) % 100)
    }

    private var ticket: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(tr("Petri · Admit one household").uppercased())
                    .font(.caption2.weight(.heavy))
                    .kerning(1.6)
                    .opacity(0.7)
                Text(tr("Season Pass").uppercased())
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .kerning(-1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            ZStack {
                TicketDash()
                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                    .foregroundStyle(night.opacity(0.3))
                    .frame(height: 2)
                    .padding(.horizontal, 20)
                HStack {
                    Circle().fill(backdrop).frame(width: 22, height: 22).offset(x: -11)
                    Spacer()
                    Circle().fill(backdrop).frame(width: 22, height: 22).offset(x: 11)
                }
            }
            HStack {
                Text(seasonYears)
                Spacer()
                Image(systemName: "ticket.fill")
            }
            .font(.subheadline.weight(.heavy))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .foregroundStyle(night)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [Color(hex: Swatch.limePale), Color(hex: Swatch.limeMid)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .rotationEffect(.degrees(-2))
        .padding(.horizontal, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Season Pass"))
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("person.2.fill", tr("Your whole household"), tr("Every kid in one journal"))
            if AppConfig.crewEnabled {
                benefit("dot.radiowaves.left.and.right", tr("Daycare Crew"), tr("An outbreak radar for your group"))
            }
            benefit("book.fill", tr("Every deep dive"), tr("The fun science on every germ, and every read"))
            benefit("sparkles", tr("Holo cards and extras"), tr("The Soup Bowl icon and the incubation widget"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(lime)
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
        }
        .accessibilityElement(children: .combine)
    }

    private var plans: some View {
        VStack(spacing: 10) {
            if let yearly = purchases.yearly {
                planRow(yearly, title: tr("Yearly"), badge: purchases.trialDays.map { tr("%lld days free", $0).uppercased() },
                        note: tr("%@ a month", (yearly.price / 12).formatted(yearly.priceFormatStyle)))
            }
            if let monthly = purchases.monthly {
                planRow(monthly, title: tr("Monthly"), badge: nil, note: nil)
            }
        }
    }

    private func planRow(_ product: Product, title: String, badge: String?, note: String?) -> some View {
        let isSelected = selectedID == product.id
        return Button {
            selectedID = product.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? lime : chalk.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(night)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(lime, in: Capsule())
                        }
                    }
                    if let note {
                        Text(note)
                            .font(.footnote)
                            .opacity(0.6)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(product.displayPrice)
                        .font(.title3.weight(.bold))
                    Text(periodLabel(product))
                        .font(.footnote)
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 70)
            .background(panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? lime : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func periodLabel(_ product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else { return "" }
        switch period.unit {
        case .year: return tr("per year")
        case .month: return tr("per month")
        case .week: return tr("per week")
        case .day: return tr("per day")
        @unknown default: return ""
        }
    }

    private var purchaseButton: some View {
        Button {
            guard let product = selected else { return }
            Task {
                if await purchases.purchase(product) {
                    Haptics.success()
                    close()
                }
            }
        } label: {
            if purchases.isPurchasing {
                ProgressView()
                    .tint(night)
            } else if let days = trialDays {
                Text(tr("Start my %lld-day free trial", days))
            } else {
                Text(tr("Subscribe"))
            }
        }
        .buttonStyle(PillButtonStyle(kind: .accent))
        .disabled(selected == nil || purchases.isPurchasing)
    }

    @ViewBuilder
    private var disclosure: some View {
        if let product = selected {
            let price = product.displayPrice + " " + periodLabel(product)
            VStack(spacing: 6) {
                if let days = trialDays {
                    Text(tr("%1$lld days free, then %2$@.", days, price))
                        .font(.footnote.weight(.semibold))
                } else {
                    Text(price)
                        .font(.footnote.weight(.semibold))
                }
                Text(tr("The Season Pass renews automatically until you cancel. Cancel at least 24 hours before the renewal date in your App Store account settings."))
                    .font(.caption)
                    .opacity(0.6)
                if product.isFamilyShareable {
                    Text(tr("Family Sharing is included."))
                        .font(.caption)
                        .opacity(0.6)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
    }

    private var ownedCard: some View {
        VStack(spacing: 12) {
            Label(tr("You have the Season Pass"), systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(lime)
            Button(tr("Done")) {
                close()
            }
            .buttonStyle(PillButtonStyle(kind: .accent))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var unavailableCard: some View {
        VStack(spacing: 12) {
            if purchases.isLoading {
                ProgressView()
                    .tint(chalk)
            } else {
                Text(purchases.loadFailed
                     ? tr("The App Store can't be reached right now. Check your connection and try again.")
                     : tr("The Season Pass isn't available right now. Try again later."))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .opacity(0.8)
                Button(tr("Try again")) {
                    Task {
                        await purchases.loadProducts()
                    }
                }
                .buttonStyle(PillButtonStyle(kind: .accent, height: 46))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var footerLinks: some View {
        HStack(spacing: 18) {
            Button(tr("Restore Purchases")) {
                Task {
                    let failure = await purchases.restore()
                    if model.hasPass {
                        close()
                    } else {
                        purchases.lastError = failure ?? tr("No Season Pass was found for this Apple Account.")
                    }
                }
            }
            Button(tr("Terms")) {
                legal = .terms
            }
            Button(tr("Privacy")) {
                legal = .privacy
            }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(chalk.opacity(0.75))
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

private struct TicketDash: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

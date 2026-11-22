import StoreKit
import SwiftUI

/// The Season Pass offer. It leads with the door the person touched, shows how the trial goes,
/// and keeps the button in reach. Prices and terms come from the App Store.
struct PaywallView: View {
    var reason = PassReason.general
    var onFinish: (() -> Void)?

    @Environment(PurchaseManager.self) private var purchases
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selectedID = PassProduct.yearlyID
    @State private var legal: LegalKind?

    private let backdrop = Color(hex: Swatch.navy)
    private let panel = Color(hex: Swatch.navySurface)
    private let frost = Color(hex: Swatch.frost)
    private let glow = Color(hex: Swatch.irisSoft)
    private let night = Color(hex: Swatch.navy)

    private var selected: Product? {
        purchases.products.first { $0.id == selectedID }
    }

    /// The trial applies to the yearly plan only.
    private var trialDays: Int? {
        selectedID == PassProduct.yearlyID ? purchases.trialDays : nil
    }

    private var isSelling: Bool {
        !model.hasPass && !purchases.products.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                VStack(spacing: 8) {
                    Text(reason.headline)
                        .font(.title.weight(.bold))
                    Text(reason.detail)
                        .font(.subheadline)
                        .opacity(0.72)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                if model.hasPass {
                    ownedCard
                } else if purchases.products.isEmpty {
                    unavailableCard
                } else {
                    if let days = trialDays, let product = selected {
                        timeline(TrialPlan(days: days), price: price(of: product))
                    }
                    plans
                }
                benefits
                if isSelling {
                    terms
                }
                footerLinks
            }
            .foregroundStyle(frost)
            .padding(.horizontal, Spacing.page)
            .padding(.top, 56)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isSelling {
                purchaseBar
            }
        }
        .background(backdrop.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(frost)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel(tr("Close"))
            .padding(.leading, 16)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
        .environment(\.palette, Palette.make(theme: .agar, scheme: .dark))
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

    /// The door's character in a spotlight, with the stub of the Pass.
    private var hero: some View {
        ZStack(alignment: .bottom) {
            Circle()
                .fill(frost)
                .frame(width: 140, height: 140)
                .shadow(color: glow.opacity(0.55), radius: 26)
            PassArt(reason: reason)
                .frame(width: 140, height: 140)
            HStack(spacing: 6) {
                Image(systemName: "ticket.fill")
                Text(tr("Season Pass"))
                Text(verbatim: seasonYears)
                    .opacity(0.65)
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(night)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(glow, in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .rotationEffect(.degrees(-3))
            .offset(y: 16)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(tr("Season Pass"))
        }
        .padding(.bottom, 16)
    }

    /// How the trial goes: today, the reminder, then the first payment.
    private func timeline(_ plan: TrialPlan, price: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            step(tr("Today"), tr("Everything opens. No charge."), isFirst: true, isLast: false)
            if let day = plan.reminderDay {
                step(trCount(day, one: "In %lld day", other: "In %lld days"),
                     tr("A reminder from Germily, if notifications are on."), isFirst: false, isLast: false)
            }
            step(trCount(plan.days, one: "In %lld day", other: "In %lld days"),
                 tr("The Pass starts: %@. Cancel before and pay nothing.", price), isFirst: false, isLast: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panel, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func step(_ title: String, _ detail: String, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isFirst ? glow : frost.opacity(0.32))
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(frost.opacity(0.18))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .opacity(0.68)
            }
            .padding(.bottom, isLast ? 0 : 14)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("Everything in the Season Pass"))
                .font(.headline)
            benefit("person.2.fill", tr("Your whole household"), tr("Your partner, the couple duel and every kid"))
            benefit("calendar", tr("The whole history"), tr("Past weeks, photos and the file for the doctor"))
            benefit("chart.bar.fill", tr("Your season in numbers"), tr("Top supplier, germs by month and the longest chain"))
            if AppConfig.crewEnabled {
                benefit("dot.radiowaves.left.and.right", tr("Daycare Crew"), tr("An outbreak radar for your group"))
            }
            benefit("sparkles", tr("Holo cards and extras"), tr("Icons, themes and the incubation widget"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 14) {
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
        }
        .accessibilityElement(children: .combine)
    }

    private var plans: some View {
        VStack(spacing: 10) {
            if let yearly = purchases.yearly {
                planRow(yearly, title: tr("Yearly"), badge: purchases.trialDays.map { tr("%lld days free", $0) },
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
                    .foregroundStyle(isSelected ? glow : frost.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(night)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(glow, in: Capsule())
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
            .frame(minHeight: 64)
            .background(panel, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
                    .strokeBorder(isSelected ? glow : Color.clear, lineWidth: 2)
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
        .buttonStyle(PillButtonStyle(kind: .ink))
        .disabled(selected == nil || purchases.isPurchasing)
    }

    private func price(of product: Product) -> String {
        product.displayPrice + " " + periodLabel(product)
    }

    /// The button and what it costs, always in reach at the bottom of the screen.
    private var purchaseBar: some View {
        VStack(spacing: 8) {
            purchaseButton
            if let product = selected {
                Group {
                    if let days = trialDays {
                        Text(tr("%1$lld days free, then %2$@.", days, price(of: product)) + " " + tr("Cancel anytime."))
                    } else {
                        Text(price(of: product) + ". " + tr("Cancel anytime."))
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(frost.opacity(0.85))
                .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, Spacing.page)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background(backdrop.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(frost.opacity(0.1))
                .frame(height: 1)
        }
    }

    private var terms: some View {
        VStack(spacing: 6) {
            Text(tr("The Season Pass renews automatically until you cancel. Cancel at least 24 hours before the renewal date in your App Store account settings."))
            if selected?.isFamilyShareable == true {
                Text(tr("Family Sharing is included."))
            }
        }
        .font(.caption)
        .opacity(0.6)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    private var ownedCard: some View {
        VStack(spacing: 12) {
            Label(tr("You have the Season Pass"), systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(glow)
            Button(tr("Done")) {
                close()
            }
            .buttonStyle(PillButtonStyle(kind: .ink))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(panel, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    private var unavailableCard: some View {
        VStack(spacing: 12) {
            if purchases.isLoading {
                ProgressView()
                    .tint(frost)
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
                .buttonStyle(PillButtonStyle(kind: .ink, height: 46))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(panel, in: RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
    }

    private var footerLinks: some View {
        HStack(spacing: 18) {
            Button(tr("Restore purchases")) {
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
        .foregroundStyle(frost.opacity(0.75))
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }
}

/// The character that stands for a door to the Season Pass.
private struct PassArt: View {
    let reason: PassReason
    @Environment(AppModel.self) private var model

    var body: some View {
        switch reason {
        case .general:
            LivelyCharacter(mood: .stalking) {
                picture("mascot-awake", side: 104)
            }
        case .household:
            HStack(alignment: .bottom, spacing: -14) {
                BuddyView(look: model.data.partnerLook, size: 46, lively: true)
                BuddyView(look: model.data.kids.first?.colorIndex ?? 0, size: 58, leads: true, pokes: true)
                BuddyView(look: model.data.hostLook, size: 46, lively: true)
            }
        case .history:
            picture("record-logbook", side: 100)
        case .photos:
            picture("record-album", side: 100)
        case .doctor:
            picture("record-doctor", side: 100)
        case .stats:
            BuddyView(look: Looks.crown, size: 78, leads: true, pokes: true)
        case .crew:
            HStack(spacing: -10) {
                picture("sticker-tissue", side: 46)
                picture("sticker-soup", side: 58)
                picture("sticker-tea", side: 46)
            }
        case .looks:
            HStack(spacing: -8) {
                icon("icon-preview-snowDay", tilt: -9)
                icon("icon-preview-golden", tilt: 0)
                icon("icon-preview-holo", tilt: 9)
            }
        case .holo:
            if let germ = model.catalog.germs.max(by: { model.count(of: $0.id) < model.count(of: $1.id) }) {
                GermCardView(germ: germ, width: 68, finish: .holo)
                    .rotationEffect(.degrees(4))
            }
        }
    }

    private func picture(_ name: String, side: CGFloat) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }

    private func icon(_ name: String, tilt: Double) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
            .rotationEffect(.degrees(tilt))
            .accessibilityHidden(true)
    }
}

/// The tear line across a ticket.
struct TicketDash: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

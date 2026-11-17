import Foundation
import Observation
import StoreKit

/// Product identifiers, as created in App Store Connect.
enum PassProduct {
    static let yearlyID = "ca.petri.app.pass.yearly"
    static let monthlyID = "ca.petri.app.pass.monthly"
    static let all = [yearlyID, monthlyID]
}

/// Season Pass products and entitlement, through StoreKit 2.
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    private(set) var products: [Product] = []
    private(set) var storePass = false
    private(set) var activeProductID: String?
    private(set) var introEligible = false
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    var lastError: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task { [weak self] in
            await self?.loadProducts()
            await self?.refreshEntitlements()
        }
    }

    var hasPass: Bool {
        #if PETRI_SIDELOAD
        if AppModel.shared.data.settings.sideloadPass { return true }
        #endif
        return storePass
    }

    var yearly: Product? {
        products.first { $0.id == PassProduct.yearlyID }
    }

    var monthly: Product? {
        products.first { $0.id == PassProduct.monthlyID }
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: PassProduct.all)
            if let subscription = yearly?.subscription {
                introEligible = await subscription.isEligibleForIntroOffer
            }
        } catch {
            products = []
        }
    }

    func refreshEntitlements() async {
        var active: String?
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.revocationDate == nil,
               PassProduct.all.contains(transaction.productID) {
                active = transaction.productID
            }
        }
        activeProductID = active
        storePass = active != nil
        AppModel.shared.passDidChange()
    }

    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                await refreshEntitlements()
                return hasPass
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    /// The free trial length in days, when the yearly plan offers one.
    var trialDays: Int? {
        guard introEligible, let offer = yearly?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        switch offer.period.unit {
        case .day: return offer.period.value
        case .week: return offer.period.value * 7
        case .month: return offer.period.value * 30
        case .year: return offer.period.value * 365
        @unknown default: return nil
        }
    }
}

import Foundation
import Observation
import StoreKit

/// Product identifiers, as created in App Store Connect.
enum PassProduct {
    static let yearlyID = "ca.germigo.app.pass.yearly"
    static let monthlyID = "ca.germigo.app.pass.monthly"
    static let all = [yearlyID, monthlyID]
}

/// The tip jar: three consumable soups, as created in App Store Connect.
enum TipProduct {
    static let smallID = "ca.germigo.app.tip.small"
    static let mediumID = "ca.germigo.app.tip.medium"
    static let largeID = "ca.germigo.app.tip.large"
    static let all = [smallID, mediumID, largeID]
}

/// Season Pass products and entitlement, through StoreKit 2.
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()

    private(set) var products: [Product] = []
    /// The tip jar's products, cheapest first.
    private(set) var tips: [Product] = []
    private(set) var storePass = false
    private(set) var activeProductID: String?
    private(set) var introEligible = false
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    var lastError: String?

    /// True when the App Store could not be asked for the products at all.
    private(set) var loadFailed = false

    /// Set when a purchase waits for an approval, such as Ask to Buy.
    var pendingNotice = false

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
        #if GERMIGO_SIDELOAD
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
            let found = try await Product.products(for: PassProduct.all + TipProduct.all)
            products = found.filter { PassProduct.all.contains($0.id) }
            tips = found.filter { TipProduct.all.contains($0.id) }.sorted { $0.price < $1.price }
            loadFailed = false
            if let subscription = yearly?.subscription {
                introEligible = await subscription.isEligibleForIntroOffer
            }
        } catch {
            products = []
            tips = []
            loadFailed = true
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
            case .pending:
                pendingNotice = true
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Buys one soup from the tip jar; true once Apple confirms it.
    func tip(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                return true
            case .pending:
                pendingNotice = true
                return false
            default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Syncs with the App Store; returns the error text when the sync fails.
    func restore() async -> String? {
        var failure: String?
        do {
            try await AppStore.sync()
        } catch {
            failure = error.localizedDescription
        }
        await refreshEntitlements()
        return failure
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

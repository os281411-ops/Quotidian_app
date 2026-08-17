import Combine
import Foundation
import StoreKit

/// Manages Quotidian Premium: product loading, purchases, restores, and the
/// current entitlement state, all via StoreKit 2 (no backend involved — the
/// device verifies its own receipts against Apple's signed transactions).
@MainActor
final class SubscriptionManager: ObservableObject {
    static let monthlyID = "com.oliverscott.Quotidian.premium.monthly"
    static let annualID = "com.oliverscott.Quotidian.premium.annual"
    private static let productIDs = [monthlyID, annualID]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isSubscribed = false
    @Published private(set) var isLoadingProducts = false
    @Published var purchaseError: String?

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// Loads the products, retrying a few times with backoff. A single
    /// `Product.products(for:)` call can come back empty or throw while the
    /// device is still establishing its App Store session (cold launch, slow
    /// network, a storefront that hasn't settled yet), so one attempt is not
    /// enough to conclude the products don't exist.
    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        purchaseError = nil

        let delays: [Duration] = [.zero, .seconds(1), .seconds(2), .seconds(4)]
        for delay in delays {
            if delay != .zero {
                try? await Task.sleep(for: delay)
            }
            if Task.isCancelled { return }
            do {
                let fetched = try await Product.products(for: Self.productIDs)
                if !fetched.isEmpty {
                    products = fetched.sorted { $0.price < $1.price }
                    purchaseError = nil
                    return
                }
            } catch {
                continue
            }
        }

        if products.isEmpty {
            purchaseError = "Couldn't load subscription options. Check your connection and try again."
        }
    }

    func purchase(_ product: Product) async {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed. Please try again."
        }
    }

    func restorePurchases() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = "Couldn't restore purchases."
        }
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        var subscribed = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productType == .autoRenewable,
               transaction.revocationDate == nil {
                subscribed = true
            }
        }
        isSubscribed = subscribed
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self, let transaction = try? self.checkVerified(result) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private enum StoreError: Error {
        case failedVerification
    }
}

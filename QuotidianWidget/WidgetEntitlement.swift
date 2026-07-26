import StoreKit

/// StoreKit 2 entitlements are OS-level and readable from any process for the
/// app (including its extensions) without an App Group — so the widget can
/// check subscription status directly, independent of the host app process.
enum WidgetEntitlement {
    static func isSubscribed() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }
}

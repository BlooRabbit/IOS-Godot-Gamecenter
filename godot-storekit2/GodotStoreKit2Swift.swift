import Foundation
import StoreKit

@objc public class GodotStoreKit2: NSObject {

    @objc public static let shared = GodotStoreKit2()

    private var cachedProducts: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    private override init() {
        super.init()
        startListeningForTransactionUpdates()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Public API (Obj-C / GDScript friendly)

    /// Load products by identifiers. Returns an NSArray of NSDictionary.
    @objc public func loadProducts(_ productIds: [String], completion: @escaping (NSArray, NSError?) -> Void) {
        Task.detached { [weak self] in
            do {
                let ids = Set(productIds)
                let products = try await Product.products(for: ids)

                // cache
                var cache: [String: Product] = [:]
                products.forEach { cache[$0.id] = $0 }
                self?.cachedProducts.merge(cache) { _, new in new }

                let out = products.compactMap { self?.productToDict($0) } as NSArray
                completion(out, nil)
            } catch {
                completion([], error as NSError)
            }
        }
    }

    /// Purchase a product by id. Returns a NSDictionary with status.
    @objc public func purchase(_ productId: String, completion: @escaping (NSDictionary, NSError?) -> Void) {
        Task.detached { [weak self] in
            do {
                guard let product = try await self?.loadOrFetchProduct(productId) else {
                    completion([:] as NSDictionary, NSError(domain: "GodotStoreKit2", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found"]))
                    return
                }

                let result = try await product.purchase()

                switch result {
                case .success(let vr):
                    switch vr {
                    case .verified(let transaction):
                        await transaction.finish()
                        let dict: [String: Any] = [
                            "status": "success",
                            "product_id": transaction.productID,
                            "transaction_id": String(transaction.id),
                            "original_transaction_id": String(transaction.originalID),
                            "ownership_type": self?.ownershipString(transaction.ownershipType) ?? "unknown"
                        ]
                        completion(dict as NSDictionary, nil)

                    case .unverified(_, let verificationError):
                        let err = NSError(domain: "GodotStoreKit2", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unverified transaction", NSUnderlyingErrorKey: verificationError])
                        completion([:] as NSDictionary, err)
                    }

                case .userCancelled:
                    completion(["status": "user_cancelled"] as NSDictionary, nil)

                case .pending:
                    completion(["status": "pending"] as NSDictionary, nil)

                @unknown default:
                    completion(["status": "unknown"] as NSDictionary, nil)
                }

            } catch {
                completion([:] as NSDictionary, error as NSError)
            }
        }
    }

    /// Restore purchases (sync + return current entitlements)
    @objc public func restorePurchases(completion: @escaping (NSArray, NSError?) -> Void) {
        Task.detached {
            do {
                try await AppStore.sync()
                var owned: [String] = []
                for await entitlement in Transaction.currentEntitlements {
                    if case .verified(let t) = entitlement {
                        owned.append(t.productID)
                    }
                }
                completion(owned as NSArray, nil)
            } catch {
                completion([] as NSArray, error as NSError)
            }
        }
    }

    /// Check if a single product id is currently entitled.
    @objc public func isEntitled(_ productId: String, completion: @escaping (Bool) -> Void) {
        Task.detached {
            for await entitlement in Transaction.currentEntitlements {
                if case .verified(let t) = entitlement, t.productID == productId {
                    completion(true)
                    return
                }
            }
            completion(false)
        }
    }

    /// Check multiple ids. Returns NSDictionary: { id: Bool }
    @objc public func areEntitled(_ productIds: [String], completion: @escaping (NSDictionary) -> Void) {
        Task.detached {
            var map = [String: Bool]()
            productIds.forEach { map[$0] = false }

            for await entitlement in Transaction.currentEntitlements {
                if case .verified(let t) = entitlement, map.keys.contains(t.productID) {
                    map[t.productID] = true
                }
            }
            completion(map as NSDictionary)
        }
    }

    // MARK: - Transaction updates (post notifications for Obj-C layer)

    private func startListeningForTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                switch update {
                case .verified(let t):
                    await t.finish()
                    self.postTransactionNotification(t, verified: true)
                case .unverified(let t, _):
                    self.postTransactionNotification(t, verified: false)
                }
            }
        }
    }

    private func postTransactionNotification(_ t: Transaction, verified: Bool) {
        let payload: [String: Any] = [
            "product_id": t.productID,
            "transaction_id": String(t.id),
            "original_transaction_id": String(t.originalID),
            "verified": verified,
            "ownership_type": ownershipString(t.ownershipType)
        ]
        NotificationCenter.default.post(name: .godotSK2TransactionUpdate, object: nil, userInfo: payload)
    }

    // MARK: - Helpers

    private func loadOrFetchProduct(_ id: String) async throws -> Product {
        if let p = cachedProducts[id] { return p }
        let products = try await Product.products(for: [id])
        guard let p = products.first(where: { $0.id == id }) else {
            throw NSError(domain: "GodotStoreKit2", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
        }
        cachedProducts[id] = p
        return p
    }

    private func productToDict(_ product: Product) -> NSDictionary {
        // Prefer Apple’s already localized, formatted price string.
        let displayPrice = product.displayPrice

        // Raw price decimal & best-effort currency code.
        let rawPrice: NSDecimalNumber = NSDecimalNumber(decimal: product.price)
        let currencyCode: String? = product.priceFormatStyle.currencyCode

        var dict: [String: Any] = [
            "id": product.id,
            "display_name": product.displayName,
            "price_string": displayPrice,
            "raw_price": rawPrice
        ]

        if let currencyCode {
            dict["currency_code"] = currencyCode
        }

        dict["type"] = productTypeString(product.type)

        if let sub = product.subscription {
            dict["subscription"] = subscriptionToDict(sub)
        }

        return dict as NSDictionary
    }

    private func subscriptionToDict(_ sub: Product.SubscriptionInfo) -> NSDictionary {
        var d: [String: Any] = [:]

        if let period = sub.subscriptionPeriod {
            d["period_unit"] = period.unitString
            d["period_value"] = period.value
        }

        if let intro = sub.introductoryOffer {
            d["introductory_offer"] = offerToDict(intro)
        }

        if let trial = sub.trialOffer {
            d["trial_offer"] = offerToDict(trial)
        }

        d["group_id"] = sub.subscriptionGroupID

        return d as NSDictionary
    }

    private func offerToDict(_ offer: Product.SubscriptionOffer) -> NSDictionary {
        var d: [String: Any] = [:]
        d["display_price"] = offer.displayPrice
        if let period = offer.period {
            d["period_unit"] = period.unitString
            d["period_value"] = period.value
        }
        d["type"] = offer.typeString
        return d as NSDictionary
    }

    private func ownershipString(_ t: Transaction.OwnershipType) -> String {
        switch t {
        case .purchased: return "purchased"
        case .familyShared: return "family_shared"
        @unknown default: return "unknown"
        }
    }

    private func productTypeString(_ type: Product.ProductType) -> String {
        switch type {
        case .consumable: return "consumable"
        case .nonConsumable: return "non_consumable"
        case .autoRenewable: return "auto_renewable"
        case .nonRenewable: return "non_renewable"
        @unknown default: return "unknown"
        }
    }
}

private extension Product.SubscriptionPeriod.Unit {
    var unitString: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "unknown"
        }
    }
}

private extension Product.SubscriptionOffer.OfferType {
    var typeString: String {
        switch self {
        case .introductory: return "introductory"
        case .promotional: return "promotional"
        case .freeTrial: return "free_trial"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - Notification name your Obj-C layer can observe
public extension Notification.Name {
    static let godotSK2TransactionUpdate = Notification.Name("GodotSK2TransactionUpdate")
}

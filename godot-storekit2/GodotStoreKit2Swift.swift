//
//  GodotStoreKit2Swift.swift
//  godot-storekit2
//
//  Minimal StoreKit 2 bridge for Obj-C / Godot.
//  iOS 15.0+
//

import Foundation
import StoreKit

@objc public final class GodotStoreKit2Swift: NSObject {

    // MARK: - Singleton

    @objc public static let shared = GodotStoreKit2Swift()

    private override init() {
        super.init()
        startObservingTransactionUpdates()
    }

    // MARK: - Storage

    private var productsCache: [String: Product] = [:]     // by productID
    private var updatesTask: Task<Void, Never>?

    // MARK: - Public (Obj-C friendly) API

    /// Load products for the given identifiers.
    /// - Parameters:
    ///   - identifiers: Array of product IDs (NSString/Swift String).
    ///   - completion: Called with NSArray<NSDictionary> describing products or empty array on failure.
    @objc public func loadProducts(_ identifiers: [String],
                                   completion: @escaping (NSArray) -> Void) {
        Task {
            do {
                let storeProducts = try await Product.products(for: identifiers)
                // Cache
                for p in storeProducts {
                    productsCache[p.id] = p
                }
                let bridged = storeProducts.map { self.productToDictionary($0) } as NSArray
                completion(bridged)
            } catch {
                // On error, return empty array to Obj-C
                completion(NSArray())
            }
        }
    }

    /// Purchase a product by identifier.
    /// - Returns NSDictionary with simple status payload.
    @objc public func purchase(_ productID: String,
                               completion: @escaping (NSDictionary) -> Void) {
        Task {
            guard let product = try? await fetchProduct(id: productID) else {
                completion([
                    "ok": false,
                    "error": "product_not_found",
                    "productID": productID
                ] as NSDictionary)
                return
            }

            do {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    guard case .verified(let transaction) = verification else {
                        completion(["ok": false,
                                    "error": "unverified_transaction"] as NSDictionary)
                        return
                    }
                    // Finish the transaction
                    await transaction.finish()
                    completion([
                        "ok": true,
                        "status": "purchased",
                        "productID": transaction.productID,
                        "id": transaction.id
                    ] as NSDictionary)

                case .userCancelled:
                    completion([
                        "ok": false,
                        "error": "user_cancelled"
                    ] as NSDictionary)

                case .pending:
                    completion([
                        "ok": true,
                        "status": "pending",
                        "productID": productID
                    ] as NSDictionary)

                @unknown default:
                    completion([
                        "ok": false,
                        "error": "unknown_purchase_result"
                    ] as NSDictionary)
                }
            } catch {
                completion([
                    "ok": false,
                    "error": "\(error)"
                ] as NSDictionary)
            }
        }
    }

    /// Restore purchases (non-consumables + active subscriptions).
    /// - Returns NSArray of productIDs restored.
    @objc public func restorePurchases(_ completion: @escaping (NSArray) -> Void) {
        Task {
            do {
                // In StoreKit 2, you generally re-check entitlements; can also call AppStore.sync()
                try? await AppStore.sync()
                var restored: [String] = []
                for await result in Transaction.currentEntitlements {
                    guard case .verified(let tx) = result else { continue }
                    restored.append(tx.productID)
                }
                completion(restored as NSArray)
            } catch {
                completion(NSArray())
            }
        }
    }

    /// Check if the user is currently entitled to a product (non-consumable or active subscription).
    /// - Returns NSDictionary { "productID": String, "entitled": Bool }
    @objc public func isEntitled(to productID: String,
                                 completion: @escaping (NSDictionary) -> Void) {
        Task {
            let entitled = await isEntitled(productID: productID)
            completion([
                "productID": productID,
                "entitled": entitled
            ] as NSDictionary)
        }
    }

    /// Check entitlement for multiple productIDs.
    /// - Returns NSArray of NSDictionary (one per productID).
    @objc public func areEntitled(_ productIDs: [String],
                                  completion: @escaping (NSArray) -> Void) {
        Task {
            let set = Set(productIDs)
            var entitledIDs: Set<String> = []
            for await result in Transaction.currentEntitlements {
                guard case .verified(let tx) = result else { continue }
                if set.contains(tx.productID) {
                    entitledIDs.insert(tx.productID)
                }
            }
            let payload: [NSDictionary] = productIDs.map { id in
                ["productID": id, "entitled": entitledIDs.contains(id)] as NSDictionary
            }
            completion(payload as NSArray)
        }
    }

    // MARK: - Internals

    private func startObservingTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let tx) = update else { continue }
                // Always finish to keep the queue clean.
                await tx.finish()
                // You could post a NotificationCenter message here if your Obj-C layer wants it.
                self?.notifyTransactionUpdate(tx)
            }
        }
    }

    private func notifyTransactionUpdate(_ tx: Transaction) {
        // Example notification. Obj-C side can subscribe to this if desired.
        let name = Notification.Name("GodotStoreKit2TransactionUpdate")
        NotificationCenter.default.post(name: name,
                                        object: nil,
                                        userInfo: [
                                            "productID": tx.productID,
                                            "id": tx.id,
                                            "date": tx.purchaseDate
                                        ])
    }

    private func fetchProduct(id: String) async throws -> Product {
        if let cached = productsCache[id] {
            return cached
        }
        let products = try await Product.products(for: [id])
        guard let p = products.first else {
            throw NSError(domain: "GodotStoreKit2Swift", code: 404, userInfo: [NSLocalizedDescriptionKey: "Product not found"])
        }
        productsCache[id] = p
        return p
    }

    /// Correct entitlement check (fixes your compile error).
    private func isEntitled(productID: String) async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let tx) = result else { continue }
            if tx.productID == productID {
                return true
            }
        }
        return false
    }

    // MARK: - Bridging helpers

    private func productToDictionary(_ p: Product) -> NSDictionary {
        var dict: [String: Any] = [
            "id": p.id,
            "type": p.type.rawValue,
            "displayName": p.displayName,
            "description": p.description
        ]

        if let subscription = p.subscription {
            dict["subscriptionPeriod"] = periodToString(subscription.subscriptionPeriod)
            dict["subscriptionGroupID"] = subscription.subscriptionGroupID
        }

        if let price = p.displayPrice as String? {
            dict["displayPrice"] = price
        }

        if let priceFormat = priceFormat(for: p) {
            dict["priceLocale"] = priceFormat.locale.identifier
            dict["currencyCode"] = priceFormat.currencyCode ?? ""
            dict["currencySymbol"] = priceFormat.currencySymbol
        }

        return dict as NSDictionary
    }

    private func priceFormat(for product: Product) -> NumberFormatter? {
        guard let price = try? product.price,
              let locale = price.locale else { return nil }
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = locale
        nf.currencyCode = price.currencyCode
        return nf
    }

    private func periodToString(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return "P\(period.value)D"
        case .week: return "P\(period.value)W"
        case .month: return "P\(period.value)M"
        case .year: return "P\(period.value)Y"
        @unknown default: return "P\(period.value)"
        }
    }
}

// MARK: - Small conveniences

private extension Product.ProductType {
    var rawValue: String {
        switch self {
        case .consumable: return "consumable"
        case .nonConsumable: return "nonConsumable"
        case .autoRenewable: return "autoRenewable"
        case .nonRenewable: return "nonRenewable"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }
}

@available(iOS 15.0, *)
private extension Product {
    var description: String {
        // Product already has a `description` property, but we make sure it’s always non-empty
        // for bridge safety if you adapt for older baselines.
        return self.subscription?.displayName ?? self.displayName
    }
}

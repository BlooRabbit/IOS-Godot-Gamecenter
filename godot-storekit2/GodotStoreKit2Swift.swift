//
//  GodotStoreKit2Swift.swift
//  godot-storekit2
//
//  Minimal StoreKit 2 bridge helpers for ObjC++ interop (Xcode 16.2 / Swift 5.9)
//

import Foundation
import StoreKit

@objc public final class GodotStoreKit2Swift: NSObject {
    // NOTE: Do NOT mark a stored static property @objc; Objective-C has no equivalent.
    public static let shared = GodotStoreKit2Swift()
    private override init() {}

    // MARK: - Public surface used from ObjC/ObjC++

    /// Convert a StoreKit 2 `Product` into a JSON-friendly dictionary.
    /// Call this from Objective-C++ and serialize as needed.
    @objc public func productDictionary(from product: Product) -> [String: Any] {
        var dict: [String: Any] = [
            "id": product.id,
            "displayName": product.displayName,
            "description": product.description,
            "price": product.displayPrice,
            "type": mapProductType(product.type),
        ]

        // Decimal -> NSNumber for ObjC friendliness
        dict["priceDecimal"] = NSDecimalNumber(decimal: product.price)

        // Subscription-specific fields
        if let sub = product.subscription {
            // Non-optional in modern SDKs
            dict["subscriptionGroupID"] = sub.subscriptionGroupID

            let basePeriod = sub.subscriptionPeriod
            dict["subscriptionPeriodValue"] = basePeriod.value
            dict["subscriptionPeriodUnit"]  = mapPeriodUnit(basePeriod.unit)

            // Introductory offer
            if let intro = sub.introductoryOffer {
                dict["introductoryOffer"] = subscriptionOfferDictionary(from: intro)
            }

            // Promotional offers
            let promos = sub.promotionalOffers
            if !promos.isEmpty {
                dict["promotionalOffers"] = promos.map { subscriptionOfferDictionary(from: $0) }
            }
        }

        return dict
    }

    // MARK: - Offer / Period mapping

    /// Convert a `Product.SubscriptionOffer` to a dictionary WITHOUT using numberOfPeriods.
    private func subscriptionOfferDictionary(from offer: Product.SubscriptionOffer) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["identifier"]  = offer.id
        dict["paymentMode"] = mapPaymentMode(offer.paymentMode)
        dict["offerType"]   = mapOfferType(offer.type)

        // Period describes the cadence of the offer (value + unit)
        let p = offer.period
        dict["periodValue"] = p.value
        dict["periodUnit"]  = mapPeriodUnit(p.unit)

        // Decimal -> NSNumber for ObjC friendliness
        dict["priceDecimal"] = NSDecimalNumber(decimal: offer.price)

        return dict
    }

    // MARK: - Enum mappers (exhaustive + @unknown default)

    private func mapProductType(_ t: Product.ProductType) -> String {
        switch t {
        case .autoRenewable:   return "autoRenewable"
        case .nonRenewable:    return "nonRenewable"
        case .consumable:      return "consumable"
        case .nonConsumable:   return "nonConsumable"
        case .unknown:         return "unknown"
        @unknown default:      return "unknown"
        }
    }

    private func mapPeriodUnit(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day:   return "day"
        case .week:  return "week"
        case .month: return "month"
        case .year:  return "year"
        @unknown default:
            return "unknown"
        }
    }

    private func mapPaymentMode(_ mode: Product.SubscriptionOffer.PaymentMode) -> String {
        switch mode {
        case .payAsYouGo: return "payAsYouGo"
        case .payUpFront: return "payUpFront"
        case .freeTrial:  return "freeTrial"
        @unknown default:
            return "unknown"
        }
    }

    private func mapOfferType(_ type: Product.SubscriptionOffer.OfferType) -> String {
        switch type {
        case .introductory: return "introductory"
        case .promotional:  return "promotional"
        @unknown default:
            return "unknown"
        }
    }
}

// MARK: - Convenience wrappers often used by ObjC++ layer

@objc public extension GodotStoreKit2Swift {
    /// Loads products for the given identifiers and returns an array of dictionaries.
    @objc func loadProducts(_ ids: [String]) async throws -> [[String: Any]] {
        let result = try await Product.products(for: ids)
        return result.map { productDictionary(from: $0) }
    }

    /// Begins a purchase and returns a simple result dictionary.
    @objc func purchase(_ productId: String) async throws -> [String: Any] {
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
            return ["status": "error", "reason": "product_not_found"]
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return [
                "status": "success",
                "productId": productId,
                "transactionId": String(transaction.id),
                "originalPurchaseDate": ISO8601DateFormatter().string(from: transaction.originalPurchaseDate)
            ]
        case .userCancelled:
            return ["status": "cancelled"]
        case .pending:
            return ["status": "pending"]
        @unknown default:
            return ["status": "unknown"]
        }
    }

    /// Restores purchases; returns an array of transaction info dictionaries.
    @objc func restorePurchases() async -> [[String: Any]] {
        var out: [[String: Any]] = []

        for await result in Transaction.currentEntitlements {
            guard let t = try? checkVerified(result) else { continue }
            out.append(transactionDictionary(from: t))
        }
        return out
    }
}

// MARK: - Verification helpers

private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
        throw NSError(domain: "godot-storekit2", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transaction unverified"])
    case .verified(let safe):
        return safe
    }
}

// MARK: - Transaction mapping

private func transactionDictionary(from t: Transaction) -> [String: Any] {
    var dict: [String: Any] = [
        "productId": t.productID,
        "transactionId": String(t.id),
        "originalPurchaseDate": ISO8601DateFormatter().string(from: t.originalPurchaseDate),
        "purchaseDate": ISO8601DateFormatter().string(from: t.purchaseDate),
        "revocationDate": t.revocationDate.map { ISO8601DateFormatter().string(from: $0) } as Any,
        "revocationReason": mapRevocationReason(t.revocationReason),
        "environment": mapEnvironment(t.environment),
        "ownershipType": mapOwnershipType(t.ownershipType),
    ]

    if let exp = t.expirationDate {
        dict["expirationDate"] = ISO8601DateFormatter().string(from: exp)
    }
    return dict
}

private func mapRevocationReason(_ r: Transaction.RevocationReason?) -> String {
    guard let r else { return "none" }
    switch r {
    case .refund: return "refund"
    case .revoked: return "revoked"
    @unknown default: return "unknown"
    }
}

private func mapEnvironment(_ e: StoreKit.Environment) -> String {
    switch e {
    case .sandbox: return "sandbox"
    case .production: return "production"
    @unknown default: return "unknown"
    }
}

private func mapOwnershipType(_ o: Transaction.OwnershipType) -> String {
    switch o {
    case .purchased: return "purchased"
    case .familyShared: return "familyShared"
    @unknown default: return "unknown"
    }
}

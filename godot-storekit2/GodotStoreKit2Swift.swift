//
//  GodotStoreKit2Swift.swift
//  godot-storekit2
//
//  Minimal StoreKit 2 bridge helpers for serialization.
//  Tested with Xcode 16.2 (iOS SDK 18.2), Swift 5.9
//

import Foundation
import StoreKit

@objc public final class GodotStoreKit2Swift: NSObject {

    // MARK: - Public API (example entry points you can call from Objective-C / Godot)

    /// Serialize a StoreKit 2 Product to a basic dictionary you can pass across a bridge.
    @objc public func serialize(product: Product) -> [String: Any] {
        var d: [String: Any] = [:]
        d["id"]            = product.id
        d["display_name"]  = product.displayName
        d["description"]   = product.description
        d["display_price"] = product.displayPrice
        d["type"]          = productTypeString(product.type)

        if let sub = product.subscription {
            d["subscription"] = serialize(subscription: sub)
        }

        return d
    }

    /// Convenience: serialize an array of products.
    @objc public func serialize(products: [Product]) -> [[String: Any]] {
        return products.map { serialize(product: $0) }
    }

    // MARK: - Subscription serialization

    private func serialize(subscription sub: Product.SubscriptionInfo) -> [String: Any] {
        var d: [String: Any] = [:]

        // Base period (non-optional in current SDK)
        let period = sub.subscriptionPeriod
        d["period_value"] = period.value
        d["period_unit"]  = unitString(period.unit)

        // Introductory offer (if any)
        if let intro = sub.introductoryOffer {
            d["introductory_offer"] = serialize(offer: intro)
        }

        // Promotional offers (if any)
        if #available(iOS 16.4, *) {
            // In modern SDKs this property exists. Guard with availability for safety.
            let promos = sub.promotionalOffers
            if !promos.isEmpty {
                d["promotional_offers"] = promos.map { serialize(offer: $0) }
            }
        }

        // Subscription group identifier (if needed downstream)
        if let groupID = sub.subscriptionGroupID {
            d["subscription_group_id"] = groupID
        }

        return d
    }

    private func serialize(offer: Product.SubscriptionOffer) -> [String: Any] {
        var d: [String: Any] = [:]

        // Period (non-optional)
        let period = offer.period
        d["period_value"] = period.value
        d["period_unit"]  = unitString(period.unit)

        // Offer metadata
        d["type"]         = offerTypeString(offer.type)             // "introductory" or "promotional"
        d["payment_mode"] = paymentModeString(offer.paymentMode)    // "free_trial" | "pay_as_you_go" | "pay_up_front"

        // Price
        // displayPrice is the localized string; for numeric breakdown, StoreKit exposes Price via Decimal & currencyCode on newer SDKs.
        d["display_price"] = offer.displayPrice

        // Optional: number of periods billed for pay-as-you-go
        if let numPeriods = offer.numberOfPeriods {
            d["number_of_periods"] = numPeriods
        }

        return d
    }

    // MARK: - Mappers (exhaustive switches, no @unknown default)

    private func unitString(_ unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day:   return "day"
        case .week:  return "week"
        case .month: return "month"
        case .year:  return "year"
        }
    }

    private func offerTypeString(_ t: Product.SubscriptionOffer.OfferType) -> String {
        switch t {
        case .introductory: return "introductory"
        case .promotional:  return "promotional"
        }
    }

    private func paymentModeString(_ mode: Product.SubscriptionOffer.PaymentMode) -> String {
        switch mode {
        case .freeTrial:  return "free_trial"
        case .payAsYouGo: return "pay_as_you_go"
        case .payUpFront: return "pay_up_front"
        }
    }

    private func productTypeString(_ type: Product.ProductType) -> String {
        switch type {
        case .autoRenewable:  return "auto_renewable"
        case .nonRenewable:   return "non_renewable"
        case .nonConsumable:  return "non_consumable"
        case .consumable:     return "consumable"
        }
    }
}

// MARK: - (Optional) Simple fetch helpers you can call before serialization

extension GodotStoreKit2Swift {
    /// Load products by identifiers and return their serialized representation.
    /// Call from Obj-C/Godot via bridging. Errors are flattened to a string for simplicity.
    @objc public func loadAndSerializeProducts(withIDs ids: [String], completion: @escaping (_ products: [[String: Any]]?, _ error: String?) -> Void) {
        Task.detached {
            do {
                let storeProducts = try await Product.products(for: ids)
                let serialized = self.serialize(products: storeProducts)
                completion(serialized, nil)
            } catch {
                completion(nil, String(describing: error))
            }
        }
    }
}

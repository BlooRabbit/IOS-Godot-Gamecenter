//
//  GodotStoreKit2Swift.swift
//  godot-storekit2
//
//  StoreKit 2 bridge helpers for serialization.
//  Tested with Xcode 16.2 (iOS SDK 18.2), Swift 5.9
//

import Foundation
import StoreKit

@objc public final class GodotStoreKit2Swift: NSObject {

    // MARK: - Obj-C exposed entry points

    /// Load products by identifiers and return an NSArray<NSDictionary> (Obj-C friendly).
    /// Any error is returned as an NSString in the second parameter.
    @objc public func loadAndSerializeProducts(withIDs ids: [String],
                                               completion: @escaping (NSArray?, NSString?) -> Void) {
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let storeProducts = try await Product.products(for: ids)
                let dicts = self.serialize(products: storeProducts) as NSArray
                completion(dicts, nil)
            } catch {
                completion(nil, NSString(string: String(describing: error)))
            }
        }
    }

    /// Same as above, but returns a JSON string (UTF-8) for easy transport over C/Obj-C bridges.
    @objc public func loadProductsJSON(withIDs ids: [String],
                                       completion: @escaping (NSString?, NSString?) -> Void) {
        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let storeProducts = try await Product.products(for: ids)
                let dicts = self.serialize(products: storeProducts)
                let data = try JSONSerialization.data(withJSONObject: dicts, options: [])
                let json = String(data: data, encoding: .utf8) ?? "[]"
                completion(NSString(string: json), nil)
            } catch {
                completion(nil, NSString(string: String(describing: error)))
            }
        }
    }

    // MARK: - Swift helpers (NOT @objc; they use Swift-only types)

    /// Serialize a StoreKit 2 Product to a basic dictionary you can pass across a bridge.
    public func serialize(product: Product) -> [String: Any] {
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
    public func serialize(products: [Product]) -> [[String: Any]] {
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

        // Promotional offers (if available on this SDK)
        if #available(iOS 16.4, *) {
            let promos = sub.promotionalOffers
            if !promos.isEmpty {
                d["promotional_offers"] = promos.map { serialize(offer: $0) }
            }
        }

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
        d["type"]         = offerTypeString(offer.type)          // "introductory" | "promotional"
        d["payment_mode"] = paymentModeString(offer.paymentMode) // "free_trial" | "pay_as_you_go" | "pay_up_front"

        // Localized price string
        d["display_price"] = offer.displayPrice

        // Optional: number of periods (pay-as-you-go)
        if let numPeriods = offer.numberOfPeriods {
            d["number_of_periods"] = numPeriods
        }

        return d
    }

    // MARK: - Mappers (exhaustive switches)

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

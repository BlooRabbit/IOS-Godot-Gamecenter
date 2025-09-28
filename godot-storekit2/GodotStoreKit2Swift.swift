//
//  GodotStoreKit2Swift.swift
//  godot-storekit2
//
//  Minimal StoreKit 2 bridge helpers for ObjC++ interop
//

import Foundation
import StoreKit

@objc public final class GodotStoreKit2Swift: NSObject {
    @objc public static let shared = GodotStoreKit2Swift()
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

        if let price = try? product.price {
            dict["priceDecimal"] = price
        }

        // Subscription-specific fields
        if let sub = product.subscription {
            // NOTE: Treated as non-optional per SDK; do NOT optional-bind it.
            let groupID = sub.subscriptionGroupID
            dict["subscriptionGroupID"] = groupID

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

        // Non-consumable / consumable / non-renewing may have no subscription info
        if let localization = product.discounts.first { // arbitrary example; discounts array exists for in-apps
            dict["hasDiscounts"] = true
            dict["firstDiscountIdentifier"] = localization.id
        } else {
            dict["hasDiscounts"] = false
        }

        return dict
    }

    // MARK: - Offer / Period mapping

    /// Convert a `Product.SubscriptionOffer` to a dictionary WITHOUT using numberOfPeriods.
    private func subscriptionOfferDictionary(from offer: Product.SubscriptionOffer) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["identifier"]  = offer.id
        dict["price"]       = offer.displayPrice

        // Period describes the cadence of the offer (value + unit)
        let p = offer.period
        dict["periodValue"] = p.value
        dict["periodUnit"]  = mapPeriodUnit(p.unit)

        // StoreKit 2: use paymentMode + type instead of numberOfPeriods
        dict["paymentMode"] = mapPaymentMode(offer.paymentMode)
        dict["offerType"]   = mapOfferType(offer.type)

        // Some offers expose a referenceName / localization via metadata (optional)
        if let name = offer.offering?.displayName, !name.isEmpty {
            dict["displayName"] = name
        }

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

    private func mapPeriodUni

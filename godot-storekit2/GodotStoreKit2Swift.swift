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
                compl

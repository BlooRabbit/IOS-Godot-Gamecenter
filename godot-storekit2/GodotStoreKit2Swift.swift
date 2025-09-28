//
//  GodotStoreKit2Swift.swift
//  Minimal SK2 “connection” + signal
//
//  Xcode 16.2 / Swift 5.9 / iOS 15.6+
//

import Foundation
import StoreKit

@objc public final class GodotStoreKit2Swift: NSObject {

    // Singleton (not @objc — ObjC doesn’t need to access it directly)
    public static let shared = GodotStoreKit2Swift()

    // Simple state you can poll from ObjC
    @objc public private(set) var isStarted: Bool = false
    @objc public private(set) var lastSignal: String = "idle"

    // Keep a strong reference to the task so it stays alive
    private var updatesTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    /// Start listening for StoreKit transaction updates.
    /// This is your “initiate connection” step.
    @objc public func start() {
        // If already started, do nothing
        guard updatesTask == nil else { return }

        isStarted = true
        lastSignal = "started"

        // Start a background listener for any StoreKit signals
        updatesTask = Task.detached { [weak self] in
            // Iterate over SK2 updates; we don’t surface the structs to ObjC.
            for await _ in Transaction.updates {
                // Whenever we get *any* update, record a simple string.
                await self?.setSignal("transaction_update")
            }
        }
    }

    /// Stop listening (optional helper).
    @objc public func stop() {
        updatesTask?.cancel()
        updatesTask = nil
        isStarted = false
        lastSignal = "stopped"
    }

    /// Returns the latest signal as a plain string you can poll from ObjC.
    @objc public func latestSignal() -> String {
        return lastSignal
    }

    // MARK: - Actor isolated setter to hop back to main safely.
    @MainActor
    private func setSignal(_ value: String) {
        self.lastSignal = value
    }
}

import Foundation
import GameKit
import UIKit

// Expose this Swift class to Obj-C as "GodotGameKitProxy"
@objc(GodotGameKitProxy)
@objcMembers
public final class GodotGameKit: NSObject, @unchecked Sendable {

    public static let shared = GodotGameKit()

    private override init() {
        super.init()
    }

    /// Initializes Game Center sign-in flow.
    /// Calls the completion with InitializationData once authentication resolves.
    @objc public func initializeGameCenter(completion: @escaping (InitializationData) -> Void) {
        let data = InitializationData()
        let localPlayer = GKLocalPlayer.local

        localPlayer.authenticateHandler = { viewController, error in

            if let error = error {
                data.initialized = false
                data.error = error.localizedDescription
                completion(data)
                return
            }

            if let vc = viewController {
                // Present Game Center sign-in UI
                guard let presenter = Self.topViewController() else {
                    data.initialized = false
                    data.error = "No root view controller to present Game Center UI"
                    completion(data)
                    return
                }

                presenter.present(vc, animated: true, completion: nil)
            } else {
                // Already authenticated or finished without UI
                data.initialized = localPlayer.isAuthenticated
                data.error = ""
                completion(data)
                print("[GameKit] Authenticated: \(localPlayer.isAuthenticated)")
            }
        }
    }

    /// Allow Godot to check if the player is currently authenticated.
    @objc public func isAuthenticated() -> Bool {
        return GKLocalPlayer.local.isAuthenticated
    }

    // MARK: - View Controller Helper

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController?

        if let base = base {
            root = base
        } else {
            let window = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })

            root = window?.rootViewController
        }

        guard let rootVC = root else { return nil }

        if let nav = rootVC as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        } else if let tab = rootVC as? UITabBarController,
                  let selected = tab.selectedViewController {
            return topViewController(base: selected)
        } else if let presented = rootVC.presentedViewController {
            return topViewController(base: presented)
        } else {
            return rootVC
        }
    }
}

@objcMembers
public class InitializationData: NSObject {
    public var initialized: Bool = false
    public var error: String = ""
}

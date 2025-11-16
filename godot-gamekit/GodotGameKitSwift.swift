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

    /// Initializes Game Center sign-in mechanism
    /// Calls completion with InitializationData once authentication is done
    
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
                // Open Game Center sign-in UI
                guard let presenter = Self.topViewController() else {
                    data.initialized = false
                    data.error = "No root view controller to show Game Center UI"
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

    /// Function to check if the player is currently authenticated.
    @objc public func isAuthenticated() -> Bool {
        return GKLocalPlayer.local.isAuthenticated
    }

    /// Report progress for an achievement (percentComplete is 0.0 - 100.0)
    @objc public func reportAchievement(identifier: String,
                                  percentComplete: Double,
                                  completion: @escaping (AchievementData) -> Void) {
        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true

        GKAchievement.report([achievement]) { error in
            let data = AchievementData()
            data.identifier = identifier
            data.percentComplete = achievement.percentComplete
            data.completed = achievement.isCompleted
            data.lastReportedDate = achievement.lastReportedDate

            if let error = error {
                data.error = error.localizedDescription
            }

            completion(data)
        }
    }

    /// Load all achievements for the local player
    @objc public func loadAchievements(completion: @escaping ([AchievementData]) -> Void) {
        GKAchievement.loadAchievements { achievements, error in
            var result: [AchievementData] = []

            if let list = achievements {
                for ach in list {
                    let data = AchievementData()
                    data.identifier = ach.identifier
                    data.percentComplete = ach.percentComplete
                    data.completed = ach.isCompleted
                    data.lastReportedDate = ach.lastReportedDate
                    result.append(data)
                }
            }
            completion(result)
        }
    }

    /// Load all available achievements 
    @objc public func loadAchievementNames(completion: @escaping ([AchievementNameData]) -> Void) {

    GKAchievementDescription.loadAchievementDescriptions { list, error in
        var result: [AchievementNameData] = []

        if let list = list {
            for desc in list {
                let data = AchievementNameData()
                data.identifier = desc.identifier
                data.title = desc.title
                result.append(data)
            }
        }

        if let error = error {
            let errData = AchievementNameData()
            errData.error = error.localizedDescription
            result.append(errData)
        }

        completion(result)
    }
}


    /// View Controller Helper
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

// ACHIEVEMENTS

@objcMembers
public class AchievementData: NSObject {
    public var identifier: String = ""
    public var percentComplete: Double = 0.0
    public var completed: Bool = false
    public var lastReportedDate: Date? = nil
    public var error: String = ""
}

@objcMembers
public class AchievementNameData: NSObject {
    public var identifier: String = ""
    public var title: String = ""
    public var error: String = ""
}


import Foundation
import GameKit
import UIKit

@objc(GameKitPlugin)
class GameKitPlugin: NSObject {

    @objc static let shared = GameKitPlugin()

    override private init() {}

    @objc func authenticate() {
        let localPlayer = GKLocalPlayer.local

        localPlayer.authenticateHandler = { viewController, error in
            let rootVC = UIApplication.shared.keyWindow?.rootViewController

            if let vc = viewController, let root = rootVC {
                root.present(vc, animated: true)
            } else if let error = error {
                print("GameKit: Authentication failed → \(error.localizedDescription)")
            } else {
                print("GameKit: Player authenticated ✓")
            }
        }
    }

    @objc func submitScore(_ score: Int, leaderboardId: String) {
        let report = GKScore(leaderboardIdentifier: leaderboardId)
        report.value = Int64(score)

        GKScore.report([report]) { error in
            if let error = error {
                print("GameKit: Score report failed → \(error.localizedDescription)")
            } else {
                print("GameKit: Score submitted ✓")
            }
        }
    }
}

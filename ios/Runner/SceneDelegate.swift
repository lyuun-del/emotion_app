import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func sceneDidEnterBackground(_ scene: UIScene) {
    super.sceneDidEnterBackground(scene)
    (UIApplication.shared.delegate as? AppDelegate)?.scheduleHealthRefresh()
  }
}

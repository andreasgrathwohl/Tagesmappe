#if os(iOS)
  import UIKit

  /// UIKit-App-Delegate für die Szene des Zweitbildschirms bis iOS 26.
  final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
      _ application: UIApplication,
      configurationForConnecting connectingSceneSession: UISceneSession,
      options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
      // Bis iOS 26 verbindet das System die Szene des Zweitbildschirms von selbst; wir nehmen sie an.
      // Ab iOS 27 kommt sie nur über das Szenen-Zubehör (Apple rät, die Rollenprüfung dort zu entfernen).
      if #unavailable(iOS 27), connectingSceneSession.role == .windowExternalDisplayNonInteractive {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = ExternalDisplaySceneDelegate.self
        return configuration
      }
      return connectingSceneSession.configuration  // SwiftUI-Hauptszene unverändert
    }
  }
#endif

#if os(iOS)
  import UIKit

  /// UIKit-App-Delegate für die Szene des Zweitbildschirms.
  final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
      _ application: UIApplication,
      configurationForConnecting connectingSceneSession: UISceneSession,
      options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
      // Die Rolle des Zweitbildschirms wird immer angenommen – auch ab iOS 27, ohne `#unavailable`-Sperre.
      // Bis iOS 26 verbindet das System die Szene von selbst. Ab iOS 27 kommt sie regulär über das
      // Szenen-Zubehör (`SceneAccessoryRegistrar`); dieser Weg steckt aber in `#if compiler(>=6.4)` und
      // fehlt in einem mit Xcode 26 gebauten Stand (CI, TestFlight). Fiele die Annahme hier weg, bekäme die
      // Szene dort die SwiftUI-Hauptkonfiguration, und die Tagesansicht erschiene auf dem Bildschirm im
      // Klassenraum – das verbietet FR-6.2. Lieber unsere Szene des Zweitbildschirms als die Hauptansicht.
      if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = ExternalDisplaySceneDelegate.self
        return configuration
      }
      return connectingSceneSession.configuration  // SwiftUI-Hauptszene unverändert
    }
  }
#endif

#if os(iOS)
  import SwiftUI
  import UIKit

  /// Meldet ab iOS 27 das Szenen-Zubehör für den Zweitbildschirm an (unsichtbar).
  /// Swift-Hinweis: `UIViewControllerRepresentable` bettet einen UIKit-Controller in SwiftUI ein.
  struct SceneAccessoryRegistrar: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> AccessoryHostViewController {
      AccessoryHostViewController()
    }
    func updateUIViewController(_ controller: AccessoryHostViewController, context: Context) {}
  }

  final class AccessoryHostViewController: UIViewController {
    /// `UISceneAccessoryRegistration` gibt es erst ab iOS 27, daher als `AnyObject?`.
    private var registration: AnyObject?

    override func viewDidAppear(_ animated: Bool) {
      super.viewDidAppear(animated)
      guard registration == nil else { return }
      // `#available` schützt nur zur Laufzeit; mit Xcode 26 fehlen die Typen, daher zusätzlich `#if compiler`.
      #if compiler(>=6.4)
        if #available(iOS 27, *) {
          // Die Hauptansicht als Ziel: das Zubehör gilt, solange die App im Vordergrund ist.
          let target = view.window?.rootViewController ?? self
          let configuration = UISceneConfiguration(
            name: nil, sessionRole: .windowExternalDisplayNonInteractive)
          configuration.delegateClass = ExternalDisplaySceneDelegate.self
          registration = target.registerSceneAccessory(
            .externalNonInteractive(sceneConfiguration: configuration))
        }
      #endif
    }
  }

  extension View {
    /// Meldet das Szenen-Zubehör des Zweitbildschirms an (ab iOS 27).
    func registersSecondScreenAccessory() -> some View {
      background(SceneAccessoryRegistrar().frame(width: 0, height: 0))
    }
  }
#endif

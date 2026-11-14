#if os(iOS)
  import SwiftUI
  import UIKit

  /// Szene des Zweitbildschirms. Swift-Hinweis: Eine „Szene“ ist in UIKit eine eigene Instanz der Oberfläche
  /// mit eigenem Fenster. SwiftUI hat für die nicht bedienbare Szene keinen eigenen Baustein; sie wird hier in
  /// UIKit angelegt und zeigt die SwiftUI-Ansicht über `UIHostingController`.
  /// Quelle: Apple, „Presenting content on a connected display“.
  final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    @MainActor func scene(
      _ scene: UIScene, willConnectTo session: UISceneSession,
      options connectionOptions: UIScene.ConnectionOptions
    ) {
      guard let windowScene = scene as? UIWindowScene,
        session.role == .windowExternalDisplayNonInteractive
      else { return }
      let window = UIWindow(windowScene: windowScene)
      window.rootViewController = UIHostingController(
        rootView: SecondScreenRootView(state: .shared).secondScreenEnvironment())
      window.makeKeyAndVisible()
      self.window = window
      guard let ratio = aspectRatio(of: windowScene) else { return }
      SecondScreenState.shared.displayConnected(aspectRatio: ratio)
    }

    @MainActor func sceneDidDisconnect(_ scene: UIScene) {
      window = nil
      SecondScreenState.shared.displayDisconnected()
    }

    @MainActor func windowScene(
      _ windowScene: UIWindowScene, didUpdate previousCoordinateSpace: any UICoordinateSpace,
      interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
      traitCollection previousTraitCollection: UITraitCollection
    ) {
      // Nur das Bildformat nachziehen: „Dunkel“ (FR-11.4) darf durch ein Update nicht aufgehoben werden.
      guard let ratio = aspectRatio(of: windowScene) else { return }
      SecondScreenState.shared.updateAspectRatio(ratio)
    }

    @MainActor private func aspectRatio(of windowScene: UIWindowScene) -> Double? {
      let bounds = windowScene.screen.bounds
      guard bounds.height > 0 else { return nil }
      return bounds.width / bounds.height
    }
  }
#endif

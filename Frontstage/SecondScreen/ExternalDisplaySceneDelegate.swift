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
      reportAspectRatio(of: windowScene)
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
      reportAspectRatio(of: windowScene)
    }

    @MainActor private func reportAspectRatio(of windowScene: UIWindowScene) {
      let bounds = windowScene.screen.bounds
      guard bounds.height > 0 else { return }
      SecondScreenState.shared.displayConnected(aspectRatio: bounds.width / bounds.height)
    }
  }
#endif

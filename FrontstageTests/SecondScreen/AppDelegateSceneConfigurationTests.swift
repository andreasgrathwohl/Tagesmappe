#if os(iOS)
  import Testing
  import UIKit

  @testable import Frontstage

  @MainActor struct AppDelegateSceneConfigurationTests {
    @Test("Hauptszene bekommt keinen eigenen Szenen-Delegate (sonst Rekursion in SwiftUI beim Start)")
    func mainSceneLeavesDelegateToSwiftUI() {
      let configuration = AppDelegate.sceneConfiguration(for: .windowApplication)
      #expect(configuration.delegateClass == nil)
      #expect(configuration.role == .windowApplication)
    }

    @Test("Zweitbildschirm bekommt die eigene Szene (FR-6.2)")
    func externalDisplayUsesOwnSceneDelegate() {
      let configuration = AppDelegate.sceneConfiguration(for: .windowExternalDisplayNonInteractive)
      #expect(configuration.delegateClass == ExternalDisplaySceneDelegate.self)
      #expect(configuration.role == .windowExternalDisplayNonInteractive)
    }
  }
#endif

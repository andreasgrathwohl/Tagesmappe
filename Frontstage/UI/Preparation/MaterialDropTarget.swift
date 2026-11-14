import FrontstageCore
import SwiftUI

/// Nimmt Dateien per Ziehen an und ordnet sie einer Unterrichtsstunde zu (FR-7, AK-4). Am Mac zieht die
/// Lehrkraft aus dem Finder, am iPad aus der Dateien-App in Split View.
///
/// Swift-Hinweis: `dropDestination(for:isEnabled:action:)` (ab iOS/macOS 26) ersetzt die ältere Form mit
/// `isTargeted`; die Aktion bekommt die gezogenen Werte und eine `DropSession`. Sie läuft synchron –
/// das asynchrone Zuordnen startet deshalb in einem eigenen `Task`.
@MainActor struct MaterialDropTarget: ViewModifier {
  let key: LessonKey
  let actions: LessonActions
  let onError: (AssignError) -> Void

  init(key: LessonKey, actions: LessonActions, onError: @escaping (AssignError) -> Void) {
    self.key = key
    self.actions = actions
    self.onError = onError
  }

  func body(content: Content) -> some View {
    content.dropDestination(for: URL.self, isEnabled: true) { urls, _ in
      Task {
        do throws(AssignError) {
          try await actions.assign(fileURLs: urls, to: key)
        } catch {
          onError(error)
        }
      }
    }
  }
}

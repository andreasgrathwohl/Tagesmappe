import SwiftUI

extension View {
  /// Hängt die Modelle des Klassenbildschirms an die Umgebung.
  func classroomEnvironment() -> some View {
    modifier(ClassroomEnvironmentModifier())
  }
}

/// Liest `ClassroomServices.shared` **im `body`**.
///
/// Swift-Hinweis: Nur ein Lesen innerhalb eines `body` verfolgt Observation. Ein außerhalb gelesener Wert
/// bliebe beim Erzeugen der Szene eingefroren und wäre nach `bind(store:)` noch `nil` bzw. der alte
/// Datenort. `board` und `store` sind optional: `.environment(_:)` nimmt dafür die Form für `Optional`;
/// gelesen wird mit `@Environment(BoardSession.self) var board: BoardSession?`.
private struct ClassroomEnvironmentModifier: ViewModifier {
  func body(content: Content) -> some View {
    let services = ClassroomServices.shared
    content
      .environment(services.unlock)
      .environment(services.session)
      .environment(services.board)
      .environment(services.store)
  }
}

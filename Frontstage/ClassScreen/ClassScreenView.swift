import SwiftUI

/// Klassenbildschirm des Zweitbildschirms (FR-11). Der Platzhalter zeigt nur die Fläche – das entspricht
/// zugleich dem Ruhezustand ohne Kauf (FR-13).
struct ClassScreenView: View {
  // Einhängepunkt – Teilplan 07 ersetzt den Inhalt; Name und init bleiben.
  var body: some View {
    SystemBackground()
  }
}

/// Neutrale Fläche in der Hintergrundfarbe des Systems (iOS und macOS).
struct SystemBackground: View {
  var body: some View {
    #if os(iOS)
      Color(uiColor: .systemBackground)
    #else
      Color(nsColor: .windowBackgroundColor)
    #endif
  }
}

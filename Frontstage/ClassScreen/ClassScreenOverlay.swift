import SwiftUI

/// Schicht über allen Inhalten des Zweitbildschirms außer „Dunkel“: die Timer-Anzeige (FR-11.2).
/// Ohne Kauf bleibt sie leer (FR-13).
struct ClassScreenOverlay: View {
  @Environment(Unlock.self) private var unlock

  var body: some View {
    if unlock.isUnlocked {
      PhaseTimerOverlay()
    }
  }
}

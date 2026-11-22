import Foundation
import Observation

/// Ob die Lösungsspalte gezeigt wird (FR-6.3, UI-17). Flüchtig und app-weit: Wer sie ausblendet, hat sie beim
/// nächsten Blatt ebenfalls aus.
@MainActor @Observable final class SolutionVisibility {
  static let shared = SolutionVisibility()

  /// Die Lehrkraft hat die Spalte eingeblendet (Knopf „Lösung“).
  var isShownByUser = true
  /// „Trotzdem zeigen“ bei Spiegelung; gilt nur für die offene Anzeige.
  var overrideMirroring = false

  init() {}

  /// Sichtbar, wenn eingeblendet und das Tablet-Bild nicht gespiegelt wird (oder die Lehrkraft es trotzdem will).
  /// `isMirrored == nil`: Zustand noch unbekannt (Anzeige gerade geöffnet) – im Zweifel nicht zeigen.
  func isVisible(isMirrored: Bool?) -> Bool {
    guard isShownByUser, let isMirrored else { return false }
    return !isMirrored || overrideMirroring
  }

  /// Beim Schließen der Anzeige: „Trotzdem zeigen“ gilt nicht für das nächste Blatt.
  func viewerClosed() {
    overrideMirroring = false
  }
}

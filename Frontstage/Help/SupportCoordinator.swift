import FrontstageCore
import Observation

/// Zustand von Hilfecenter und Rückmeldung, der außerhalb einer einzelnen Ansicht gebraucht wird: Das Menü
/// „Hilfe“ (macOS) und die Wurzelansicht greifen darauf zu.
///
/// Swift-Hinweis: `@Observable` ersetzt `ObservableObject`; SwiftUI beobachtet die gelesenen Eigenschaften
/// automatisch. `static let shared` ist nötig, weil `Commands` außerhalb des Ansichtenbaums entstehen.
@MainActor @Observable
final class SupportCoordinator {
  static let shared = SupportCoordinator()

  /// Vorgabe `.standard`; `RootView` setzt den echten Kontext (Datenort, Erscheinungsbild, Kaufstand).
  var context: FeedbackContext
  var showsHelpCenter = false
  var feedbackSession: FeedbackSession?

  /// Rückmeldung, die erst nach dem Schließen des Hilfecenters beginnt (zwei Blätter am selben Ziel
  /// verträgt SwiftUI nicht; die Aufnahme soll zudem nicht das Hilfeblatt zeigen).
  private var pendingKind: FeedbackKind?

  init() {
    context = .standard
  }

  /// Zeigt das Hilfecenter – nicht über einer offenen Rückmeldung (der Entwurf bliebe sonst verdeckt).
  func showHelpCenter() {
    guard feedbackSession == nil else { return }
    showsHelpCenter = true
  }

  /// Startet eine Rückmeldung ohne Thema. Die Aufnahme des Fensters entsteht vor dem Blatt
  /// (`FeedbackStarter`). Ist schon eine offen, bleibt sie.
  func startFeedback(kind: FeedbackKind = .issue) {
    guard feedbackSession == nil else { return }
    feedbackSession = FeedbackStarter.start(kind: kind, topic: nil, context: context)
  }

  /// Wunsch aus dem Hilfecenter: Blatt schließen, die Rückmeldung beginnt in `helpCenterDidDismiss()`.
  func requestFeedbackFromHelpCenter(kind: FeedbackKind) {
    pendingKind = kind
    showsHelpCenter = false
  }

  /// `onDismiss` des Hilfecenter-Blatts.
  func helpCenterDidDismiss() {
    guard let kind = pendingKind else { return }
    pendingKind = nil
    startFeedback(kind: kind)
  }
}

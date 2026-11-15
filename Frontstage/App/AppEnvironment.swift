import FrontstageCore
import Foundation
import Observation

/// Abhängigkeitsbündel der Oberfläche. Entsteht je Datenort in `ScopedAppContent`, weil es einen
/// `DataStore` hält; die View-Modelle bekommen es im `init`.
///
/// Swift-Hinweis: `@Observable` beobachtet die veränderlichen Eigenschaften (`viewerAvailable`,
/// `penNotes`); die `let`-Eigenschaften ändern sich nie und brauchen keine Beobachtung.
@MainActor @Observable final class AppEnvironment {
  let store: any PreparationStore
  let storage: any MaterialStorage
  /// Setzt Teilplan 06; `false` (Vorgabe): PDF und Bild werden wie jedes Material übergeben.
  var viewerAvailable: Bool = false
  /// Setzt Teilplan 06; Vorgabe `NoPenNoteFileRelocation()`.
  var penNotes: any PenNoteFileRelocating = NoPenNoteFileRelocation()
  let today: @MainActor () -> CalendarDay
  /// Aktueller Datenort (Teilplan 08) – für den Hinweis beim Abmelden von Microsoft.
  let dataLocation: @MainActor () -> DataLocation
  /// Aktueller Zeitpunkt – für „Jetzt“ und die automatische Auswahl der Tagesansicht (UI-3, UI-12);
  /// in Tests festgesetzt.
  let now: @MainActor () -> Date

  init(
    store: any PreparationStore, storage: any MaterialStorage,
    today: @escaping @MainActor () -> CalendarDay,
    dataLocation: @escaping @MainActor () -> DataLocation = { .iCloud },
    now: @escaping @MainActor () -> Date = { Date() }
  ) {
    self.store = store
    self.storage = storage
    self.today = today
    self.dataLocation = dataLocation
    self.now = now
  }
}

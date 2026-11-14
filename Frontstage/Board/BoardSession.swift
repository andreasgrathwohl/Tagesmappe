import Observation

/// Sitzung der geöffneten Tafel (FR-12).
///
/// PLATZHALTER aus Aufgabe 4, damit `ClassroomServices` übersetzt; Aufgabe 9 ersetzt die Datei.
@MainActor @Observable final class BoardSession {
  @ObservationIgnored private let store: BoardStore
  @ObservationIgnored private let secondScreen: SecondScreenState

  init(store: BoardStore, secondScreen: SecondScreenState) {
    self.store = store
    self.secondScreen = secondScreen
  }
}

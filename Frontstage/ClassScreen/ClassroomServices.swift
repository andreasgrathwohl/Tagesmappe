import Observation

/// Ein Bündel für beide Szenen; `classroomEnvironment()` hängt es an.
///
/// Der Halter ist `shared`, weil die Szene des Zweitbildschirms außerhalb des SwiftUI-Baums entsteht (06).
/// Was einen `DataStore` hält, entsteht erst in `bind(store:)` – aufgerufen aus `RootView`
/// (`.onChange(of: dataLocation.generation, initial: true)`), nach jedem Wechsel des Datenorts erneut.
/// `Unlock` und `LessonSessionState` hängen nicht am Datenort und bleiben.
@MainActor @Observable final class ClassroomServices {
  static let shared = ClassroomServices(
    unlock: Unlock(listenForUpdates: true), session: LessonSessionState(signal: TimerSignalPlayer()))

  let unlock: Unlock
  let session: LessonSessionState
  /// Der Store, an den die Tafel gerade gebunden ist; `nil` nur kurz beim Start.
  private(set) var store: DataStore?
  private(set) var board: BoardSession?

  /// Intern, für Tests.
  init(unlock: Unlock, session: LessonSessionState = LessonSessionState(signal: nil)) {
    self.unlock = unlock
    self.session = session
  }

  /// Bindet die Tafel an den aktuellen `DataStore`. Gleicher Store: nichts. Anderer Store (Wechsel des
  /// Datenorts): neue `BoardSession`, und eine offene Tafel des alten Datenorts wird geschlossen.
  func bind(store newStore: DataStore) {
    guard store !== newStore else { return }
    SecondScreenState.shared.setBoardLesson(nil)
    board = BoardSession(store: BoardStore(store: newStore), secondScreen: .shared)
    store = newStore
  }
}

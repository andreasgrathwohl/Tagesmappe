import FrontstageCore
import Observation

/// Flüchtiger Zustand der laufenden Unterrichtsstunde: Timer und Arbeitsform (FR-11.2, FR-11.3).
///
/// PLATZHALTER aus Aufgabe 4, damit `ClassroomServices` übersetzt; Aufgabe 5 ersetzt die Datei um
/// `lessonKey`, `lessonDidChange(to:)` und die Timer-Steuerung.
@MainActor @Observable final class LessonSessionState {
  var timer = PhaseTimer()
  var workMode: WorkMode?
  @ObservationIgnored let signal: TimerSignalPlayer?

  init(signal: TimerSignalPlayer?) {
    self.signal = signal
  }
}

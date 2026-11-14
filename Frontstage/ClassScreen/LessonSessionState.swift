import FrontstageCore
import Foundation
import Observation

/// Flüchtiger Zustand der laufenden Unterrichtsstunde: Timer und Arbeitsform (FR-11.2, FR-11.3).
///
/// Nichts davon wird gespeichert oder gespiegelt. Der Timer rechnet aus einem Endzeitpunkt und überdauert
/// den Stundenwechsel (er gehört dem Unterricht, nicht der Stunde); die Arbeitsform gilt nur für die
/// Unterrichtsstunde, für die sie gewählt wurde.
@MainActor @Observable final class LessonSessionState {
  var timer = PhaseTimer()
  /// Zuletzt verwendete Dauer des Timers in Minuten (Vorgabe 5); flüchtig, gilt für alle Smartboard-Leisten.
  var timerMinutes = 5
  var workMode: WorkMode?
  /// Die Unterrichtsstunde, für die `workMode` gilt; `nil`, solange keine läuft.
  private(set) var lessonKey: LessonKey?

  @ObservationIgnored private let signal: TimerSignalPlayer?
  /// Wartet bis zum Endzeitpunkt und spielt dann das Signal. Erbt den MainActor.
  @ObservationIgnored private var signalTask: Task<Void, Never>?

  init(signal: TimerSignalPlayer?) {
    self.signal = signal
  }

  /// Meldet die aktuelle Unterrichtsstunde. Wechselt sie, wird die Arbeitsform zurückgesetzt;
  /// der Timer bleibt unberührt. Dieselbe Stunde erneut zu melden ändert nichts.
  func lessonDidChange(to key: LessonKey?) {
    guard key != lessonKey else { return }
    lessonKey = key
    workMode = nil
  }

  /// Wählt die Arbeitsform für die laufende Stunde `key`. Meldet die Stunde vorher, damit eine Wahl nicht an einer
  /// veralteten Stunde hängt und beim nächsten Melden verworfen wird.
  func selectWorkMode(_ mode: WorkMode?, for key: LessonKey?) {
    lessonDidChange(to: key)
    workMode = mode
  }

  func startTimer(minutes: Int, now: Date) {
    timer.start(duration: TimeInterval(max(0, minutes)) * 60, now: now)
    scheduleSignal()
  }

  func pauseTimer(now: Date) {
    timer.pause(now: now)
    cancelSignal()
  }

  func resumeTimer(now: Date) {
    timer.resume(now: now)
    scheduleSignal()
  }

  func stopTimer() {
    timer.stop()
    cancelSignal()
  }

  private func cancelSignal() {
    signalTask?.cancel()
    signalTask = nil
  }

  /// Plant das Signal zum Endzeitpunkt neu. `Task.sleep(for:)` mit der Restdauer, weil `ContinuousClock`
  /// nicht an `Date` gebunden ist. Kehrt die App erst nach dem Ablauf zurück, lehnt `shouldPlaySignal`
  /// das verspätete Signal ab (Review Focus 1).
  private func scheduleSignal() {
    cancelSignal()
    guard case .running(let endDate) = timer.state else { return }
    signalTask = Task { [weak self] in
      let delay = max(0, endDate.timeIntervalSinceNow)
      do { try await Task.sleep(for: .seconds(delay)) } catch { return }
      guard let self, !Task.isCancelled else { return }
      if self.timer.shouldPlaySignal(at: .now) { self.signal?.play() }
    }
  }
}

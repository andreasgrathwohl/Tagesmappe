import FrontstageCore
import Foundation
import Observation
import OSLog

/// Thema, Bereitlegen und Hausaufgabe einer Stunde eintragen – kostenlos (FR-13, Nutzerentscheidung
/// 2026-11-13). Teilplan 07 nutzt diesen Editor mit.
@MainActor @Observable final class LessonInfoEditor {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "LessonInfoEditor")

  let key: LessonKey
  private let store: any PreparationStore

  var topic: String
  var toPrepare: String
  var homework: String

  /// Startet mit den gespeicherten Angaben der Stunde (fehlende Felder als leerer Text).
  init(key: LessonKey, store: any PreparationStore) {
    self.key = key
    self.store = store
    let info = (try? store.lessonInfo(for: key)) ?? LessonInfo()
    self.topic = info.topic ?? ""
    self.toPrepare = info.toPrepare ?? ""
    self.homework = info.homework ?? ""
  }

  /// Speichert über `store.setLessonInfo`; `LessonInfo` trimmt und macht leere Felder zu `nil` (FR-11.1).
  func save() {
    do {
      try store.setLessonInfo(
        LessonInfo(topic: topic, toPrepare: toPrepare, homework: homework), for: key)
    } catch {
      Self.logger.error("Stundenangaben speichern gescheitert: \(String(describing: error), privacy: .public)")
    }
  }
}

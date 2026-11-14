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

  /// Zuletzt geladener oder gespeicherter Stand; nur Abweichungen davon werden geschrieben.
  private var baseline: Baseline

  private struct Baseline: Equatable {
    var topic: String
    var toPrepare: String
    var homework: String
  }

  /// Startet mit den gespeicherten Angaben der Stunde (fehlende Felder als leerer Text).
  init(key: LessonKey, store: any PreparationStore) {
    self.key = key
    self.store = store
    let loaded = Self.load(key: key, store: store)
    self.topic = loaded.topic
    self.toPrepare = loaded.toPrepare
    self.homework = loaded.homework
    self.baseline = loaded
  }

  private static func load(key: LessonKey, store: any PreparationStore) -> Baseline {
    let info = (try? store.lessonInfo(for: key)) ?? LessonInfo()
    return Baseline(
      topic: info.topic ?? "", toPrepare: info.toPrepare ?? "", homework: info.homework ?? "")
  }

  private var current: Baseline { Baseline(topic: topic, toPrepare: toPrepare, homework: homework) }

  /// `true`, wenn die Felder von dem abweichen, was geladen oder zuletzt gespeichert wurde.
  var isDirty: Bool { current != baseline }

  /// Übernimmt Änderungen von einem anderen Gerät, solange hier nichts bearbeitet wurde. Ohne diese
  /// Prüfung würde ein veralteter Stand beim Verlassen einen neueren Eintrag überschreiben.
  func reloadIfUnedited() {
    guard !isDirty else { return }
    let loaded = Self.load(key: key, store: store)
    guard loaded != baseline else { return }
    topic = loaded.topic
    toPrepare = loaded.toPrepare
    homework = loaded.homework
    baseline = loaded
  }

  /// Speichert über `store.setLessonInfo`, aber nur bei echter Änderung (kein leerer Datensatz für
  /// bloß angesehene Stunden, kein Überschreiben fremder Änderungen). `LessonInfo` trimmt und macht
  /// leere Felder zu `nil` (FR-11.1).
  func save() {
    guard isDirty else { return }
    let snapshot = current
    do {
      try store.setLessonInfo(
        LessonInfo(topic: snapshot.topic, toPrepare: snapshot.toPrepare, homework: snapshot.homework),
        for: key)
      baseline = snapshot
    } catch {
      Self.logger.error("Stundenangaben speichern gescheitert: \(String(describing: error), privacy: .public)")
    }
  }
}

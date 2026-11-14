import Foundation
import FrontstageCore
import OSLog
import Observation

/// Fehler beim Anlegen eines unterrichtsfreien Zeitraums.
enum NonTeachingPeriodError: Error, Equatable {
  /// „Von“ liegt nach „Bis“.
  case fromAfterTo
  /// Speichern im `DataStore` gescheitert.
  case saveFailed
}

/// Logik von „Einrichten › Unterrichtsfrei“ (FR-7): Ferien und Studientage pflegen und das Material
/// sehen, das in einem Zeitraum ohne Stunde dasteht. Material bleibt immer erhalten; es wird nur
/// zugeordnet (`actions.move`), nie gelöscht.
///
/// Swift-Hinweis: `throws(NonTeachingPeriodError)` ist ein typisierter Fehler (Swift 6); `catch`
/// kennt den Typ ohne Umwandlung.
@MainActor @Observable final class NonTeachingPeriodsViewModel {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage",
    category: "NonTeachingPeriods")

  private let environment: AppEnvironment

  /// Nach `from` (dann `to`) sortiert.
  private(set) var periods: [NonTeachingPeriod] = []
  /// Letzter Fehler einer Aktion ohne eigenen `throws`-Weg (Entfernen).
  var lastFailure: NonTeachingPeriodError?
  let actions: LessonActions

  init(environment: AppEnvironment) {
    self.environment = environment
    self.actions = LessonActions(
      store: environment.store, storage: environment.storage, penNotes: environment.penNotes)
    reload()
  }

  /// Liest den Stand aus dem `DataStore` neu (auch nach Änderungen vom anderen Gerät).
  func reload() {
    let loaded = (try? environment.store.nonTeachingPeriods()) ?? []
    periods = loaded.sorted { ($0.from, $0.to, $0.title) < ($1.from, $1.to, $1.title) }
  }

  /// Legt einen Zeitraum an; ein leerer Titel wird zum Standardtitel. `from == to` (ein Tag) ist erlaubt.
  func add(from: CalendarDay, to: CalendarDay, title: String) throws(NonTeachingPeriodError) {
    guard from <= to else { throw .fromAfterTo }
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let resolved = trimmed.isEmpty ? String(localized: "setup.nonTeaching.defaultTitle") : trimmed
    do {
      try environment.store.addNonTeachingPeriod(
        NonTeachingPeriod(from: from, to: to, title: resolved))
    } catch {
      Self.logger.error("Zeitraum anlegen gescheitert: \(String(describing: error), privacy: .public)")
      throw .saveFailed
    }
    reload()
  }

  /// Entfernt nur den Zeitraum; Zuordnungen bleiben (sie erscheinen danach wieder an ihrer Stunde
  /// oder als „Material ohne Stunde“).
  func remove(_ period: NonTeachingPeriod) {
    do {
      try environment.store.removeNonTeachingPeriod(period)
    } catch {
      Self.logger.error("Zeitraum entfernen gescheitert: \(String(describing: error), privacy: .public)")
      lastFailure = .saveFailed
    }
    reload()
  }

  /// Zuordnungen aller Tage von `from` bis `to`, zu denen es keine Stunde gibt.
  func materialsWithoutLesson(in period: NonTeachingPeriod) -> [MaterialLinkItem] {
    var result: [MaterialLinkItem] = []
    var day = period.from
    while day <= period.to {
      do {
        result += try environment.store.orphanedLinkItems(on: day)
      } catch {
        Self.logger.error("Material ohne Stunde gescheitert: \(String(describing: error), privacy: .public)")
      }
      day = day.adding(days: 1)
    }
    return result
  }

  /// Unterrichtsstunden der 14 Tage nach dem Zeitraum (ohne Ausfälle) – Auswahl für „Zuordnen …“.
  func assignableLessons(after period: NonTeachingPeriod, days: Int = 14) -> [Lesson] {
    var result: [Lesson] = []
    for offset in 1...days {
      let lessons = (try? environment.store.lessons(on: period.to.adding(days: offset))) ?? []
      result += lessons.filter { !$0.isCancelled }
    }
    return result
  }
}

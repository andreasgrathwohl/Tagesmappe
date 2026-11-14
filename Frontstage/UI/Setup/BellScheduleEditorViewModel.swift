import FrontstageCore
import Observation

/// Fehler beim Ändern des Zeitrasters.
enum BellScheduleError: Error, Equatable {
  case endNotAfterStart
  /// Die Stunde überschneidet sich mit der genannten anderen Stunde.
  case overlaps(period: Int)
  /// Das Speichern im `DataStore` ist gescheitert (kommt nicht aus dem Plan; Speichern kann immer scheitern).
  case saveFailed
}

/// Logik von „Einrichten › Zeitraster“ (FR-1.2): Beginn und Ende je Stunde.
///
/// Swift-Hinweis: `throws(BellScheduleError)` ist eine typisierte Fehlerdeklaration (Swift 6); im `catch`
/// ist der Fehler ohne Typumwandlung ein `BellScheduleError`.
@MainActor @Observable final class BellScheduleEditorViewModel {
  private let environment: AppEnvironment

  private(set) var schedule: BellSchedule
  /// Letzter Fehler einer Aktion ohne eigenen `throws`-Weg (Stunde hinzufügen/entfernen).
  var lastFailure: BellScheduleError?

  /// Dauer und Pause einer neu hinzugefügten Stunde in Minuten.
  private static let defaultDuration = 45
  private static let defaultGap = 5

  init(environment: AppEnvironment) {
    self.environment = environment
    self.schedule = (try? environment.store.timetable())?.bellSchedule ?? BellSchedule()
  }

  /// Liest den Stand aus dem `DataStore` neu (auch nach Änderungen vom anderen Gerät).
  func reload() {
    schedule = (try? environment.store.timetable())?.bellSchedule ?? BellSchedule()
  }

  /// Stundennummern aufsteigend.
  var periods: [Int] { schedule.periods.keys.sorted() }

  /// Ob eine weitere Stunde noch vor Mitternacht endet.
  var canAddPeriod: Bool { nextPeriod() != nil }

  /// Setzt Beginn und Ende der Stunde (legt sie an, falls sie fehlt). Stunden dürfen aneinanderstoßen
  /// (Ende = Beginn der nächsten), sich aber nicht überschneiden.
  func set(period: Int, start: TimeOfDay, end: TimeOfDay) throws(BellScheduleError) {
    guard end > start else { throw .endNotAfterStart }
    for other in schedule.periods.keys.sorted() where other != period {
      guard let range = schedule.periods[other] else { continue }
      if start < range.upperBound && range.lowerBound < end { throw .overlaps(period: other) }
    }
    var updated = schedule
    updated.periods[period] = start...end
    try persist(updated)
  }

  /// Nächste Nummer; Beginn = Ende der vorigen + 5 Minuten, Dauer 45 Minuten; ohne Stunden 1: 8:00–8:45.
  /// Ohne Platz vor Mitternacht passiert nichts (`canAddPeriod` ist dann `false`).
  func addPeriod() {
    guard let next = nextPeriod() else { return }
    var updated = schedule
    updated.periods[next.number] = next.range
    do throws(BellScheduleError) { try persist(updated) } catch { lastFailure = error }
  }

  func removeLastPeriod() {
    guard let last = schedule.periods.keys.max() else { return }
    var updated = schedule
    updated.periods[last] = nil
    do throws(BellScheduleError) { try persist(updated) } catch { lastFailure = error }
  }

  // MARK: - Intern

  private func nextPeriod() -> (number: Int, range: ClosedRange<TimeOfDay>)? {
    let startMinutes: Int
    let number: Int
    if let last = schedule.periods.keys.max(), let range = schedule.periods[last] {
      number = last + 1
      startMinutes = range.upperBound.minutesSinceMidnight + Self.defaultGap
    } else {
      number = 1
      startMinutes = 8 * 60
    }
    let endMinutes = startMinutes + Self.defaultDuration
    guard endMinutes <= 23 * 60 + 59 else { return nil }
    let start = TimeOfDay(hour: startMinutes / 60, minute: startMinutes % 60)
    let end = TimeOfDay(hour: endMinutes / 60, minute: endMinutes % 60)
    return (number, start...end)
  }

  private func persist(_ updated: BellSchedule) throws(BellScheduleError) {
    do {
      try environment.store.setBellSchedule(updated)
    } catch {
      throw .saveFailed
    }
    schedule = updated
  }
}

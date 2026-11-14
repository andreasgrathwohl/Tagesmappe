import Foundation
import FrontstageCore

/// Schmale Sicht auf die App-Daten für die Stundenplan-Quellen – ohne SwiftData-Typen nach außen.
/// Die Signaturen entsprechen den `DataStore`-Methoden aus Teilplan 02; Tests können einen Zähler dazwischenhängen.
@MainActor protocol TimetableRepository: AnyObject {
  func timetable() throws -> Timetable?
  /// Einträge mit Herkunft `.manual` oder von Hand geändert (Eingabe für `ImportDiffer`, AK-3).
  func manuallyEditedEntries() throws -> Set<TimetableEntry>
  func nonTeachingPeriods() throws -> [NonTeachingPeriod]
  func scheduleChanges() throws -> [ScheduleChange]
  func timetableSourceRaw() throws -> String
  func setTimetableSourceRaw(_ raw: String) throws
  /// „Stand“ (Glossar): gespiegelt, also auch auf dem zweiten Gerät sichtbar.
  func sourceFetchedAt() throws -> Date?
  /// Schreibt Einträge, Wochenvarianten und Zeitraster in einem Speichervorgang.
  func replaceTimetable(
    entries: [TimetableEntry], manuallyEdited: Set<TimetableEntry>, weekVariantCount: Int,
    referenceWeekA: CalendarDay?, bellSchedule: BellSchedule?
  ) throws
  /// Ersetzt alle Abweichungen und setzt, wenn nicht `nil`, den Stand – ein Speichervorgang.
  func replaceScheduleChanges(_ changes: [ScheduleChange], sourceFetchedAt: Date?) throws
}

/// `DataStore` erfüllt das Protokoll mit seinen vorhandenen Methoden (gleiche Signaturen).
extension DataStore: TimetableRepository {}

extension TimetableRepository {
  /// Unbekannter Rohwert → `.manual`.
  func timetableSourceKind() throws -> TimetableSourceKind {
    TimetableSourceKind(rawValue: try timetableSourceRaw()) ?? .manual
  }

  func setTimetableSourceKind(_ kind: TimetableSourceKind) throws {
    try setTimetableSourceRaw(kind.rawValue)
  }
}

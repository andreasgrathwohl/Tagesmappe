import Foundation

/// Art der Stundenplan-Quelle (Glossar: Stundenplan-Quelle). Liegt im Kern, damit der Rohwert gespeichert
/// (`TimetableRecord.sourceKindRaw`) und angezeigt werden kann. WebUntis kommt später als weiterer Fall (FR-2.1).
public enum TimetableSourceKind: String, Codable, Sendable, CaseIterable {
  case manual
  case schulmanager
}

/// Fehler beim Abfragen einer Stundenplan-Quelle.
public enum TimetableSourceError: Error, Hashable, Codable, Sendable {
  case notConfigured
  case invalidCredentials
  case multipleSchoolsUnsupported
  case offline
  case server(status: Int)
  /// Text nur zur Diagnose, nie mit Zugangsdaten.
  case unexpectedResponse(String)
}

/// Abweichung, wie die Quelle sie meldet – noch ohne Schlüssel der Unterrichtsstunde (ADR-0005).
public enum SourceChange: Hashable, Codable, Sendable {
  case cancelled(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject)
  case substitute(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject)
}

/// Aus datierten Stunden abgeleiteter Wochenplan.
public struct DerivedTimetable: Hashable, Codable, Sendable {
  public var entries: [TimetableEntry]
  public var weekVariantCount: Int
  public var referenceWeekA: CalendarDay?

  public init(entries: [TimetableEntry], weekVariantCount: Int, referenceWeekA: CalendarDay?) {
    self.entries = entries
    self.weekVariantCount = weekVariantCount
    self.referenceWeekA = referenceWeekA
  }
}

/// Ergebnis der Wochenplan-Ableitung.
public enum TimetableDerivationOutcome: Hashable, Codable, Sendable {
  case derived(DerivedTimetable)
  /// Zum Beispiel Sommerferien: Der Stundenplan bleibt, wie er ist.
  case noLessonsInRange
  /// Nur eine Unterrichtswoche, der vorhandene Plan hat aber A/B.
  case weekVariantsUndetermined
}

/// Stand einer Abfrage bei einer Quelle.
public struct SourceSnapshot: Hashable, Codable, Sendable {
  public var kind: TimetableSourceKind
  public var fetchedAt: Date
  public var range: ClosedRange<CalendarDay>
  public var timetable: TimetableDerivationOutcome
  public var bellSchedule: BellSchedule?
  public var changes: [SourceChange]

  public init(
    kind: TimetableSourceKind, fetchedAt: Date, range: ClosedRange<CalendarDay>,
    timetable: TimetableDerivationOutcome, bellSchedule: BellSchedule?, changes: [SourceChange]
  ) {
    self.kind = kind
    self.fetchedAt = fetchedAt
    self.range = range
    self.timetable = timetable
    self.bellSchedule = bellSchedule
    self.changes = changes
  }
}

/// Gemeinsame Schnittstelle aller Stundenplan-Quellen (Area stundenplan-quellen, ADR-0004).
public protocol TimetableSource: Sendable {
  var kind: TimetableSourceKind { get }
  /// `nil`: Diese Quelle liefert nichts, der Stundenplan wird in der App gepflegt („von Hand“).
  /// `existing` braucht die Quelle, um A/B-Wochen gleich zu benennen wie der vorhandene Stundenplan.
  func fetch(range: ClosedRange<CalendarDay>, existing: Timetable?, now: Date) async throws
    -> SourceSnapshot?
}

/// Quelle „von Hand“: liefert nichts.
public struct ManualTimetableSource: TimetableSource {
  public init() {}
  public var kind: TimetableSourceKind { .manual }
  public func fetch(range: ClosedRange<CalendarDay>, existing: Timetable?, now: Date) async throws
    -> SourceSnapshot?
  { nil }
}

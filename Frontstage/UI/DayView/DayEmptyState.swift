import FrontstageCore
import Foundation

/// Leere Zustände der Tagesansicht (UI-13).
enum DayEmptyState: Equatable {
  case noLessons
  /// Der Stundenplan hat noch keinen Eintrag (geführter Erststart, FR-1.3): Hinweis mit Weg nach Einrichten.
  case noTimetable
  case nonTeachingDay(title: String)
  case sourceFailed(TimetableSourceError)
  /// Detailbereich ohne gewählte Stunde.
  case selectLesson

  /// `.rows` → `nil`. `.noLessons` mit Quelle ≠ manual, ohne je einen Stand (`fetchedAt == nil`) und mit
  /// Fehler → `sourceFailed`; sonst ohne einen einzigen Eintrag im Stundenplan `noTimetable`, sonst `noLessons`.
  /// Ferien gehen vor: Ein Ferientag bleibt ein Ferientag, auch ohne Stundenplan.
  static func make(
    content: DayContent, sourceKind: TimetableSourceKind, fetchedAt: Date?,
    lastError: TimetableSourceError?, hasTimetableEntries: Bool = true
  ) -> DayEmptyState? {
    switch content {
    case .rows:
      return nil
    case .nonTeachingDay(let title):
      return .nonTeachingDay(title: title)
    case .noLessons:
      if sourceKind != .manual, fetchedAt == nil, let lastError { return .sourceFailed(lastError) }
      return hasTimetableEntries ? .noLessons : .noTimetable
    }
  }
}

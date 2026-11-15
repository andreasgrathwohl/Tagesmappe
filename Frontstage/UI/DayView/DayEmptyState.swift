import FrontstageCore
import Foundation

/// Leere Zustände der Tagesansicht (UI-13).
enum DayEmptyState: Equatable {
  case noLessons
  case nonTeachingDay(title: String)
  case sourceFailed(TimetableSourceError)
  /// Detailbereich ohne gewählte Stunde.
  case selectLesson

  /// `.rows` → `nil`. `.noLessons` mit Quelle ≠ manual, ohne je einen Stand (`fetchedAt == nil`) und mit
  /// Fehler → `sourceFailed`; sonst `noLessons`.
  static func make(
    content: DayContent, sourceKind: TimetableSourceKind, fetchedAt: Date?,
    lastError: TimetableSourceError?
  ) -> DayEmptyState? {
    switch content {
    case .rows:
      return nil
    case .nonTeachingDay(let title):
      return .nonTeachingDay(title: title)
    case .noLessons:
      if sourceKind != .manual, fetchedAt == nil, let lastError { return .sourceFailed(lastError) }
      return .noLessons
    }
  }
}

import FrontstageCore
import Foundation

/// Art einer Unterrichtsstunde in der Tagesansicht.
enum LessonStatus: Hashable {
  case regular
  case substitute
  /// Ausfall; die Herkunft entscheidet, ob er sich von Hand aufheben lässt (FR-8).
  case cancelled(Origin)
}

/// Eine Zuordnung samt Zustand. `availability == nil`: noch nicht gelesen (Systemstandard: kein Zustandssymbol).
struct MaterialRow: Identifiable, Hashable {
  let item: MaterialLinkItem
  let availability: MaterialAvailability?
  var id: UUID { item.id }
}

/// Eine Unterrichtsstunde mit Material und Stundenangaben (Thema, Bereitlegen, Hausaufgabe – FR-13).
struct LessonRow: Identifiable, Hashable {
  let lesson: Lesson
  let status: LessonStatus
  let materials: [MaterialRow]
  let info: LessonInfo
  /// Thema und Leistungsnachweise aus dem Jahresplan (FR-15.5, FR-15.6); `nil` ohne Plan.
  var planHint: LessonPlanHint? = nil
  var id: String { lesson.key.storageText }
}

/// Eine Zeile der Tagesansicht: Unterrichtsstunde oder Lücke.
enum DayRow: Identifiable, Hashable {
  case noLesson(period: Int, time: ClosedRange<TimeOfDay>?)
  case lesson(LessonRow)

  var id: String {
    switch self {
    case .noLesson(let period, _): "free-\(period)"
    case .lesson(let row): row.id
    }
  }
}

/// Inhalt der Tagesansicht.
enum DayContent: Hashable {
  /// Tag in einem unterrichtsfreien Zeitraum (Ferien, Feiertag).
  case nonTeachingDay(title: String)
  case noLessons
  case rows([DayRow])
}

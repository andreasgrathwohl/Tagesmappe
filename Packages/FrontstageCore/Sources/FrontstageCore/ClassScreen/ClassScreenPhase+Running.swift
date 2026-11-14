import Foundation

extension ClassScreenPhase {
  /// Schlüssel der Unterrichtsstunde, die gerade läuft; `nil` vor der nächsten Stunde und nach der letzten.
  /// Nur eine laufende Stunde zählt als „aktuell“ – an ihr hängt die Arbeitsform (FR-11.3).
  public var runningLessonKey: LessonKey? {
    switch self {
    case .inLesson(let lesson), .finalMinutes(let lesson): lesson.key
    case .upcoming, .noMoreLessons: nil
    }
  }
}

import FrontstageCore
import Foundation

/// Die gerade laufende Unterrichtsstunde, unabhängig davon, was der Zweitbildschirm zeigt.
///
/// Die Arbeitsform hängt an der laufenden Stunde (FR-11.3). Würde nur der Klassenbildschirm sie melden, ginge
/// eine Wahl verloren, die getroffen wird, während Material oder die Tafel am Zweitbildschirm steht.
@MainActor enum RunningLesson {
  /// Schlüssel der Stunde, die zum Zeitpunkt `date` läuft; `nil` in Pausen, vor der ersten und nach der letzten.
  static func key(in store: DataStore, at date: Date, calendar: Calendar = .current) -> LessonKey? {
    let lessons = (try? store.lessons(on: CalendarDay(date, calendar: calendar))) ?? []
    return ClassScreenCalculator.phase(now: TimeOfDay(date, calendar: calendar), lessons: lessons)
      .runningLessonKey
  }
}

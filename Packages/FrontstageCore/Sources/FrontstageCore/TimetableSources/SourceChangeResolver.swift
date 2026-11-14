/// Ordnet die Abweichungen einer Quelle den berechneten Unterrichtsstunden zu (ADR-0005).
public enum SourceChangeResolver {
  /// Ausfall → Schlüssel der berechneten Unterrichtsstunde (gleiche Stunde, Klasse, Fach); ohne Treffer → `unmatched`.
  /// Vertretungsstunde → immer `.substituteLesson(…, .source)`.
  public static func resolve(
    _ changes: [SourceChange], timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod]
  ) -> (resolved: [ScheduleChange], unmatched: [SourceChange]) {
    var resolved: [ScheduleChange] = []
    var unmatched: [SourceChange] = []
    // Stunden je Tag nur einmal berechnen; ohne Abweichungen, damit Vertretungen keine Ausfälle verdecken.
    var lessonsByDay: [CalendarDay: [Lesson]] = [:]

    for change in changes {
      switch change {
      case let .substitute(date, period, schoolClass, subject):
        resolved.append(
          .substituteLesson(
            date: date, period: period, schoolClass: schoolClass, subject: subject, .source))
      case let .cancelled(date, period, schoolClass, subject):
        let lessons =
          lessonsByDay[date]
          ?? TimetableCalculator.lessons(
            on: date, timetable: timetable, nonTeachingPeriods: nonTeachingPeriods, changes: [])
        lessonsByDay[date] = lessons
        // Bei mehreren Treffern (gleiche Stunde, Klasse, Fach) gilt der erste in der Tagesreihenfolge.
        if let match = lessons.first(where: {
          $0.period == period && $0.key.schoolClass == schoolClass && $0.key.subject == subject
            && !$0.isSubstituteLesson
        }) {
          resolved.append(.cancellation(match.key, .source))
        } else {
          unmatched.append(change)
        }
      }
    }
    return (resolved, unmatched)
  }
}

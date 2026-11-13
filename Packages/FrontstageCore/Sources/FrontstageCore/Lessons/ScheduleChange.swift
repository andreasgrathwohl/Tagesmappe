/// Abweichung vom regulären Stundenplan an einem Tag.
public enum ScheduleChange: Hashable, Codable, Sendable {
  /// Die Stunde mit diesem Schlüssel fällt aus.
  case cancellation(LessonKey, Origin)
  /// Zusätzliche Stunde, die der Stundenplan nicht vorsieht (Vertretung).
  case substituteLesson(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject, Origin)
}

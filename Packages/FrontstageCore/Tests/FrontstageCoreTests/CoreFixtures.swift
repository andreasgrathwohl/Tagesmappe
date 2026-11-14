@testable import FrontstageCore

/// Gemeinsame Bausteine für Kerntests (Teilplan 07).
enum CoreFixtures {
  /// Dienstag, 17.11.2026.
  static let tuesday = CalendarDay(year: 2026, month: 11, day: 17)

  /// Eine berechnete Unterrichtsstunde mit Zeitraum.
  static func lesson(
    _ cls: String, _ subject: String, period: Int, from: (Int, Int), to: (Int, Int),
    on day: CalendarDay = CoreFixtures.tuesday, ordinal: Int = 1, cancelled: Bool = false
  ) -> Lesson {
    Lesson(
      key: LessonKey(
        date: day, schoolClass: SchoolClass(cls), subject: Subject(subject), ordinal: ordinal),
      period: period,
      time: TimeOfDay(hour: from.0, minute: from.1)...TimeOfDay(hour: to.0, minute: to.1),
      isSubstituteLesson: false, isCancelled: cancelled,
      cancellationOrigin: cancelled ? .manual : nil)
  }
}

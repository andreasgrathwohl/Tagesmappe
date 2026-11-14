/// Wählbare Zielstunden für „Für <Klasse> übernehmen“ (FR-3.2). Es gibt keine automatische Zielwahl:
/// Die Lehrkraft wählt aus der hier berechneten Liste.
public enum ParallelLessonFinder {
  /// Kandidaten für „Für <Klasse> übernehmen“: alle nicht ausgefallenen Unterrichtsstunden von `schoolClass`
  /// (jedes Fach) ab `day` einschließlich bis `day + maxDays - 1`, in Tages- und Kern-Reihenfolge.
  public static func candidates(
    for schoolClass: SchoolClass, from day: CalendarDay, timetable: Timetable,
    nonTeachingPeriods: [NonTeachingPeriod], changes: [ScheduleChange], maxDays: Int = 28
  ) -> [Lesson] {
    guard maxDays > 0 else { return [] }
    var result: [Lesson] = []
    for offset in 0..<maxDays {
      let current = day.adding(days: offset)
      let lessons = TimetableCalculator.lessons(
        on: current, timetable: timetable, nonTeachingPeriods: nonTeachingPeriods,
        changes: changes)
      result += lessons.filter { $0.key.schoolClass == schoolClass && !$0.isCancelled }
    }
    return result
  }

  /// Klassen zur Wahl: alle Klassen mit Einträgen im Stundenplan außer `excluding`; sortiert nach `normalized`.
  public static func selectableClasses(in timetable: Timetable, excluding: SchoolClass)
    -> [SchoolClass]
  {
    let others = Set(timetable.entries.map(\.schoolClass)).subtracting([excluding])
    return others.sorted { $0.normalized < $1.normalized }
  }
}

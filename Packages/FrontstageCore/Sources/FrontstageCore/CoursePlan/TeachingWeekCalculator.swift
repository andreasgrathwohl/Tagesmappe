/// Unterrichtswoche (Glossar): ISO-Woche im Schuljahr mit mindestens einem Unterrichtstag.
public struct TeachingWeek: Hashable, Sendable {
  /// 1, 2, … ab Beginn des Schuljahrs.
  public let number: Int
  public let monday: CalendarDay
  public let isoWeek: ISOWeek
  /// Halbjahr des ersten Unterrichtstags.
  public let term: Term
  /// Aufsteigend sortiert.
  public let teachingDays: [CalendarDay]

  public init(
    number: Int, monday: CalendarDay, isoWeek: ISOWeek, term: Term, teachingDays: [CalendarDay]
  ) {
    self.number = number
    self.monday = monday
    self.isoWeek = isoWeek
    self.term = term
    self.teachingDays = teachingDays
  }
}

public enum TeachingWeekCalculator {
  /// Unterrichtstag: Montag bis Freitag, im Schuljahr, in keinem unterrichtsfreien Zeitraum.
  public static func isTeachingDay(
    _ day: CalendarDay, in year: SchoolYear, nonTeachingPeriods: [NonTeachingPeriod]
  ) -> Bool {
    guard year.contains(day), day.weekday.rawValue <= Weekday.friday.rawValue else { return false }
    return !nonTeachingPeriods.contains { $0.contains(day) }
  }

  /// Alle Unterrichtswochen des Schuljahrs, fortlaufend ab 1 nummeriert; Wochen ohne
  /// Unterrichtstag entfallen.
  public static func weeks(of year: SchoolYear, nonTeachingPeriods: [NonTeachingPeriod])
    -> [TeachingWeek]
  {
    var result: [TeachingWeek] = []
    var monday = year.firstDay.mondayOfWeek
    while monday <= year.lastDay {
      let days = (0..<5).map { monday.adding(days: $0) }.filter {
        isTeachingDay($0, in: year, nonTeachingPeriods: nonTeachingPeriods)
      }
      if let first = days.first, let term = year.term(of: first) {
        result.append(
          TeachingWeek(
            number: result.count + 1, monday: monday, isoWeek: monday.isoWeek, term: term,
            teachingDays: days))
      }
      monday = monday.adding(days: 7)
    }
    return result
  }
}

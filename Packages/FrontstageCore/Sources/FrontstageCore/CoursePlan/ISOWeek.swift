/// Kalenderwoche nach ISO 8601 (Woche beginnt Montag; Woche 1 enthält den ersten Donnerstag des Jahres).
public struct ISOWeek: Hashable, Comparable, Codable, Sendable {
  public let year: Int
  public let week: Int

  public init(year: Int, week: Int) {
    self.year = year
    self.week = week
  }

  public static func < (lhs: ISOWeek, rhs: ISOWeek) -> Bool {
    (lhs.year, lhs.week) < (rhs.year, rhs.week)
  }
}

extension CalendarDay {
  /// ISO-Woche dieses Tags. Der Donnerstag der Woche bestimmt das ISO-Jahr; gerechnet wird über
  /// die Tageszahl, ohne `Calendar`.
  public var isoWeek: ISOWeek {
    let thursday = mondayOfWeek.adding(days: 3)
    let jan1 = CalendarDay(year: thursday.year, month: 1, day: 1)
    let dayInYear = thursday.dayNumber - jan1.dayNumber + 1
    return ISOWeek(year: thursday.year, week: (dayInYear - 1) / 7 + 1)
  }
}

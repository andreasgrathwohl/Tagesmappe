import Foundation

/// Halbjahr (Glossar).
public enum Term: String, Codable, Sendable, CaseIterable { case first, second }

/// Schuljahr (Glossar, ADR-0013). Kennung ist `startYear`.
public struct SchoolYear: Hashable, Codable, Sendable {
  public var firstDay: CalendarDay
  /// Erster Tag des zweiten Halbjahrs.
  public var secondTermStart: CalendarDay
  public var lastDay: CalendarDay
  /// Jahrgang von Hand je Klasse (Schlüssel `SchoolClass.normalized`), nur für Klassen ohne Ziffern.
  public var gradeOverrides: [String: Int]

  public init(
    firstDay: CalendarDay, secondTermStart: CalendarDay, lastDay: CalendarDay,
    gradeOverrides: [String: Int] = [:]
  ) {
    self.firstDay = firstDay
    self.secondTermStart = secondTermStart
    self.lastDay = lastDay
    self.gradeOverrides = gradeOverrides
  }

  public var startYear: Int { firstDay.year }

  /// Anzeigetitel, z. B. „2026/27“.
  public var title: String {
    String(format: "%d/%02d", startYear, (startYear + 1) % 100)
  }

  public func contains(_ day: CalendarDay) -> Bool {
    day >= firstDay && day <= lastDay
  }

  /// Halbjahr des Tags; `nil` außerhalb des Schuljahrs.
  public func term(of day: CalendarDay) -> Term? {
    guard contains(day) else { return nil }
    return day < secondTermStart ? .first : .second
  }
}

public enum SchoolYearIssue: Hashable, Sendable {
  case lastDayBeforeFirstDay
  case secondTermOutside
  case overlaps(startYear: Int)
}

extension SchoolYear {
  /// Prüft gegen die übrigen Schuljahre; ein Schuljahr mit gleichem `startYear` in `others`
  /// zählt nicht (wird ersetzt).
  public func issue(among others: [SchoolYear]) -> SchoolYearIssue? {
    if lastDay < firstDay { return .lastDayBeforeFirstDay }
    if secondTermStart <= firstDay || secondTermStart > lastDay { return .secondTermOutside }
    for other in others where other.startYear != startYear {
      if firstDay <= other.lastDay && other.firstDay <= lastDay {
        return .overlaps(startYear: other.startYear)
      }
    }
    return nil
  }
}

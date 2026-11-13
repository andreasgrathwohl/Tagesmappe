import Foundation

/// Uhrzeit ohne Datum und ohne Zeitzone, auf die Minute genau.
public struct TimeOfDay: Hashable, Comparable, Codable, Sendable {
  public let hour: Int
  public let minute: Int

  /// Voraussetzung: `hour` in 0...23, `minute` in 0...59.
  public init(hour: Int, minute: Int) {
    precondition((0...23).contains(hour), "Stunde außerhalb 0...23")
    precondition((0...59).contains(minute), "Minute außerhalb 0...59")
    self.hour = hour
    self.minute = minute
  }

  /// Minuten seit Mitternacht (0...1439).
  public var minutesSinceMidnight: Int { hour * 60 + minute }

  /// Uhrzeit eines Zeitpunkts in der Zeitzone des übergebenen Kalenders; Sekunden werden abgeschnitten.
  /// Wie bei `CalendarDay` zählt vom Kalender nur die Zeitzone, gerechnet wird gregorianisch.
  public init(_ date: Date, calendar: Calendar) {
    let parts = CalendarDay.gregorian(in: calendar.timeZone).dateComponents(
      [.hour, .minute], from: date)
    self.init(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
  }

  public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
    lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
  }
}
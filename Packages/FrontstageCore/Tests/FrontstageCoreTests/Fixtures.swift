@testable import FrontstageCore

/// Kurzform für einen Kalendertag in Tests.
func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDay {
  CalendarDay(year: y, month: m, day: day)
}

/// Kurzform für eine Uhrzeit in Tests.
func t(_ h: Int, _ m: Int) -> TimeOfDay {
  TimeOfDay(hour: h, minute: m)
}

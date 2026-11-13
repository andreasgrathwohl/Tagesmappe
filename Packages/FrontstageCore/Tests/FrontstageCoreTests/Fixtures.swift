@testable import FrontstageCore

/// Kurzform für einen Kalendertag in Tests.
func d(_ y: Int, _ m: Int, _ day: Int) -> CalendarDay {
  CalendarDay(year: y, month: m, day: day)
}

/// Kurzform für eine Uhrzeit in Tests.
func t(_ h: Int, _ m: Int) -> TimeOfDay {
  TimeOfDay(hour: h, minute: m)
}

/// Stundenplan für Tests; Bezugswoche A ist die Woche ab Montag, 16.11.2026.
func timetable(
  _ entries: [TimetableEntry], bell: [Int: ClosedRange<TimeOfDay>] = [:], variants: Int = 1
) -> Timetable {
  Timetable(
    weekVariantCount: variants, referenceWeekA: d(2026, 11, 16),
    bellSchedule: BellSchedule(periods: bell), entries: entries)
}

/// Kurzform für einen Stundenplaneintrag in Tests.
func entry(
  _ weekday: Weekday, _ period: Int, _ schoolClass: String, _ subject: String,
  variant: WeekVariant? = nil
) -> TimetableEntry {
  TimetableEntry(
    weekVariant: variant, weekday: weekday, period: period, schoolClass: SchoolClass(schoolClass),
    subject: Subject(subject))
}

import FrontstageCore
import Foundation

/// Uhrzeiten einer Stunde im Systemformat (UI-15): 24 Stunden in de_DE, 12 Stunden in en_US.
enum LessonTimeFormat {
  /// „08:35 – 09:20“ (Systemformat des Gebietsschemas).
  static func range(
    _ time: ClosedRange<TimeOfDay>, on day: CalendarDay, calendar: Calendar = .current,
    locale: Locale = .current
  ) -> String {
    let (start, end) = dates(time, on: day, calendar: calendar)
    let style = Date.IntervalFormatStyle(
      date: nil, time: .shortened, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
    return style.format(start..<end)
  }

  /// Für VoiceOver: „08:35 bis 09:20“.
  static func accessibilityRange(
    _ time: ClosedRange<TimeOfDay>, on day: CalendarDay, calendar: Calendar = .current,
    locale: Locale = .current
  ) -> String {
    let (start, end) = dates(time, on: day, calendar: calendar)
    let format = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, calendar: calendar,
                                  timeZone: calendar.timeZone)
    return String(
      localized: "dayView.timeRange.accessibility \(start.formatted(format)) \(end.formatted(format))",
      locale: locale)
  }

  private static func dates(_ time: ClosedRange<TimeOfDay>, on day: CalendarDay, calendar: Calendar)
    -> (Date, Date)
  {
    func date(_ t: TimeOfDay) -> Date {
      calendar.date(
        from: DateComponents(
          year: day.year, month: day.month, day: day.day, hour: t.hour, minute: t.minute)) ?? Date()
    }
    return (date(time.lowerBound), date(time.upperBound))
  }
}

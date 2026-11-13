import Foundation
import Testing
@testable import FrontstageCore

@Suite("CalendarDay")
struct CalendarDayTests {
  @Test("Wochentag bekannter Daten")
  func weekdayOfKnownDates() {
    #expect(d(2026, 11, 16).weekday == .monday)
    #expect(d(2026, 11, 17).weekday == .tuesday)
    #expect(d(2024, 2, 29).weekday == .thursday)
    #expect(d(2000, 1, 1).weekday == .saturday)
    #expect(d(1970, 1, 1).weekday == .thursday)
  }

  @Test("Tageszahl und Rundreise")
  func dayNumberRoundTrip() {
    #expect(d(1970, 1, 1).dayNumber == 0)
    for x in [d(2026, 11, 16), d(2024, 2, 29), d(1969, 12, 31)] {
      #expect(CalendarDay(dayNumber: x.dayNumber) == x)
    }
  }

  @Test("Tage addieren über Monats- und Schaltjahrgrenzen")
  func addingDaysCrossesMonthAndLeapYear() {
    #expect(d(2026, 11, 30).adding(days: 1) == d(2026, 12, 1))
    #expect(d(2024, 2, 28).adding(days: 1) == d(2024, 2, 29))
    #expect(d(2026, 12, 31).adding(days: 1) == d(2027, 1, 1))
    #expect(d(2026, 11, 23).adding(days: -7) == d(2026, 11, 16))
  }

  @Test("Sortierung nach Datum")
  func comparableOrdersByDate() {
    #expect(d(2026, 11, 16) < d(2026, 11, 17))
    #expect(d(2026, 12, 1) > d(2026, 11, 30))
  }

  @Test("Speichertext und Rundreise")
  func storageTextRoundTrip() {
    #expect(d(2026, 11, 3).storageText == "2026-11-03")
    #expect(CalendarDay(storageText: "2026-11-03") == d(2026, 11, 3))
    #expect(CalendarDay(storageText: "2026-02-30") == nil)
    #expect(CalendarDay(storageText: "2026-13-01") == nil)
    #expect(CalendarDay(storageText: "17.11.2026") == nil)
    #expect(CalendarDay(storageText: "x") == nil)
  }

  @Test("Montag der Woche")
  func mondayOfWeek() {
    #expect(d(2026, 11, 17).mondayOfWeek == d(2026, 11, 16))
    #expect(d(2026, 11, 22).mondayOfWeek == d(2026, 11, 16))
    #expect(d(2026, 11, 16).mondayOfWeek == d(2026, 11, 16))
    #expect(d(2027, 1, 1).mondayOfWeek == d(2026, 12, 28))
  }

  @Test("Datumsumrechnung nutzt die übergebene Zeitzone")
  func dateConversionUsesGivenTimeZone() throws {
    let date = Date(timeIntervalSince1970: 1_774_740_600) // 2026-03-28T23:30:00Z
    var berlin = Calendar(identifier: .gregorian)
    berlin.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = try #require(TimeZone(identifier: "UTC"))
    #expect(CalendarDay(date, calendar: berlin) == d(2026, 3, 29))
    #expect(TimeOfDay(date, calendar: berlin) == t(0, 30))
    #expect(CalendarDay(date, calendar: utc) == d(2026, 3, 28))
    #expect(TimeOfDay(date, calendar: utc) == t(23, 30))
  }

  @Test(
    "Nicht-gregorianischer Kalender ergibt denselben Tag wie der gregorianische",
    arguments: [Calendar.Identifier.buddhist, .japanese])
  func dateConversionIgnoresCalendarSystem(identifier: Calendar.Identifier) throws {
    let date = Date(timeIntervalSince1970: 1_774_740_600) // 2026-03-28T23:30:00Z
    let berlin = try #require(TimeZone(identifier: "Europe/Berlin"))
    var other = Calendar(identifier: identifier)
    other.timeZone = berlin
    #expect(CalendarDay(date, calendar: other) == d(2026, 3, 29))
    #expect(TimeOfDay(date, calendar: other) == t(0, 30))
  }

  @Test("Uhrzeiten sind geordnet")
  func timeOfDayOrdering() {
    #expect(t(8, 35) < t(9, 20))
    #expect(t(9, 20).minutesSinceMidnight == 560)
  }
}

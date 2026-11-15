import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Uhrzeiten im Systemformat (UI-15).
@Suite struct LessonTimeFormatTests {
  private var berlin: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
    return calendar
  }

  private let time = TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20)

  @Test("UI-15: deutsches Systemformat 08:35 und 09:20")
  func germanRange() {
    let text = LessonTimeFormat.range(
      time, on: .tue17, calendar: berlin, locale: Locale(identifier: "de_DE"))
    #expect(text.contains("08:35"))
    #expect(text.contains("09:20"))
  }

  @Test("UI-15: 12-Stunden-Format in en_US enthält 8:35 und 9:20")
  func usRange() {
    let text = LessonTimeFormat.range(
      time, on: .tue17, calendar: berlin, locale: Locale(identifier: "en_US"))
    #expect(text.contains("8:35"))
    #expect(text.contains("9:20"))
    #expect(!text.contains("08:35"))
  }
}

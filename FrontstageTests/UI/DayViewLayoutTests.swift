import Foundation
import Testing

@testable import Frontstage

@Suite struct DayViewLayoutTests {
  @Test("AK-10: acht Zeilen passen ohne Scrollen auf 11 Zoll quer")
  func eightRowsFitElevenInch() throws {
    // 834 pt Höhe − 24 Status − 50 Leiste − 64 Kopf − 76 Smartboard-Leiste (Teilplan 06) − 100 Ränder = 520
    let height = try #require(DayViewLayout.rowHeight(availableHeight: 520, rowCount: 8))
    #expect(height >= 44)
  }

  @Test("Wenige Zeilen werden auf die Höchsthöhe begrenzt")
  func fewRowsAreCapped() {
    #expect(DayViewLayout.rowHeight(availableHeight: 600, rowCount: 5) == 96)
  }

  @Test("Zu viele Zeilen: Rückfall auf Scrollen")
  func tooManyRowsFallBackToScrolling() {
    #expect(DayViewLayout.rowHeight(availableHeight: 600, rowCount: 12) == nil)
  }

  @Test("Ohne Zeilen bleibt es bei der Höchsthöhe")
  func noRowsKeepMaximum() {
    #expect(DayViewLayout.rowHeight(availableHeight: 600, rowCount: 0) == 96)
  }
}

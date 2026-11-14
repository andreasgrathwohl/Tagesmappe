import Foundation
import Testing
@testable import FrontstageCore

@Suite("BellSchedule")
struct BellScheduleTests {
  /// Gespeichertes und synchronisiertes Format (FR-1.2): Stundennummer als Text-Schlüssel, Zeitspanne
  /// als Liste aus Beginn und Ende. Ändert sich dieser Text, lesen ältere Stände nicht mehr.
  private let pinnedJSON = #"{"periods":{"2":[{"hour":8,"minute":35},{"hour":9,"minute":20}]}}"#

  @Test("Festes JSON-Format wird gelesen (FR-1.2)")
  func decodesPinnedJSON() throws {
    let decoded = try JSONDecoder().decode(BellSchedule.self, from: Data(pinnedJSON.utf8))
    #expect(decoded == BellSchedule(periods: [2: t(8, 35)...t(9, 20)]))
  }

  @Test("Kodieren ergibt wieder dasselbe JSON-Format (FR-1.2)")
  func encodesToPinnedJSON() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(BellSchedule(periods: [2: t(8, 35)...t(9, 20)]))
    #expect(String(decoding: data, as: UTF8.self) == pinnedJSON)
  }

  @Test("Mehrere Stunden ergeben bei jedem Kodieren dieselben Bytes (FR-14)")
  func encodingManyPeriodsIsStable() throws {
    let schedule = BellSchedule(periods: [
      1: t(8, 0)...t(8, 45), 2: t(8, 50)...t(9, 35), 3: t(9, 50)...t(10, 35), 10: t(15, 0)...t(15, 45),
    ])
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let first = try encoder.encode(schedule)
    for _ in 0..<20 {
      // Frische Kopie mit neu aufgebautem Wörterbuch (eigene Iterationsreihenfolge).
      let copy = BellSchedule(periods: Dictionary(uniqueKeysWithValues: schedule.periods.shuffled()))
      #expect(try encoder.encode(copy) == first)
    }
    #expect(try JSONDecoder().decode(BellSchedule.self, from: first) == schedule)
  }
}

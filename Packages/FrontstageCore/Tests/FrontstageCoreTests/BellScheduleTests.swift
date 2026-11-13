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
}

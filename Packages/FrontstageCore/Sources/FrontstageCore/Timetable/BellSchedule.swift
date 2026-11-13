/// Zeitraster der Schule (FR-1.2): Stundennummer → Beginn und Ende der Stunde.
public struct BellSchedule: Hashable, Codable, Sendable {
  /// Schlüssel ist die Stundennummer (`period`).
  public var periods: [Int: ClosedRange<TimeOfDay>]

  public init(periods: [Int: ClosedRange<TimeOfDay>] = [:]) {
    self.periods = periods
  }
}

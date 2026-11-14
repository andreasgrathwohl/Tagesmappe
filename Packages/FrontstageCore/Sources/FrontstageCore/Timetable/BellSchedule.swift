/// Zeitraster der Schule (FR-1.2): Stundennummer → Beginn und Ende der Stunde.
public struct BellSchedule: Hashable, Codable, Sendable {
  /// Schlüssel ist die Stundennummer (`period`).
  public var periods: [Int: ClosedRange<TimeOfDay>]

  public init(periods: [Int: ClosedRange<TimeOfDay>] = [:]) {
    self.periods = periods
  }

  private enum CodingKeys: String, CodingKey { case periods }

  /// Explizit statt synthetisiert: Ein `[Int: …]`-Wörterbuch wird je nach Plattform als Objekt oder als
  /// flaches Array in Iterationsreihenfolge geschrieben. Hier immer als Objekt mit Text-Schlüsseln, das
  /// `.sortedKeys` stabil ordnet; die Prüfsumme des Datensatzes (FR-14) hängt daran.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    let textKeyed = Dictionary(uniqueKeysWithValues: periods.map { (String($0.key), $0.value) })
    try container.encode(textKeyed, forKey: .periods)
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let textKeyed = try container.decode([String: ClosedRange<TimeOfDay>].self, forKey: .periods)
    var result: [Int: ClosedRange<TimeOfDay>] = [:]
    for (key, value) in textKeyed {
      guard let period = Int(key) else {
        throw DecodingError.dataCorruptedError(
          forKey: .periods, in: container, debugDescription: "Keine Stundennummer: \(key)")
      }
      result[period] = value
    }
    self.periods = result
  }
}

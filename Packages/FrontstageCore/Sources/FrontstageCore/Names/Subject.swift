import Foundation

/// Unterrichtsfach: Vergleich über den normalisierten Namen, Anzeige in der eingegebenen Schreibweise.
public struct Subject: Hashable, Codable, Sendable {
  /// Kleingeschrieben, Leerraum-Folgen zu einem Leerzeichen zusammengefasst.
  public let normalized: String
  /// Getrimmte Originalschreibweise für die Anzeige.
  public let display: String

  /// Keine Abkürzungs-Zuordnung („E“ bleibt „E“).
  public init(_ raw: String) {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    self.display = trimmed
    self.normalized = trimmed.lowercased()
      .split(whereSeparator: { $0.isWhitespace })
      .joined(separator: " ")
  }

  // Gleichheit und Hash nur über `normalized`: Die synthetisierte Gleichheit würde `display` mitzählen,
  // und „Englisch“ ≠ „englisch“ würde jeden Schlüssel brechen, der das Fach enthält.
  public static func == (lhs: Subject, rhs: Subject) -> Bool {
    lhs.normalized == rhs.normalized
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(normalized)
  }
}

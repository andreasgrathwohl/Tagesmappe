/// Datenort (Glossar): wo die App-Daten zwischen den Geräten abgeglichen werden (FR-14, ADR-0012).
public enum DataLocation: String, Codable, Sendable, CaseIterable {
  case iCloud
  case oneDrive
}

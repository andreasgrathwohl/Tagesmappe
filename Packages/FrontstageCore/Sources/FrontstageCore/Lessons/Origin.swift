/// Herkunft einer Zuordnung: von Hand angelegt oder aus der Stundenplanquelle übernommen.
public enum Origin: String, Codable, Sendable {
  case manual
  case source
}

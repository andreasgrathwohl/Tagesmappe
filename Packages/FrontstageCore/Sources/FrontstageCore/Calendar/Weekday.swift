/// Wochentag nach ISO 8601: Montag = 1 bis Sonntag = 7.
public enum Weekday: Int, CaseIterable, Codable, Sendable {
  case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday
}
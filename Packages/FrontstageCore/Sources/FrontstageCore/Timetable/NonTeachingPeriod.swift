/// Unterrichtsfreie Zeit (Ferien, Studientage), beide Enden eingeschlossen.
public struct NonTeachingPeriod: Hashable, Codable, Sendable {
  public var from: CalendarDay
  public var to: CalendarDay
  public var title: String

  public init(from: CalendarDay, to: CalendarDay, title: String) {
    self.from = from
    self.to = to
    self.title = title
  }

  /// Wahr, wenn `day` zwischen `from` und `to` liegt (einschließlich).
  public func contains(_ day: CalendarDay) -> Bool {
    from <= day && day <= to
  }
}

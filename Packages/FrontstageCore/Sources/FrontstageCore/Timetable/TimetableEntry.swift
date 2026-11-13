/// Eine feste Stunde im Stundenplan: Wochentag, Stundennummer, Klasse und Fach.
public struct TimetableEntry: Hashable, Codable, Sendable {
  /// `nil` heißt: gilt in der A- und der B-Woche (bei nur einer Variante: in jeder Woche).
  public var weekVariant: WeekVariant?
  public var weekday: Weekday
  public var period: Int
  public var schoolClass: SchoolClass
  public var subject: Subject

  public init(
    weekVariant: WeekVariant? = nil, weekday: Weekday, period: Int, schoolClass: SchoolClass,
    subject: Subject
  ) {
    self.weekVariant = weekVariant
    self.weekday = weekday
    self.period = period
    self.schoolClass = schoolClass
    self.subject = subject
  }
}

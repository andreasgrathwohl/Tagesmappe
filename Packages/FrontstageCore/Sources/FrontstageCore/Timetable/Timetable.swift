/// Der Stundenplan: Wochenrhythmus, Zeitraster und feste Stunden.
public struct Timetable: Codable, Sendable {
  /// 1 (jede Woche gleich) oder 2 (A-/B-Woche).
  public var weekVariantCount: Int
  /// Ein beliebiger Tag der A-Woche; maßgeblich ist die Woche, die ihn enthält.
  public var referenceWeekA: CalendarDay
  public var bellSchedule: BellSchedule
  public var entries: [TimetableEntry]

  public init(
    weekVariantCount: Int = 1, referenceWeekA: CalendarDay, bellSchedule: BellSchedule = BellSchedule(),
    entries: [TimetableEntry] = []
  ) {
    self.weekVariantCount = weekVariantCount
    self.referenceWeekA = referenceWeekA
    self.bellSchedule = bellSchedule
    self.entries = entries
  }

  /// Eine Variante, leeres Zeitraster, keine Einträge. Die Bezugswoche ist bei einer Variante ohne Bedeutung.
  public static let empty = Timetable(
    weekVariantCount: 1, referenceWeekA: CalendarDay(year: 1970, month: 1, day: 1))
}

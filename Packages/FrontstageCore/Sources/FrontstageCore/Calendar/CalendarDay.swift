import Foundation

/// Kalendertag ohne Zeitzone; zwei Geräte in verschiedenen Zeitzonen meinen mit demselben Wert
/// denselben Schultag.
public struct CalendarDay: Hashable, Comparable, Codable, Sendable {
  public let year: Int
  public let month: Int
  public let day: Int

  /// Voraussetzung: gültiges Datum im gregorianischen Kalender.
  public init(year: Int, month: Int, day: Int) {
    precondition(Self.isValid(year: year, month: month, day: day), "Ungültiges Datum")
    self.year = year
    self.month = month
    self.day = day
  }

  /// Tag aus dem Speichertext `yyyy-MM-dd`; `nil` bei falschem Format oder ungültigem Datum.
  public init?(storageText: String) {
    let parts = storageText.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3,
      parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
      parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
      let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
      Self.isValid(year: y, month: m, day: d)
    else { return nil }
    self.init(year: y, month: m, day: d)
  }

  /// Tage seit 1970-01-01 (negativ davor).
  public init(dayNumber: Int) {
    // civil_from_days (H. Hinnant, gemeinfrei)
    let z = dayNumber + 719_468
    let era = (z >= 0 ? z : z - 146_096) / 146_097
    let doe = z - era * 146_097
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let d = doy - (153 * mp + 2) / 5 + 1
    let m = mp < 10 ? mp + 3 : mp - 9
    self.year = yoe + era * 400 + (m <= 2 ? 1 : 0)
    self.month = m
    self.day = d
  }

  /// Kalendertag eines Zeitpunkts im übergebenen Kalender (und dessen Zeitzone).
  /// Grenze App → Kern: Der Kern liest selbst nie die Uhr oder die aktuelle Zeitzone.
  public init(_ date: Date, calendar: Calendar) {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    self.init(year: parts.year ?? 1970, month: parts.month ?? 1, day: parts.day ?? 1)
  }

  /// ISO-Text `yyyy-MM-dd`; sortiert als Text wie als Datum (für Jahre 1000...9999).
  public var storageText: String {
    let y = String(year)
    let paddedYear = String(repeating: "0", count: max(0, 4 - y.count)) + y
    return "\(paddedYear)-\(month < 10 ? "0" : "")\(month)-\(day < 10 ? "0" : "")\(day)"
  }

  /// Tage seit 1970-01-01 (negativ davor).
  public var dayNumber: Int {
    // days_from_civil (H. Hinnant, gemeinfrei)
    let y = month <= 2 ? year - 1 : year
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let mp = (month + 9) % 12  // März = 0
    let doy = (153 * mp + 2) / 5 + day - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146_097 + doe - 719_468
  }

  /// Der Tag `days` Tage später (negativ: früher).
  public func adding(days: Int) -> CalendarDay {
    CalendarDay(dayNumber: dayNumber + days)
  }

  /// Wochentag; 1970-01-01 war ein Donnerstag.
  public var weekday: Weekday {
    let index = ((dayNumber + 3) % 7 + 7) % 7
    return Weekday(rawValue: index + 1)!
  }

  /// Montag der Woche, die diesen Tag enthält (Sonntag gehört zur laufenden Woche).
  public var mondayOfWeek: CalendarDay {
    CalendarDay(dayNumber: dayNumber - (weekday.rawValue - 1))
  }

  public static func < (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
    lhs.dayNumber < rhs.dayNumber
  }

  /// Gültig, wenn die Rundreise über die Tageszahl denselben Tag ergibt.
  private static func isValid(year: Int, month: Int, day: Int) -> Bool {
    guard (1...12).contains(month), (1...31).contains(day) else { return false }
    let z = CalendarDay(unchecked: year, month, day).dayNumber
    let back = CalendarDay(dayNumber: z)
    return back.year == year && back.month == month && back.day == day
  }

  private init(unchecked year: Int, _ month: Int, _ day: Int) {
    self.year = year
    self.month = month
    self.day = day
  }
}

/// Rest mit Vorzeichen des Teilers (Abrundung): `floorMod(-1, 7) == 6`.
func floorMod(_ a: Int, _ n: Int) -> Int {
  ((a % n) + n) % n
}

/// Ganzzahldivision mit Abrundung: `floorDiv(-1, 7) == -1` (Swifts `/` schneidet zu 0 hin ab).
func floorDiv(_ a: Int, _ n: Int) -> Int {
  (a - floorMod(a, n)) / n
}

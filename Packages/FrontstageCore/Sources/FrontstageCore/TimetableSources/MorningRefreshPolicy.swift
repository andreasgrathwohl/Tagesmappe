import Foundation

/// Wann die Quelle abgefragt wird (ADR-0004, RISK-1): schonend, damit kein Konto gesperrt wird.
public enum MorningRefreshPolicy {
  public static let automaticAttemptsPerDay = 3
  public static let automaticRetryInterval: TimeInterval = 30 * 60
  public static let userRequestInterval: TimeInterval = 60

  /// Automatisch: kein Erfolg heute, weniger als 3 automatische Versuche heute, letzter Versuch ≥ 30 min her.
  /// Knopfdruck: letzter Versuch ≥ 60 s her (auch nach einem Erfolg heute).
  public static func shouldFetch(
    _ trigger: RefreshTrigger, status: SourceStatus, now: Date, calendar: Calendar
  ) -> Bool {
    let sinceLastAttempt = status.lastAttemptAt.map { now.timeIntervalSince($0) }
    if trigger == .userRequest {
      return sinceLastAttempt.map { $0 >= userRequestInterval } ?? true
    }
    guard status.isStale(now: now, calendar: calendar) else { return false }
    let today = CalendarDay(now, calendar: calendar)
    let attemptsToday = status.automaticAttemptsDay == today ? status.automaticAttemptsCount : 0
    guard attemptsToday < automaticAttemptsPerDay else { return false }
    return sinceLastAttempt.map { $0 >= automaticRetryInterval } ?? true
  }

  /// Nächster Tag 05:30 Ortszeit – frühester Beginn der Hintergrund-Aktualisierung (ADR-0004).
  public static func nextBackgroundBeginDate(after now: Date, calendar: Calendar) -> Date {
    let tomorrow = CalendarDay(now, calendar: calendar).adding(days: 1)
    let components = DateComponents(
      year: tomorrow.year, month: tomorrow.month, day: tomorrow.day, hour: 5, minute: 30)
    return calendar.date(from: components) ?? now.addingTimeInterval(24 * 3600)
  }
}

import Foundation

/// Auslöser einer Abfrage bei der Stundenplan-Quelle.
public enum RefreshTrigger: String, Codable, Sendable {
  /// Szene wird aktiv (nicht: App startet) – maßgeblich für „erstes Öffnen am Tag“ (AK-21).
  case appBecameActive
  case backgroundRefresh
  case userRequest

  /// Automatisch ausgelöst, also an Tageslimit und Abstand gebunden.
  var isAutomatic: Bool { self != .userRequest }
}

/// Stand der Quelle: Zeitpunkte, Fehlzähler und Zähler der automatischen Versuche des Tages.
/// Enthält nie Zugangsdaten oder Token (Fehlertexte nur zur Diagnose).
public struct SourceStatus: Hashable, Codable, Sendable {
  public var lastSuccessAt: Date?
  public var lastAttemptAt: Date?
  public var consecutiveFailures: Int
  public var lastError: TimetableSourceError?
  public var automaticAttemptsDay: CalendarDay?
  public var automaticAttemptsCount: Int

  public init() {
    consecutiveFailures = 0
    automaticAttemptsCount = 0
  }

  /// Vermerkt den Beginn eines Versuchs; automatische Versuche zählen je Kalendertag.
  public func recordingAttempt(_ trigger: RefreshTrigger, at: Date, calendar: Calendar)
    -> SourceStatus
  {
    var copy = self
    copy.lastAttemptAt = at
    if trigger.isAutomatic {
      let today = CalendarDay(at, calendar: calendar)
      if automaticAttemptsDay == today {
        copy.automaticAttemptsCount += 1
      } else {
        copy.automaticAttemptsDay = today
        copy.automaticAttemptsCount = 1
      }
    }
    return copy
  }

  public func recordingSuccess(at: Date) -> SourceStatus {
    var copy = self
    copy.lastSuccessAt = at
    copy.consecutiveFailures = 0
    copy.lastError = nil
    return copy
  }

  public func recordingFailure(_ error: TimetableSourceError, at: Date) -> SourceStatus {
    var copy = self
    copy.consecutiveFailures += 1
    copy.lastError = error
    return copy
  }

  /// Ab drei Fehlern in Folge soll die Oberfläche die Pflege von Hand anbieten (Area stundenplan-quellen).
  public var suggestsManualMaintenance: Bool { consecutiveFailures >= 3 }

  /// Kein Erfolg am Kalendertag von `now`.
  public func isStale(now: Date, calendar: Calendar) -> Bool {
    guard let lastSuccessAt else { return true }
    return CalendarDay(lastSuccessAt, calendar: calendar) != CalendarDay(now, calendar: calendar)
  }
}

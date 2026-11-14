import Foundation

/// Phasen-Timer des Klassenbildschirms (FR-11.2). Rechnet aus einem Endzeitpunkt,
/// nicht aus Ticks: Die aktuelle Zeit (`now`) kommt immer von außen, der Typ
/// hält weder eine Uhr noch einen `Timer`.
public struct PhaseTimer: Hashable, Sendable {
  public enum State: Hashable, Sendable {
    case idle
    case running(endDate: Date)
    case paused(remaining: TimeInterval)
  }

  public private(set) var state: State

  public init() { state = .idle }

  /// Startet den Timer und überschreibt jeden bisherigen Zustand.
  public mutating func start(duration: TimeInterval, now: Date) {
    state = .running(endDate: now.addingTimeInterval(max(0, duration)))
  }

  /// Hält einen laufenden Timer an; aus `idle` oder `paused` wirkungslos.
  public mutating func pause(now: Date) {
    guard case .running(let endDate) = state else { return }
    state = .paused(remaining: max(0, endDate.timeIntervalSince(now)))
  }

  /// Setzt einen angehaltenen Timer fort; sonst wirkungslos.
  public mutating func resume(now: Date) {
    guard case .paused(let remaining) = state else { return }
    state = .running(endDate: now.addingTimeInterval(remaining))
  }

  public mutating func stop() { state = .idle }

  /// Restzeit; `nil` bei `idle`, nie kleiner als 0.
  public func remaining(at now: Date) -> TimeInterval? {
    switch state {
    case .idle: return nil
    case .running(let endDate): return max(0, endDate.timeIntervalSince(now))
    case .paused(let remaining): return remaining
    }
  }

  /// Nur ein laufender Timer läuft ab; ein angehaltener nie.
  public func isExpired(at now: Date) -> Bool {
    guard case .running(let endDate) = state else { return false }
    return now >= endDate
  }

  /// Signal nur, wenn der Ablauf höchstens `tolerance` Sekunden zurückliegt
  /// (kein verspätetes Signal, etwa nach dem Aufwachen des Geräts).
  public func shouldPlaySignal(at now: Date, tolerance: TimeInterval = 2) -> Bool {
    guard case .running(let endDate) = state, now >= endDate else { return false }
    return now.timeIntervalSince(endDate) <= tolerance
  }

  /// „m:ss“, auf volle Sekunden aufgerundet; Minuten laufen über 59 hinaus.
  public static func format(_ remaining: TimeInterval) -> String {
    let total = Int(max(0, remaining).rounded(.up))
    return "\(total / 60):" + (total % 60 < 10 ? "0" : "") + "\(total % 60)"
  }
}

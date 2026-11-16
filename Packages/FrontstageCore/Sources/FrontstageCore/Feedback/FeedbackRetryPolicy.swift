import Foundation

/// Wiederholungsregeln für das Hochladen (Entscheidung 16).
public enum FeedbackRetryPolicy {
  public static let maxAttempts = 3
  /// Sekunden vor Versuch 2 und 3.
  public static let delays: [Double] = [1, 4]

  /// Netzfehler (`nil`) und 5xx werden wiederholt, alles andere nicht.
  public static func shouldRetry(statusCode: Int?) -> Bool {
    guard let statusCode else { return true }
    return (500...599).contains(statusCode)
  }
}

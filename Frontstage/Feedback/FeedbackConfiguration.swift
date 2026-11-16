import Foundation
import FrontstageCore

/// Rückmeldung-Einstellungen aus der Info.plist (Build-Einstellungen, ADR-0014). Platzhalter und
/// nicht aufgelöste `$(…)`-Werte ergeben `nil`.
enum FeedbackConfiguration {
  private static let placeholderKey = "not-a-real-key"

  private static func string(_ key: String, bundle: Bundle) -> String? {
    bundle.object(forInfoDictionaryKey: key) as? String
  }

  static func recipient(bundle: Bundle = .main) -> String? {
    FeedbackRecipient.resolve(string("FrontstageFeedbackEmail", bundle: bundle))
  }

  /// Ohne App-Schlüssel gilt der Dienst als nicht hinterlegt.
  static func service(bundle: Bundle = .main) -> FeedbackServiceEndpoint? {
    guard appKey(bundle: bundle) != nil else { return nil }
    return FeedbackServiceEndpoint.resolve(string("FrontstageFeedbackURL", bundle: bundle))
  }

  static func appKey(bundle: Bundle = .main) -> String? {
    guard let raw = string("FrontstageFeedbackAppKey", bundle: bundle) else { return nil }
    let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, value != placeholderKey, !value.contains("$(") else { return nil }
    return value
  }
}

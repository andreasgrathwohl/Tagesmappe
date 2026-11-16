import Foundation

/// Einmalige Zustimmung zum Hochladen von Rückmeldungen (Entscheidung 18). Gemerkt wird nur ein Wahrheitswert
/// in den lokalen Einstellungen, ohne Zeitpunkt und ohne Bezug zu einer Person.
enum FeedbackConsent {
  static let key = "feedback.consent.v1"

  static func isGiven(defaults: UserDefaults = .standard) -> Bool {
    defaults.bool(forKey: key)
  }

  static func give(defaults: UserDefaults = .standard) {
    defaults.set(true, forKey: key)
  }
}

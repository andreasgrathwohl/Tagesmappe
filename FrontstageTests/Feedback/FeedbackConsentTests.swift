import Foundation
import Testing

@testable import Frontstage

@Suite struct FeedbackConsentTests {
  @Test("Zustimmung wird gemerkt")
  func remembersConsent() throws {
    let name = "feedback-consent-test-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    #expect(!FeedbackConsent.isGiven(defaults: defaults))
    FeedbackConsent.give(defaults: defaults)
    #expect(FeedbackConsent.isGiven(defaults: defaults))
  }
}

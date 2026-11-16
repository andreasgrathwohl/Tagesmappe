import Testing
@testable import FrontstageCore

@Suite("Feedback Recipient") struct FeedbackRecipientTests {
  @Test("Gültige Adresse getrimmt")
  func acceptsValid() {
    #expect(FeedbackRecipient.resolve("  hilfe@frontstage-rueckmeldung.de ") == "hilfe@frontstage-rueckmeldung.de")
  }

  @Test("Review 3: Platzhalter abgelehnt")
  func rejectsPlaceholders() {
    for raw in ["feedback@example.com", "a@b.local", "a@b.test", "a@x.invalid", "a@localhost", "a@EXAMPLE.org", "a@x.example"] {
      #expect(FeedbackRecipient.resolve(raw) == nil, "\(raw)")
    }
  }

  @Test("Review 3: unaufgelöste Build-Einstellung abgelehnt")
  func rejectsUnresolvedBuildSetting() {
    #expect(FeedbackRecipient.resolve("$(FEEDBACK_EMAIL)") == nil)
    #expect(FeedbackRecipient.resolve("") == nil)
    #expect(FeedbackRecipient.resolve(nil) == nil)
  }

  @Test("Formfehler abgelehnt")
  func rejectsMalformed() {
    for raw in ["a@@b.de", "@b.de", "a@", "a b@c.de", "a@bde"] {
      #expect(FeedbackRecipient.resolve(raw) == nil, "\(raw)")
    }
  }
}

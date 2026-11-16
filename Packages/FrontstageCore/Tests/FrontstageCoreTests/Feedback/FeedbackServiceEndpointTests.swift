import Testing
@testable import FrontstageCore

@Suite("Feedback Service Endpoint") struct FeedbackServiceEndpointTests {
  @Test("https-Basis ohne Schrägstrich am Ende")
  func resolvesBase() {
    let e = FeedbackServiceEndpoint.resolve("https://rueckmeldung.frontstage-app.de/")
    #expect(e?.baseURL.absoluteString == "https://rueckmeldung.frontstage-app.de")
    #expect(e?.feedbackURL.absoluteString == "https://rueckmeldung.frontstage-app.de/api/v1/feedback")
  }

  @Test("Review 3: Platzhalter, http, unaufgelöst → nil")
  func rejectsPlaceholders() {
    let raws = ["https://frontstage.example.com", "http://x.de", "$(FEEDBACK_URL)", "", "https://x.de/pfad?x=1",
                "https://x.de/#a", "https://x.de/pfad", "https://localhost"]
    for raw in raws {
      #expect(FeedbackServiceEndpoint.resolve(raw) == nil, "\(raw)")
    }
    #expect(FeedbackServiceEndpoint.resolve(nil) == nil)
  }

  @Test("Datenschutzseite")
  func privacyURL() {
    #expect(FeedbackServiceEndpoint.resolve("https://x.de")?.privacyURL.absoluteString == "https://x.de/datenschutz")
  }
}

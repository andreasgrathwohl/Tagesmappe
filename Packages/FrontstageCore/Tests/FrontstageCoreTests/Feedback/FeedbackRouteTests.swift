import Testing
@testable import FrontstageCore

@Suite("Feedback Route") struct FeedbackRouteTests {
  @Test("Mit Adresse und Konto: Mail")
  func mailWhenPossible() {
    #expect(FeedbackRoute.fallback(recipient: "a@b.de", canSendMail: true) == .mail(recipient: "a@b.de"))
  }

  @Test("Review 3: fehlende Adresse vor fehlendem Konto")
  func noRecipientWinsOverMailAccount() {
    #expect(FeedbackRoute.fallback(recipient: nil, canSendMail: false) == .share(.noRecipient))
    #expect(FeedbackRoute.fallback(recipient: nil, canSendMail: true) == .share(.noRecipient))
  }

  @Test("Ohne Konto: Teilen")
  func shareWithoutMailAccount() {
    #expect(FeedbackRoute.fallback(recipient: "a@b.de", canSendMail: false) == .share(.noMailAccount))
  }

  @Test("Review 3: Dienst schlägt Mail")
  func uploadWinsWhenServiceConfigured() throws {
    let service = try #require(FeedbackServiceEndpoint.resolve("https://rueckmeldung.frontstage-app.de"))
    #expect(FeedbackRoute.choose(service: service, recipient: "a@b.de", canSendMail: true) == .upload(endpoint: service))
    #expect(FeedbackRoute.choose(service: nil, recipient: "a@b.de", canSendMail: true) == .mail(recipient: "a@b.de"))
  }
}

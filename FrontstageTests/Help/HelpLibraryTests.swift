import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct HelpLibraryTests {
  @Test("Alle angezeigten Artikel laden aus dem App-Bundle, ohne Befund") func everyTopicLoadsFromBundle() {
    let (catalog, issues) = HelpLibrary.load(bundle: .main)
    #expect(issues.isEmpty)
    #expect(catalog.articles.count == HelpTopic.availableCases.count)
  }

  @Test("Dienst ohne Schlüssel gilt als nicht hinterlegt") func serviceNeedsKey() {
    if FeedbackConfiguration.service() != nil {
      #expect(FeedbackConfiguration.appKey() != nil)
    }
  }

  @Test("Adresse ist nil oder gültig – nie ein Platzhalter") func recipientIsNilOrResolved() {
    if let r = FeedbackConfiguration.recipient() { #expect(FeedbackRecipient.resolve(r) == r) }
  }
}

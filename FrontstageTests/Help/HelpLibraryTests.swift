import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct HelpLibraryTests {
  @Test("Alle 21 Artikel laden aus dem App-Bundle, ohne Befund") func everyTopicLoadsFromBundle() {
    let (catalog, issues) = HelpLibrary.load(bundle: .main)
    #expect(issues.isEmpty)
    #expect(catalog.articles.count == 21)
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

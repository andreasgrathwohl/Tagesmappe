import Foundation
import Testing

@testable import Frontstage

@MainActor @Suite struct DocumentHandOffTests {
  @Test("Office-Adresse ohne Antwort innerhalb der Frist ergibt nil")
  func officeURITimesOut() async {
    // Die Attrappe antwortet nie; sie wartet abbrechbar, damit der Test sauber endet.
    let handOff = SystemDocumentHandOff(openURL: { _ in
      try? await Task.sleep(for: .seconds(3600))
      return true
    })
    let result = await handOff.openOfficeURI("ms-word:ofe|u|https://example.com/a.docx", limit: .milliseconds(50))
    #expect(result == nil)
  }

  @Test("Abgelehnte Office-Adresse ergibt false")
  func officeURIRejected() async {
    let handOff = SystemDocumentHandOff(openURL: { _ in false })
    let result = await handOff.openOfficeURI("ms-word:ofe|u|https://example.com/a.docx", limit: .seconds(5))
    #expect(result == false)
  }

  @Test("Angenommene Office-Adresse ergibt true")
  func officeURIAccepted() async {
    let handOff = SystemDocumentHandOff(openURL: { _ in true })
    let result = await handOff.openOfficeURI("ms-word:ofe|u|https://example.com/a.docx", limit: .seconds(5))
    #expect(result == true)
  }
}

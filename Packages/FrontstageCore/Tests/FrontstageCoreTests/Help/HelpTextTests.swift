import Testing
@testable import FrontstageCore

@Suite("Help Text") struct HelpTextTests {
  @Test("Faltung: Umlaute, ß, Akzente, Groß") func folds() {
    #expect(HelpText.fold("Übernehmen ÄÖÜ ß Café") == "ubernehmen aou ss cafe")
  }

  @Test("Wörter: Satzzeichen trennen") func splitsWords() {
    #expect(HelpText.words("Ferien/Feiertage, 8b!") == ["ferien", "feiertage", "8b"])
  }

  @Test("Wörter: leerer Text ergibt keine Wörter") func emptyWords() {
    #expect(HelpText.words(" ,;/ ") == [])
  }
}

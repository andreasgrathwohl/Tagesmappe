import Testing
@testable import FrontstageCore

@Suite("SolutionMatching")
struct SolutionMatchingTests {
  @Test("Lösung mit Gedankenstrich hinter dem Namen")
  func findsDashSuffix() {
    #expect(
      SolutionMatching.bestCandidate(
        forSheetNamed: "AB Bruchrechnen.pdf",
        among: ["AB Bruchrechnen.pdf", "AB Bruchrechnen – Lösung.pdf", "Andere.pdf"])
        == "AB Bruchrechnen – Lösung.pdf")
  }

  @Test("Unterstrich mit Loesung und Lösungswort vorn")
  func findsUnderscoreLoesungAndPrefix() {
    #expect(
      SolutionMatching.bestCandidate(forSheetNamed: "AB Bruchrechnen.pdf", among: ["AB Bruchrechnen_Loesung.pdf"])
        == "AB Bruchrechnen_Loesung.pdf")
    #expect(
      SolutionMatching.bestCandidate(forSheetNamed: "AB Bruchrechnen.pdf", among: ["Lösung AB Bruchrechnen.pdf"])
        == "Lösung AB Bruchrechnen.pdf")
  }

  @Test("Groß-/Kleinschreibung, Klammern und Lsg")
  func ignoresCaseAccentsAndLsg() {
    #expect(
      SolutionMatching.bestCandidate(forSheetNamed: "ab bruchrechnen.PDF", among: ["AB Bruchrechnen (LSG).png"])
        == "AB Bruchrechnen (LSG).png")
  }

  @Test("PDF vor Bild, dann kürzer, dann alphabetisch")
  func prefersPdfThenShorterThenAlphabetical() {
    #expect(
      SolutionMatching.bestCandidate(
        forSheetNamed: "Test.pdf", among: ["Test Lösungen.png", "Test Lösungen.pdf", "Test Lösung.pdf"])
        == "Test Lösung.pdf")
  }

  @Test("Anderer Stamm, keine PDF/Bild-Datei, das Blatt selbst, Lösungswort im Wort")
  func rejectsOtherStemsNonDocumentsAndSheetItself() {
    #expect(
      SolutionMatching.bestCandidate(
        forSheetNamed: "AB Bruchrechnen.pdf",
        among: [
          "AB Bruchrechnen 2 – Lösung.pdf", "AB Bruchrechnen – Lösung.docx", "AB Bruchrechnen.pdf",
          "Lösungsweg AB Bruchrechnen.pdf",
        ]) == nil)
  }
}

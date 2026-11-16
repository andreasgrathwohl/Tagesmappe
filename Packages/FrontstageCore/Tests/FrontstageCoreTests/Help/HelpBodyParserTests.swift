import Testing
@testable import FrontstageCore

@Suite("Help Body")
struct HelpBodyParserTests {
  @Test("Absatz, Zwischentitel, Liste, Schritte, Hinweis (FR-17)")
  func parsesAllBlocks() throws {
    let text = "Erste Zeile\nzweite Zeile\n\n## So geht es\n1. Öffne Einrichten.\n2. Tippe auf **Datenort**.\n\n- iCloud\n- OneDrive\n\n> Wechseln nimmt alle Daten mit."
    #expect(try HelpBodyParser.parse(text) == [
      .paragraph("Erste Zeile zweite Zeile"), .heading("So geht es"),
      .steps(["Öffne Einrichten.", "Tippe auf **Datenort**."]),
      .bullets(["iCloud", "OneDrive"]), .note("Wechseln nimmt alle Daten mit."),
    ])
  }

  @Test("CRLF wie LF (FR-17)")
  func handlesCRLF() throws {
    let lf = "A\nB\n\n- x\n- y\n\n> n1\n> n2"
    let crlf = lf.replacingOccurrences(of: "\n", with: "\r\n")
    #expect(try HelpBodyParser.parse(crlf) == HelpBodyParser.parse(lf))
    #expect(try HelpBodyParser.parse(lf) == [.paragraph("A B"), .bullets(["x", "y"]), .note("n1 n2")])
  }

  @Test("Leerer Text ist ein Fehler (FR-17)")
  func emptyThrows() {
    #expect(throws: HelpBodyError.empty) { try HelpBodyParser.parse(" \n ") }
  }

  @Test("# und ### sind nicht erlaubt, mit Zeilennummer (FR-17)")
  func rejectsOtherHeadings() {
    #expect(throws: HelpBodyError.unsupportedHeading(line: 3)) { try HelpBodyParser.parse("A\n\n### B") }
    #expect(throws: HelpBodyError.unsupportedHeading(line: 1)) { try HelpBodyParser.parse("# B") }
  }

  @Test("Liste endet an Absatz ohne Leerzeile (FR-17)")
  func bulletThenParagraph() throws {
    #expect(try HelpBodyParser.parse("- a\nText") == [.bullets(["a"]), .paragraph("Text")])
  }

  @Test("Inline-Markdown bleibt unverändert (FR-17)")
  func keepsInlineMarkdown() throws {
    #expect(try HelpBodyParser.parse("Siehe [Hilfe](https://example.com) und **fett**")
            == [.paragraph("Siehe [Hilfe](https://example.com) und **fett**")])
  }
}

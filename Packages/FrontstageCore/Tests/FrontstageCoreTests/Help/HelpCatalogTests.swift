import Testing
@testable import FrontstageCore

@Suite("Help Catalog") struct HelpCatalogTests {
  private func completeText(_ key: String) -> String? {
    if key.hasSuffix(".keywords") { return "Eins, Zwei" }
    if key.hasSuffix(".body") { return "Ein Absatz." }
    return "Text zu \(key)"
  }

  @Test("Vollständige Texte ergeben 20 Artikel ohne Befund, ohne abgeschaltetes Thema (ADR-0016)")
  func buildsFromCompleteTexts() {
    let result = HelpCatalog.build(text: completeText)
    #expect(result.issues.isEmpty)
    #expect(result.catalog.articles.count == 20)
    #expect(result.catalog.articles.map(\.topic) == HelpTopic.availableCases)
    #expect(result.catalog.article(for: .schulmanager) == nil)
  }

  @Test("Fehlender Text wird gemeldet, Thema fehlt") func reportsMissingText() {
    let result = HelpCatalog.build { $0 == "help.board.body" ? nil : completeText($0) }
    #expect(result.issues == [.missingText(key: "help.board.body")])
    #expect(result.catalog.article(for: .board) == nil)
    #expect(result.catalog.articles.count == 19)
  }

  @Test("Ungültiger Text wird gemeldet") func reportsInvalidBody() {
    let result = HelpCatalog.build { $0 == "help.board.body" ? "# X" : completeText($0) }
    #expect(result.issues == [.invalidBody(.board, .unsupportedHeading(line: 1))])
    #expect(result.catalog.article(for: .board) == nil)
  }

  @Test("Stichwörter getrimmt, leere fallen weg") func splitsKeywords() {
    let result = HelpCatalog.build { $0 == "help.board.keywords" ? " AirPlay, Kabel ,, " : completeText($0) }
    #expect(result.catalog.article(for: .board)?.keywords == ["AirPlay", "Kabel"])
  }

  @Test("Artikel behalten Titel, Kurzfassung und Blöcke") func keepsFields() {
    let result = HelpCatalog.build(text: completeText)
    let article = result.catalog.article(for: .dayView)
    #expect(article?.title == "Text zu help.dayView.title")
    #expect(article?.summary == "Text zu help.dayView.summary")
    #expect(article?.blocks == [.paragraph("Ein Absatz.")])
  }
}

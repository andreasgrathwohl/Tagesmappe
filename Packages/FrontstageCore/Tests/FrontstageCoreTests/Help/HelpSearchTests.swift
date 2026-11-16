import Testing
@testable import FrontstageCore

@Suite("Help Search") struct HelpSearchTests {
  private func article(_ topic: HelpTopic, title: String, keywords: [String] = [], body: String = "Inhalt.") -> HelpArticle {
    HelpArticle(topic: topic, title: title, summary: "", keywords: keywords, blocks: [.paragraph(body)])
  }

  private var catalog: HelpCatalog {
    HelpCatalog(articles: [
      article(.secondScreen, title: "Smartboard verbinden", keywords: ["AirPlay", "Apple TV", "Kabel"]),
      article(.classScreen, title: "Klassenanzeige", body: "Per AirPlay zeigen."),
      article(.preparation, title: "Vorbereitung", body: "Für 8b übernehmen."),
      article(.coursePlan, title: "Kursplan", body: "Vorjahresplan übernehmen."),
      article(.nonTeachingDays, title: "Ferien und Feiertage"),
      article(.schoolYears, title: "Schuljahre", body: "Ferien eintragen."),
    ])
  }

  @Test("AK-57: Stichwort schlägt Text") func keywordBeatsBody() {
    #expect(HelpSearch.results(for: "AirPlay", in: catalog).first == .secondScreen)
  }

  @Test("AK-57: Titel schlägt Text, klein geschrieben") func titleBeatsBody() {
    #expect(HelpSearch.results(for: "ferien", in: catalog).first == .nonTeachingDays)
  }

  @Test("AK-57: ohne Umlaut") func foldsQuery() {
    #expect(Set(HelpSearch.results(for: "ubernehmen", in: catalog)) == [.preparation, .coursePlan])
  }

  @Test("Alle Wörter müssen passen") func allTermsRequired() {
    #expect(HelpSearch.results(for: "ferien airplay", in: catalog) == [])
  }

  @Test("Wortanfang, nicht Wortmitte") func prefixOnly() {
    #expect(HelpSearch.results(for: "play", in: catalog) == [])
  }

  @Test("Leer, nur 1 Zeichen, unbekannt → keine Treffer") func emptyResults() {
    #expect(HelpSearch.results(for: "", in: catalog) == [])
    #expect(HelpSearch.results(for: "a", in: catalog) == [])
    #expect(HelpSearch.results(for: "xyz", in: catalog) == [])
  }

  @Test("Gleichstand: Reihenfolge der Themen") func tieUsesTopicOrder() {
    // Beide nur im Text: gleiche Punkte, also Reihenfolge von HelpTopic.allCases (preparation vor coursePlan).
    #expect(HelpSearch.results(for: "ubernehmen", in: catalog) == [.preparation, .coursePlan])
  }

  @Test("Wortanfang im Titel zählt weniger als das ganze Titelwort") func titleExactBeatsPrefix() {
    let c = HelpCatalog(articles: [
      article(.dayView, title: "Tagesansicht"),
      article(.board, title: "Tag"),
    ])
    #expect(HelpSearch.results(for: "tag", in: c) == [.board, .dayView])
  }
}

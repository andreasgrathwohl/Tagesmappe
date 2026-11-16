import Foundation
import Testing
@testable import FrontstageCore

/// Prüft die echten Hilfetexte aus `Frontstage/Resources/Localizable.xcstrings` (FR-17, FR-17.2).
@Suite("Help Content") struct HelpContentTests {
  private enum LoadError: Error { case notFound(String) }

  /// Alle deutschen Werte der Tabelle (`strings[key].localizations.de.stringUnit.value`).
  private static func loadStrings() throws -> [String: String] {
    var url = URL(fileURLWithPath: #filePath)
    // Datei, Help, FrontstageCoreTests, Tests, FrontstageCore, Packages -> Repo-Wurzel
    for _ in 0..<6 { url.deleteLastPathComponent() }
    url.appendPathComponent("Frontstage/Resources/Localizable.xcstrings")
    let data = try Data(contentsOf: url)
    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let strings = root["strings"] as? [String: Any] else { throw LoadError.notFound("strings") }
    var result: [String: String] = [:]
    for (key, entry) in strings {
      if let dict = entry as? [String: Any],
         let localizations = dict["localizations"] as? [String: Any],
         let de = localizations["de"] as? [String: Any],
         let unit = de["stringUnit"] as? [String: Any],
         let value = unit["value"] as? String {
        result[key] = value
      }
    }
    return result
  }

  private static func articleKeys() -> [String] {
    HelpTopic.allCases.flatMap { topic in
      ["title", "summary", "keywords", "body"].map { "\(topic.textKeyPrefix).\($0)" }
    }
  }

  private static func catalog() throws -> HelpCatalog {
    let strings = try loadStrings()
    return HelpCatalog.build(text: { strings[$0] }).catalog
  }

  @Test("Jedes Thema hat alle vier Texte, ohne Befund") func catalogIsComplete() throws {
    let strings = try Self.loadStrings()
    let (catalog, issues) = HelpCatalog.build(text: { strings[$0] })
    #expect(issues.isEmpty)
    #expect(catalog.articles.count == HelpTopic.allCases.count)
  }

  @Test("Datenhygiene: nur Beispielklassen, kein @, kein %") func onlyNeutralExamples() throws {
    let strings = try Self.loadStrings()
    let allowed: Set<String> = ["7a", "8a", "8b", "9c", "6c"]
    let regex = try NSRegularExpression(pattern: "\\b\\d{1,2}[a-z]\\b")
    for key in Self.articleKeys() {
      let value = try #require(strings[key])
      #expect(!value.contains("@"), "@ in \(key)")
      #expect(!value.contains("%"), "% in \(key)")
      let lower = value.lowercased()
      let range = NSRange(lower.startIndex..., in: lower)
      for match in regex.matches(in: lower, range: range) {
        let found = (lower as NSString).substring(with: match.range)
        #expect(allowed.contains(found), "Klassenbezeichnung \(found) in \(key)")
      }
    }
  }

  @Test("AK-57 mit echten Texten") func searchMatchesAcceptance() throws {
    let catalog = try Self.catalog()
    #expect(HelpSearch.results(for: "AirPlay", in: catalog).first == .secondScreen)
    #expect(HelpSearch.results(for: "ferien", in: catalog).first == .nonTeachingDays)
    #expect(Set(HelpSearch.results(for: "ubernehmen", in: catalog)).isSuperset(of: [.preparation, .coursePlan]))
    #expect(HelpSearch.results(for: "xyz", in: catalog).isEmpty)
  }

  @Test("Jeder Titel höchstens 30 Zeichen, Kurzfassung ein Satz") func titleAndSummaryShape() throws {
    let catalog = try Self.catalog()
    for article in catalog.articles {
      #expect(article.title.count <= 30, "Titel zu lang: \(article.topic)")
      let summary = article.summary
      #expect(summary.hasSuffix("."), "Kurzfassung ohne Punkt: \(article.topic)")
      let inner = summary.dropLast()
      #expect(!inner.contains(". ") && !inner.contains("? ") && !inner.contains("! "),
              "Kurzfassung ist kein Satz: \(article.topic)")
      #expect(!inner.contains("\n"))
    }
  }

  @Test("Stichwörter 3 bis 8, Text 80 bis 250 Wörter") func keywordAndBodySize() throws {
    let strings = try Self.loadStrings()
    let catalog = try Self.catalog()
    for article in catalog.articles {
      #expect((3...8).contains(article.keywords.count), "Stichwörter: \(article.topic)")
      let body = try #require(strings["\(article.topic.textKeyPrefix).body"])
      let count = body.split(whereSeparator: { $0.isWhitespace }).count
      #expect((80...250).contains(count), "Wortzahl \(count): \(article.topic)")
    }
  }
}

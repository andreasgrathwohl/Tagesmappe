import Foundation

/// Befund beim Bauen des Katalogs.
public enum HelpCatalogIssue: Hashable, Sendable {
  case missingText(key: String)
  case invalidBody(HelpTopic, HelpBodyError)
}

/// Alle Hilfeartikel, in der Reihenfolge von `HelpTopic.allCases`.
public struct HelpCatalog: Sendable {
  public let articles: [HelpArticle]

  public init(articles: [HelpArticle]) {
    let order = Dictionary(uniqueKeysWithValues: HelpTopic.allCases.enumerated().map { ($1, $0) })
    self.articles = articles.sorted { (order[$0.topic] ?? 0) < (order[$1.topic] ?? 0) }
  }

  public func article(for topic: HelpTopic) -> HelpArticle? {
    articles.first { $0.topic == topic }
  }

  /// Baut den Katalog aus einer Textquelle (`nil` = Text fehlt). Stichwörter sind an "," getrennt,
  /// getrimmt und ohne leere. Ein Thema mit Befund fehlt im Katalog.
  public static func build(text: (String) -> String?) -> (catalog: HelpCatalog, issues: [HelpCatalogIssue]) {
    var articles: [HelpArticle] = []
    var issues: [HelpCatalogIssue] = []

    for topic in HelpTopic.allCases {
      let prefix = topic.textKeyPrefix
      var values: [String: String] = [:]
      var complete = true
      for part in ["title", "summary", "keywords", "body"] {
        let key = "\(prefix).\(part)"
        if let value = text(key) {
          values[part] = value
        } else {
          issues.append(.missingText(key: key))
          complete = false
        }
      }
      guard complete, let title = values["title"], let summary = values["summary"],
            let keywordText = values["keywords"], let body = values["body"] else { continue }

      do {
        let blocks = try HelpBodyParser.parse(body)
        let keywords = keywordText.split(separator: ",")
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
        articles.append(HelpArticle(topic: topic, title: title, summary: summary, keywords: keywords, blocks: blocks))
      } catch let error as HelpBodyError {
        issues.append(.invalidBody(topic, error))
      } catch {
        // `parse` wirft nur `HelpBodyError`.
      }
    }
    return (HelpCatalog(articles: articles), issues)
  }
}

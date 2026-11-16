import Foundation

/// Suche im Katalog: gefaltet, alle Suchwörter müssen als Wortanfang vorkommen.
public enum HelpSearch {
  public static let minimumTermLength = 2

  /// Punkte je Suchwort (der höchste passende Fund zählt): Titelwort gleich 12, Titelwortanfang 10,
  /// Stichwort 6, Kurzfassung 3, Text 1. Summe absteigend, bei Gleichstand Reihenfolge der Themen.
  public static func results(for query: String, in catalog: HelpCatalog) -> [HelpTopic] {
    let terms = HelpText.words(query).filter { $0.count >= minimumTermLength }
    guard !terms.isEmpty else { return [] }

    var scored: [(topic: HelpTopic, score: Int, order: Int)] = []
    for (index, article) in catalog.articles.enumerated() {
      let titleWords = HelpText.words(article.title)
      let keywordWords = article.keywords.flatMap(HelpText.words)
      let summaryWords = HelpText.words(article.summary)
      let bodyWords = HelpText.words(article.blocks.flatMap(strings).joined(separator: " "))

      var total = 0
      var matchedAll = true
      for term in terms {
        let points: Int
        if titleWords.contains(term) { points = 12 }
        else if titleWords.contains(where: { $0.hasPrefix(term) }) { points = 10 }
        else if keywordWords.contains(where: { $0.hasPrefix(term) }) { points = 6 }
        else if summaryWords.contains(where: { $0.hasPrefix(term) }) { points = 3 }
        else if bodyWords.contains(where: { $0.hasPrefix(term) }) { points = 1 }
        else { points = 0 }
        if points == 0 { matchedAll = false; break }
        total += points
      }
      if matchedAll { scored.append((article.topic, total, index)) }
    }
    return scored.sorted { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }.map(\.topic)
  }

  private static func strings(_ block: HelpBlock) -> [String] {
    switch block {
    case .heading(let s), .paragraph(let s), .note(let s): [s]
    case .bullets(let items), .steps(let items): items
    }
  }
}

import Foundation
import FrontstageCore
import Observation

/// Zustand des Hilfecenters: Suchtext, Trefferliste und die Gliederung nach Gruppen.
///
/// Swift-Hinweis: `@Observable` (Observation-Framework) ersetzt `ObservableObject`; SwiftUI beobachtet
/// automatisch genau die Eigenschaften, die `body` liest – ein `@Published` ist nicht nötig.
@MainActor @Observable
final class HelpCenterModel {
  private let catalog: HelpCatalog
  var query: String = ""

  init(catalog: HelpCatalog) {
    self.catalog = catalog
  }

  /// Nur Leerraum gilt nicht als Suche.
  var isSearching: Bool {
    !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Treffer in der Rangfolge von `HelpSearch`.
  var results: [HelpArticle] {
    HelpSearch.results(for: query, in: catalog).compactMap { catalog.article(for: $0) }
  }

  /// Alle Gruppen in `allCases`-Reihenfolge; Artikel in der Reihenfolge der Themen.
  var sections: [(group: HelpGroup, articles: [HelpArticle])] {
    HelpGroup.allCases.map { group in
      (group, group.topics.compactMap { catalog.article(for: $0) })
    }
  }
}

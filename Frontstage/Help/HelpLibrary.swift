import Foundation
import FrontstageCore
import OSLog

/// Lädt den Hilfekatalog aus der kompilierten String-Tabelle des App-Bündels.
enum HelpLibrary {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "Help")

  /// Einmal geladen; in der App ohne Befund (Test), Befunde gehen in den Log.
  @MainActor static let shared: HelpCatalog = {
    let (catalog, issues) = load(bundle: .main)
    for issue in issues {
      logger.error("Hilfekatalog: \(String(describing: issue), privacy: .public)")
    }
    return catalog
  }()

  /// Liest Texte per `localizedString`; Swift-Hinweis: fehlt ein Schlüssel, liefert Foundation den
  /// Schlüssel selbst zurück – das gilt hier als „Text fehlt“ (`nil`).
  static func load(bundle: Bundle) -> (catalog: HelpCatalog, issues: [HelpCatalogIssue]) {
    HelpCatalog.build { key in
      let value = bundle.localizedString(forKey: key, value: nil, table: nil)
      return value == key ? nil : value
    }
  }
}

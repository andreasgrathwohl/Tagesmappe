import FrontstageCore

/// Was der Zweitbildschirm tatsächlich zeigt: der gewählte Inhalt, durch die Freischaltung gefiltert (FR-13).
enum SecondScreenRendering: Hashable {
  case classScreen, neutral, material, board, dark

  /// Klassenbildschirm und Tafel gehören zum Kauf; ohne Kauf zeigt der Bildschirm eine neutrale Fläche.
  /// Material und „Dunkel“ bleiben frei.
  static func resolve(_ content: SecondScreenContent, isUnlocked: Bool) -> SecondScreenRendering {
    switch content {
    case .classScreen: isUnlocked ? .classScreen : .neutral
    case .board: isUnlocked ? .board : .neutral
    case .material: .material
    case .dark: .dark
    }
  }
}

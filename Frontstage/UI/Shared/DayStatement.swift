import Foundation

/// Die vier Aussagen der Tagesansicht (DESIGN.md) – je eigenes Symbol und eigener Text, nie nur Farbe.
///
/// Die Symbole sind Platzhalter (SF Symbols, Systemstandard) bis zur Design-Runde.
enum DayStatement: CaseIterable {
  /// Lücke im Stundenplan.
  case noLesson
  /// Stunde ohne zugeordnetes Material.
  case lessonWithoutMaterial
  /// Zugeordnetes Material ist nicht verfügbar.
  case materialUnavailable
  /// Stunde fällt aus.
  case cancellation

  /// Name des SF Symbols.
  var symbolName: String {
    switch self {
    case .noLesson: "minus"
    case .lessonWithoutMaterial: "tray"
    case .materialUnavailable: "exclamationmark.triangle"
    case .cancellation: "xmark.circle"
    }
  }

  /// Schlüssel in `Localizable.xcstrings`.
  var labelKey: String {
    switch self {
    case .noLesson: "dayView.statement.noLesson"
    case .lessonWithoutMaterial: "dayView.statement.lessonWithoutMaterial"
    case .materialUnavailable: "dayView.statement.materialUnavailable"
    case .cancellation: "dayView.statement.cancellation"
    }
  }
}

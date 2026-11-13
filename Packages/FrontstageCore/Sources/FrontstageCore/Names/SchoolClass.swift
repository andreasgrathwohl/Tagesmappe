import Foundation

/// Klasse in normalisierter Schreibweise (ADR-0005): „8 b“, „08B“ und „8b“ sind dieselbe Klasse.
public struct SchoolClass: Hashable, Codable, Sendable {
  /// Kleingeschrieben, ohne Leerraum, ohne führende Nullen vor weiteren Ziffern.
  public let normalized: String

  /// Normalisiert die Rohschreibweise.
  public init(_ raw: String) {
    // Leerraum inklusive geschütztem Leerzeichen (U+00A0) entfernen.
    let compact = String(
      raw.lowercased().unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
    // Führende Nullen entfernen, solange danach noch eine Ziffer folgt ("0" bleibt erhalten).
    var chars = Substring(compact)
    while chars.first == "0", let second = chars.dropFirst().first, second.isASCII, second.isNumber {
      chars = chars.dropFirst()
    }
    self.normalized = String(chars)
  }
}

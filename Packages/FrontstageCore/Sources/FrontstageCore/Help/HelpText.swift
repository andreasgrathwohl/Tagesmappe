import Foundation

/// Textfaltung für die Hilfesuche. Eigene Tabelle statt `String.folding`, damit das Ergebnis auf
/// Windows, im Simulator und am Gerät gleich ist.
public enum HelpText {
  /// Kleinschreibung plus Faltung: ä→a, ö→o, ü→u, ß→ss, Akzente weg.
  public static func fold(_ text: String) -> String {
    var result = ""
    for scalar in text.lowercased().unicodeScalars {
      // Kombinierende Akzente (bereits zerlegte Eingabe) fallen weg.
      if (0x0300...0x036F).contains(scalar.value) { continue }
      if let mapped = table[Character(scalar)] {
        result += mapped
      } else {
        result.unicodeScalars.append(scalar)
      }
    }
    return result
  }

  /// Gefaltete Wörter, getrennt an allem außer Buchstaben und Ziffern, ohne leere.
  public static func words(_ text: String) -> [String] {
    fold(text)
      .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
      .map(String.init)
  }

  private static let table: [Character: String] = {
    var map: [Character: String] = ["ß": "ss"]
    let groups: [(String, String)] = [
      ("äàáâãå", "a"), ("öòóôõ", "o"), ("üùúû", "u"), ("èéêë", "e"), ("ìíîï", "i"), ("ç", "c"), ("ñ", "n"),
    ]
    for (chars, base) in groups { for c in chars { map[c] = base } }
    return map
  }()
}

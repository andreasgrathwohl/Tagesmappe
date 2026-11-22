import Foundation

/// Findet im Ordner eines Blatts die passende Lösung über den Dateinamen (FR-6.3).
///
/// Regel: Ein Lösungswort steht als eigenes Wort am Anfang oder Ende des Namens (ohne Endung); der Rest gleicht dem
/// Namen des Blatts. Verglichen wird ohne Groß-/Kleinschreibung und ohne Akzente; Leerzeichen, Bindestrich,
/// Gedankenstrich, Unterstrich, Punkt und Klammern trennen Wörter. Nur PDF und Bild kommen in Frage.
public enum SolutionMatching {
  /// Lösungswörter, schon gefaltet (ohne Akzente, klein).
  private static let solutionWords: Set<String> = [
    "losung", "losungen", "loesung", "loesungen", "lsg", "solution", "solutions", "key",
  ]

  private static let separators = CharacterSet(charactersIn: " -–—_.()")

  /// Dateiname des besten Kandidaten unter `names` (Namen mit Endung, ohne Pfad); `nil` ohne Treffer.
  /// Mehrere Treffer: PDF vor Bild, dann kürzerer Name, dann alphabetisch.
  public static func bestCandidate(forSheetNamed sheet: String, among names: [String]) -> String? {
    let sheetWords = words(of: stem(of: sheet))
    guard !sheetWords.isEmpty else { return nil }
    let sheetFolded = fold(sheet)
    let candidates = names.filter { name in
      let kind = MaterialFileKind(fileExtension: (name as NSString).pathExtension)
      guard kind.opensInViewer, fold(name) != sheetFolded else { return false }
      return remainder(of: words(of: stem(of: name))) == sheetWords
    }
    return candidates.min { lhs, rhs in
      let lhsPDF = isPDF(lhs)
      let rhsPDF = isPDF(rhs)
      if lhsPDF != rhsPDF { return lhsPDF }
      if lhs.count != rhs.count { return lhs.count < rhs.count }
      return lhs.localizedStandardCompare(rhs) == .orderedAscending
    }
  }

  /// Die Wörter ohne ein Lösungswort am Anfang oder Ende; `nil`, wenn keines dort steht.
  private static func remainder(of words: [String]) -> [String]? {
    if let first = words.first, solutionWords.contains(first), words.count > 1 { return Array(words.dropFirst()) }
    if let last = words.last, solutionWords.contains(last), words.count > 1 { return Array(words.dropLast()) }
    return nil
  }

  private static func isPDF(_ name: String) -> Bool {
    MaterialFileKind(fileExtension: (name as NSString).pathExtension) == .pdf
  }

  private static func stem(of name: String) -> String {
    (name as NSString).deletingPathExtension
  }

  private static func fold(_ text: String) -> String {
    text.precomposedStringWithCanonicalMapping
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
  }

  private static func words(of text: String) -> [String] {
    fold(text).components(separatedBy: separators).filter { !$0.isEmpty }
  }
}

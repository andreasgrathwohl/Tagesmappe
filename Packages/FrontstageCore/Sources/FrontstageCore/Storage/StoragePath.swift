import Foundation

/// Eine Ordnerfreigabe mit ihrem Namen und dem aufgelösten Pfad (als normalisierte Bestandteile).
public struct GrantLocation: Hashable, Sendable {
  /// Name der Freigabe, wie er in `MaterialReference.folderGrantName` steht.
  public let name: String
  /// Pfadbestandteile des Freigabe-Ordners, siehe `StoragePath.normalizedComponents(_:)`.
  public let components: [String]

  public init(name: String, components: [String]) {
    self.name = name
    self.components = components
  }
}

/// Ort einer Datei relativ zu einer Freigabe — die geräteunabhängige Form, die gespeichert wird.
public struct RelativeLocation: Hashable, Sendable {
  /// Name der Freigabe, in der die Datei liegt.
  public let folderGrantName: String
  /// Pfad unterhalb der Freigabe, Bestandteile mit `/` getrennt, NFC.
  public let relativePath: String

  public init(folderGrantName: String, relativePath: String) {
    self.folderGrantName = folderGrantName
    self.relativePath = relativePath
  }
}

/// Reine Textarbeit an Dateipfaden: normalisieren, Freigabe zuordnen, Namen abgleichen.
/// Arbeitet nicht auf dem Dateisystem und ist daher auch unter Windows testbar.
public enum StoragePath {
  /// Zerlegt einen Pfad an `/`; leere Teile und `.` entfallen, `..` entfernt den vorigen Teil,
  /// ein führendes `private` vor `var`/`tmp`/`etc` entfällt, jedes Element ist NFC.
  public static func normalizedComponents(_ path: String) -> [String] {
    var result: [String] = []
    for part in path.split(separator: "/", omittingEmptySubsequences: true) {
      switch part {
      case ".": continue
      case "..": if !result.isEmpty { result.removeLast() }
      default: result.append(nfc(String(part)))
      }
    }
    if result.count >= 2, result[0] == "private", ["var", "tmp", "etc"].contains(result[1]) {
      result.removeFirst()
    }
    return result
  }

  /// Ordnet eine Datei der engsten Freigabe zu, deren Pfad ein echtes Präfix ist
  /// (Vergleich je Element NFC und ohne Groß-/Kleinschreibung). `nil`, wenn keine passt
  /// oder die Datei die Freigabe selbst ist.
  public static func relativeLocation(ofFile file: [String], in grants: [GrantLocation]) -> RelativeLocation? {
    var best: GrantLocation?
    for grant in grants where !grant.components.isEmpty && file.count > grant.components.count {
      let isPrefix = zip(grant.components, file).allSatisfy { folded($0) == folded($1) }
      if isPrefix, grant.components.count > (best?.components.count ?? 0) {
        best = grant
      }
    }
    guard let best else { return nil }
    let rest = file.dropFirst(best.components.count).map(nfc)
    return RelativeLocation(folderGrantName: best.name, relativePath: rest.joined(separator: "/"))
  }

  /// Zerlegt einen gespeicherten relativen Pfad in seine Bestandteile.
  public static func components(ofRelativePath path: String) -> [String] {
    path.split(separator: "/", omittingEmptySubsequences: true).map { String($0) }
  }

  /// Sucht `wanted` unter `names` in drei Stufen: exakt (Unicode-Skalare), NFC-gleich, NFC ohne
  /// Groß-/Kleinschreibung. Eine Stufe zählt nur bei genau einem Treffer; sonst folgt die nächste,
  /// am Ende `nil`.
  public static func matchName(_ wanted: String, among names: [String]) -> String? {
    let wantedScalars = Array(wanted.unicodeScalars)
    let exact = names.filter { Array($0.unicodeScalars) == wantedScalars }
    if exact.count == 1 { return exact[0] }
    if !exact.isEmpty { return nil }

    let wantedNFC = nfc(wanted)
    let sameNFC = names.filter { Array(nfc($0).unicodeScalars) == Array(wantedNFC.unicodeScalars) }
    if sameNFC.count == 1 { return sameNFC[0] }
    if !sameNFC.isEmpty { return nil }

    let wantedFolded = folded(wanted)
    let sameFolded = names.filter { folded($0) == wantedFolded }
    return sameFolded.count == 1 ? sameFolded[0] : nil
  }

  private static func nfc(_ text: String) -> String {
    text.precomposedStringWithCanonicalMapping
  }

  /// NFC und kleingeschrieben, verglichen über Unicode-Skalare (Swifts `==` wäre schon kanonisch gleich).
  private static func folded(_ text: String) -> [Unicode.Scalar] {
    Array(nfc(text).lowercased().precomposedStringWithCanonicalMapping.unicodeScalars)
  }
}

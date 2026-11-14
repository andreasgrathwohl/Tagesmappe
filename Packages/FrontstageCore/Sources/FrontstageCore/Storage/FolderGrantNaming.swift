import Foundation

/// Vorschlag für den Namen einer neuen Ordnerfreigabe.
public struct GrantNameSuggestion: Hashable, Sendable {
  /// Vorgeschlagener Freigabe-Name.
  public let name: String
  /// Der Name entspricht einem bereits gespiegelten Namen (Freigabe eines anderen Geräts).
  public let matchesMirroredName: Bool

  public init(name: String, matchesMirroredName: Bool) {
    self.name = name
    self.matchesMirroredName = matchesMirroredName
  }
}

/// Schlägt Freigabe-Namen vor, die lokal eindeutig sind und möglichst zu gespiegelten Namen passen.
public enum FolderGrantNaming {
  /// Nimmt den Ordnernamen; ist er lokal schon vergeben, wird ein Zähler ab 2 angehängt.
  public static func suggestion(
    folderName: String, localGrantNames: Set<String>, mirroredNames: Set<String>
  ) -> GrantNameSuggestion {
    let taken = Set(localGrantNames.map(key))
    var name = folderName
    var counter = 2
    while taken.contains(key(name)) {
      name = "\(folderName) \(counter)"
      counter += 1
    }
    let mirrored = Set(mirroredNames.map(key))
    return GrantNameSuggestion(name: name, matchesMirroredName: mirrored.contains(key(name)))
  }

  private static func key(_ name: String) -> String {
    name.precomposedStringWithCanonicalMapping.lowercased()
  }
}

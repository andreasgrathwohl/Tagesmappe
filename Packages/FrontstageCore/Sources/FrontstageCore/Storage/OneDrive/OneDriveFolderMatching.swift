import Foundation

/// Erkennung, welcher OneDrive-Ordner dem freigegebenen lokalen Ordner entspricht.
public enum OneDriveFolderMatching {
  /// Pfade relativ zur OneDrive-Wurzel, die der freigegebene Ordner sein könnte – längster zuerst.
  public static func candidatePaths(localFolderComponents: [String], maxDepth: Int = 6) -> [String] {
    // Mac: hinter „CloudStorage/OneDrive-…“ beginnt die OneDrive-Wurzel – dann gibt es genau einen Kandidaten.
    if let index = localFolderComponents.firstIndex(of: "CloudStorage"),
      index + 1 < localFolderComponents.count,
      localFolderComponents[index + 1].hasPrefix("OneDrive-")
    {
      let rest = localFolderComponents[(index + 2)...]
      return rest.isEmpty ? [] : [rest.joined(separator: "/")]
    }
    let longest = min(maxDepth, localFolderComponents.count)
    guard longest >= 1 else { return [] }
    return (1...longest).reversed().map { length in
      localFolderComponents.suffix(length).joined(separator: "/")
    }
  }

  /// Alle sichtbaren lokalen Namen (ohne „.“-Präfix) stehen auch online; leer = kein Treffer.
  public static func childrenMatch(local: [String], remote: [String]) -> Bool {
    let visible = local.filter { !$0.hasPrefix(".") }.map(normalized)
    guard !visible.isEmpty else { return false }
    let online = Set(remote.map(normalized))
    return visible.allSatisfy { online.contains($0) }
  }

  /// Graph-Pfad eines Elements: Teil nach `root:` in `parentReference.path` + `/` + Name, NFC, ohne führenden `/`,
  /// unkodiert. Graph liefert `parentReference.path` prozentkodiert (`/drive/root:/Klasse%208b`); die
  /// Elternsegmente werden deshalb dekodiert, `item.name` ist bereits roh. Kodiert wird erst beim Bau einer Adresse.
  public static func rootRelativePath(of item: OneDriveItem) -> String? {
    guard let path = item.parentReference.path, let marker = path.range(of: "root:") else { return nil }
    let parent = path[marker.upperBound...].split(separator: "/", omittingEmptySubsequences: true)
      .map { String($0).removingPercentEncoding ?? String($0) }
    return (parent + [item.name]).joined(separator: "/").precomposedStringWithCanonicalMapping
  }

  private static func normalized(_ name: String) -> String {
    name.precomposedStringWithCanonicalMapping.lowercased()
  }
}

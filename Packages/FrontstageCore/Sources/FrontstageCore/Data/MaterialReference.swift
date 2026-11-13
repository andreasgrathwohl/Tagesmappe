import Foundation

/// Materialverweis gemäß ADR-0003: gespiegelter Name der Ordnerfreigabe plus Pfad darin, ggf. OneDrive-Kennungen.
public struct MaterialReference: Hashable, Codable, Sendable {
  public var folderGrantName: String
  /// NFC, "/"-getrennt, ohne führenden "/".
  public var relativePath: String
  public var displayName: String
  public var fileKind: MaterialFileKind
  public var oneDriveItemID: String?
  public var oneDriveDriveID: String?

  public init(
    folderGrantName: String, relativePath: String, displayName: String, fileKind: MaterialFileKind,
    oneDriveItemID: String? = nil, oneDriveDriveID: String? = nil
  ) {
    self.folderGrantName = folderGrantName
    self.relativePath = relativePath
    self.displayName = displayName
    self.fileKind = fileKind
    self.oneDriveItemID = oneDriveItemID
    self.oneDriveDriveID = oneDriveDriveID
  }

  /// Fachlicher Schlüssel „dieselbe Datei“: `onedrive:<id>`, wenn eine nicht leere OneDrive-Kennung da ist,
  /// sonst `path:<Freigabe>/<Pfad>`.
  public var fileIdentity: String {
    if let id = oneDriveItemID, !id.isEmpty { return "onedrive:\(id)" }
    return "path:\(folderGrantName)/\(relativePath)"
  }

  /// Ort ohne OneDrive-Kennung: Schlüssel für Zustände und für „Neu verknüpfen“.
  public var locationKey: String {
    folderGrantName + "\u{1F}" + relativePath.lowercased()
  }

  /// Endung des Pfads, klein geschrieben (ohne Punkt); leer, wenn es keine gibt.
  public var fileExtension: String {
    let name = relativePath.split(separator: "/").last.map(String.init) ?? relativePath
    guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
    return String(name[name.index(after: dot)...]).lowercased()
  }
}

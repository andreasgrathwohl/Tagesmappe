import Foundation

/// Ausschnitt eines Graph-driveItem aus Delta oder children
/// (`$select=id,name,parentReference,file,folder,deleted,eTag,size,lastModifiedDateTime`).
public struct RemoteItem: Codable, Hashable, Sendable {
  public var id: String
  /// Fehlt bei Löschungen in OneDrive for Business.
  public var name: String?
  public var parentID: String?
  public var isFolder: Bool
  public var isDeleted: Bool
  public var eTag: String?
  public var size: Int?
  public var lastModified: Date?

  public init(
    id: String, name: String?, parentID: String?, isFolder: Bool, isDeleted: Bool,
    eTag: String?, size: Int?, lastModified: Date?
  ) {
    self.id = id
    self.name = name
    self.parentID = parentID
    self.isFolder = isFolder
    self.isDeleted = isDeleted
    self.eTag = eTag
    self.size = size
    self.lastModified = lastModified
  }
}

/// Eine Datei im Datenordner mit ihrem Stand.
public struct RemoteFile: Hashable, Codable, Sendable {
  public var path: String
  public var itemID: String
  public var eTag: String
  public var size: Int
  public var lastModified: Date

  public init(path: String, itemID: String, eTag: String, size: Int, lastModified: Date) {
    self.path = path
    self.itemID = itemID
    self.eTag = eTag
    self.size = size
    self.lastModified = lastModified
  }
}

/// Bild des App-Ordners aus Delta-Seiten; wird mit dem Buch gespeichert.
///
/// Delta liefert Elemente ohne Pfad und Löschungen ohne Namen; die Zuordnung Kennung → Pfad
/// wird deshalb lokal gehalten und erst in `files` berechnet (Reihenfolge innerhalb einer Seite egal).
public struct RemoteIndex: Codable, Equatable, Sendable {
  public var appFolderID: String
  public var deltaLink: String?
  /// Alle bekannten, nicht gelöschten Elemente nach Kennung. Gefiltert wird erst beim Lesen.
  private var items: [String: RemoteItem] = [:]

  public init(appFolderID: String) {
    self.appFolderID = appFolderID
  }

  /// Wendet eine Seite an; ein späteres Vorkommen derselben Kennung gewinnt.
  public mutating func apply(_ pageItems: [RemoteItem]) {
    for item in pageItems {
      if item.isDeleted {
        items[item.id] = nil
      } else {
        items[item.id] = item
      }
    }
  }

  /// Beginn einer Neu-Aufzählung nach 410: Elemente und `deltaLink` verwerfen, `appFolderID` bleibt.
  public mutating func beginResync() {
    items = [:]
    deltaLink = nil
  }

  /// Aktuelle Dateiliste (nur Pfade, die `RemoteLayout.classify` erkennt), sortiert nach Pfad.
  public var files: [RemoteFile] {
    // Ordner direkt unter dem App-Ordner: Kennung → Name.
    var folderNames: [String: String] = [:]
    for item in items.values where item.isFolder && item.parentID == appFolderID {
      if let name = item.name { folderNames[item.id] = name }
    }

    var result: [RemoteFile] = []
    for item in items.values where !item.isFolder {
      guard let name = item.name, let parent = item.parentID else { continue }
      let path: String
      if parent == appFolderID {
        path = name
      } else if let folderName = folderNames[parent] {
        path = "\(folderName)/\(name)"
      } else {
        continue
      }
      guard RemoteLayout.classify(path: path) != nil else { continue }
      result.append(
        RemoteFile(
          path: path, itemID: item.id, eTag: item.eTag ?? "", size: item.size ?? 0,
          lastModified: item.lastModified ?? Date(timeIntervalSince1970: 0)))
    }
    return result.sorted { $0.path < $1.path }
  }

  public func file(at path: String) -> RemoteFile? {
    files.first { $0.path == path }
  }
}

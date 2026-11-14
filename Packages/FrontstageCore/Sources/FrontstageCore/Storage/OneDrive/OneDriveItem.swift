import Foundation

/// Ausschnitt eines Graph-driveItem (`$select=id,name,webUrl,parentReference`).
public struct OneDriveItem: Hashable, Codable, Sendable {
  /// Verweis auf den übergeordneten Ordner samt Laufwerk.
  public struct ParentReference: Hashable, Codable, Sendable {
    public var driveId: String
    public var driveType: String
    public var path: String?

    public init(driveId: String, driveType: String, path: String?) {
      self.driveId = driveId
      self.driveType = driveType
      self.path = path
    }
  }

  public var id: String
  public var name: String
  public var webUrl: String
  public var parentReference: ParentReference

  public init(id: String, name: String, webUrl: String, parentReference: ParentReference) {
    self.id = id
    self.name = name
    self.webUrl = webUrl
    self.parentReference = parentReference
  }
}

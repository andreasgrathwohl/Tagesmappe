import Foundation

/// Inhalt von `library.json`: kennzeichnet einen Datenordner eindeutig (FR-14.1).
public struct LibraryMarker: Codable, Hashable, Sendable {
  public var formatVersion: Int
  public var libraryID: UUID
  public var createdAt: Date

  public init(libraryID: UUID, createdAt: Date) {
    self.formatVersion = RecordEnvelope.currentFormatVersion
    self.libraryID = libraryID
    self.createdAt = createdAt
  }
}

import Foundation

/// Inhalt des Erscheinungsbilds (ein Datensatz je Datenordner, `Theme`).
public struct ThemePayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var baseToneRaw: String
  public var accentHex: String?
  public var appearanceModeRaw: String
  public var updatedAt: Date

  public init(createdAt: Date, baseToneRaw: String, accentHex: String?, appearanceModeRaw: String, updatedAt: Date) {
    self.createdAt = createdAt
    self.baseToneRaw = baseToneRaw
    self.accentHex = accentHex
    self.appearanceModeRaw = appearanceModeRaw
    self.updatedAt = updatedAt
  }
}

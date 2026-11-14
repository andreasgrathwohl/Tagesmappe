import Foundation

/// Inhalt einer Datei `<Modell>/<Kennung>.json`.
public struct RecordEnvelope: Codable, Hashable, Sendable {
  public static let currentFormatVersion = 1

  public var formatVersion: Int
  public var id: UUID
  public var model: SyncModel
  public var updatedAt: Date
  public var deviceID: String
  public var deleted: Bool
  /// `nil` genau dann, wenn `deleted`.
  public var payload: RecordPayload?

  public init(
    id: UUID, model: SyncModel, updatedAt: Date, deviceID: String, deleted: Bool, payload: RecordPayload?
  ) {
    self.formatVersion = Self.currentFormatVersion
    self.id = id
    self.model = model
    self.updatedAt = updatedAt
    self.deviceID = deviceID
    self.deleted = deleted
    self.payload = payload
  }

  /// „Zuletzt geschrieben gilt“: späteres `updatedAt`; bei Gleichstand die größere Geräte-Kennung.
  public func isNewer(than other: (updatedAt: Date, deviceID: String)) -> Bool {
    if updatedAt != other.updatedAt { return updatedAt > other.updatedAt }
    return deviceID > other.deviceID
  }

  private enum CodingKeys: String, CodingKey {
    case formatVersion, id, model, updatedAt, deviceID, deleted, payload
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    formatVersion = try container.decode(Int.self, forKey: .formatVersion)
    id = try container.decode(UUID.self, forKey: .id)
    model = try container.decode(SyncModel.self, forKey: .model)
    updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    deviceID = try container.decode(String.self, forKey: .deviceID)
    deleted = try container.decode(Bool.self, forKey: .deleted)
    if deleted {
      payload = nil
    } else {
      guard container.contains(.payload) else { throw DataFolderCodingError.payloadMissing }
      // Erst das Modell, dann der dazu passende Inhalt.
      payload = try RecordPayload(model: model, from: try container.superDecoder(forKey: .payload))
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(formatVersion, forKey: .formatVersion)
    try container.encode(id, forKey: .id)
    try container.encode(model, forKey: .model)
    try container.encode(updatedAt, forKey: .updatedAt)
    try container.encode(deviceID, forKey: .deviceID)
    try container.encode(deleted, forKey: .deleted)
    if deleted { return }
    guard let payload else { throw DataFolderCodingError.payloadMissing }
    guard payload.model == model else { throw DataFolderCodingError.modelMismatch }
    try container.encode(payload, forKey: .payload)
  }
}

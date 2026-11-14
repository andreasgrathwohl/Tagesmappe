import Foundation

/// Stand eines Datensatzes im lokalen Buch.
public struct LedgerEntry: Codable, Hashable, Sendable {
  public var model: SyncModel
  /// `nil` bei Löschmarke.
  public var payloadHash: String?
  /// Stand, der zuletzt geschrieben oder übernommen wurde.
  public var updatedAt: Date
  public var deviceID: String
  public var deleted: Bool
  /// Lokale Änderung, noch nicht geschrieben.
  public var dirtySince: Date?

  public init(
    model: SyncModel, payloadHash: String?, updatedAt: Date, deviceID: String, deleted: Bool, dirtySince: Date?
  ) {
    self.model = model
    self.payloadHash = payloadHash
    self.updatedAt = updatedAt
    self.deviceID = deviceID
    self.deleted = deleted
    self.dirtySince = dirtySince
  }
}

/// Lokales Buch – je Gerät, nie abgeglichen, nie gesichert.
public struct SyncLedger: Codable, Equatable, Sendable {
  public var deviceID: String
  public var entries: [UUID: LedgerEntry]
  /// Pfad → zuletzt gelesenes oder geschriebenes eTag.
  public var seenETags: [String: String]
  public var remote: RemoteIndex
  public var lastSuccessfulSync: Date?

  public init(deviceID: String, appFolderID: String) {
    self.deviceID = deviceID
    self.entries = [:]
    self.seenETags = [:]
    self.remote = RemoteIndex(appFolderID: appFolderID)
    self.lastSuccessfulSync = nil
  }

  /// Kennungen mit lokaler Änderung, die noch nicht geschrieben ist.
  public var dirtyIDs: Set<UUID> {
    Set(entries.filter { $0.value.dirtySince != nil }.keys)
  }

  /// Nach erfolgreichem Schreiben: Stand der Hülle übernehmen, ausstehend aufheben, eTag merken.
  public mutating func recordWritten(_ envelope: RecordEnvelope, payloadHash: String?, file: RemoteFile) {
    recordApplied(envelope, payloadHash: payloadHash)
    seenETags[file.path] = file.eTag
  }

  /// Nach dem Übernehmen einer fremden Hülle in die lokale Datenbank.
  public mutating func recordApplied(_ envelope: RecordEnvelope, payloadHash: String?) {
    entries[envelope.id] = LedgerEntry(
      model: envelope.model, payloadHash: envelope.deleted ? nil : payloadHash, updatedAt: envelope.updatedAt,
      deviceID: envelope.deviceID, deleted: envelope.deleted, dirtySince: nil)
  }

  /// Eine Datei gelesen, aber nicht übernommen (z. B. unterlegen): eTag merken, damit sie nicht erneut gelesen wird.
  public mutating func recordSeen(_ file: RemoteFile) {
    seenETags[file.path] = file.eTag
  }

  /// Wendet eine Delta-Seite auf das Bild des Datenordners an und vergisst die eTags entfernter Dateien –
  /// sonst ginge das nächste Schreiben mit einem `If-Match` hinaus, das auf keine Datei mehr passt.
  public mutating func applyRemote(_ items: [RemoteItem]) {
    for path in remote.apply(items) { seenETags[path] = nil }
  }

  /// Nach einer vollständigen Aufzählung: eTags von Pfaden vergessen, die es im Datenordner nicht mehr gibt.
  public mutating func pruneSeenETags() {
    let present = remote.filesByPath
    seenETags = seenETags.filter { present[$0.key] != nil }
  }

  /// Eine Kennung ganz vergessen (abgelaufene Löschmarke entfernt): Eintrag und eTag der Datensatzdatei.
  public mutating func forget(_ id: UUID) {
    if let model = entries[id]?.model {
      seenETags[RemoteLayout.recordPath(model: model, id: id)] = nil
    }
    entries[id] = nil
  }
}

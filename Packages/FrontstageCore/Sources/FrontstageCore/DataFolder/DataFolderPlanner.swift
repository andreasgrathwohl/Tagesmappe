import Foundation

/// Lokaler Stand eines Datensatzes: Kennung, Modell und Prüfsumme des kanonischen Inhalts.
public struct LocalRecordState: Hashable, Sendable {
  public var id: UUID
  public var model: SyncModel
  public var payloadHash: String

  public init(id: UUID, model: SyncModel, payloadHash: String) {
    self.id = id
    self.model = model
    self.payloadHash = payloadHash
  }
}

/// Reine Planung des Abgleichs: was lokal neu ist, was geschrieben und was gelesen werden muss.
public enum DataFolderPlanner {
  /// `changed`: geprüfte Datensätze (Prüfsumme ≠ Buch → `dirtySince = now`). `liveIDs`: alle lokalen Kennungen;
  /// im Buch bekannte, nicht gelöschte, die fehlen → Löschmarke ausstehend. `nil` = keine Löschprüfung.
  public static func markLocalChanges(
    changed: [LocalRecordState], liveIDs: Set<UUID>?, ledger: SyncLedger, now: Date
  ) -> SyncLedger {
    var result = ledger
    for state in changed {
      if var entry = result.entries[state.id] {
        // Gleiche Prüfsumme und nicht gelöscht: nichts zu tun.
        if !entry.deleted, entry.payloadHash == state.payloadHash { continue }
        entry.model = state.model
        entry.deleted = false
        entry.dirtySince = entry.dirtySince ?? now  // früheste ungeschriebene Änderung zählt
        result.entries[state.id] = entry
      } else {
        // Neu: Stand „nie geschrieben“, bis `recordWritten` ihn setzt.
        result.entries[state.id] = LedgerEntry(
          model: state.model, payloadHash: nil, updatedAt: .distantPast, deviceID: ledger.deviceID,
          deleted: false, dirtySince: now)
      }
    }
    if let liveIDs {
      for (id, var entry) in result.entries where !entry.deleted && !liveIDs.contains(id) {
        entry.deleted = true
        entry.dirtySince = entry.dirtySince ?? now
        result.entries[id] = entry
      }
    }
    return result
  }

  /// Hüllen für alle ausstehenden Kennungen außer `excluding`; `updatedAt = now`, `deviceID = ledger.deviceID`.
  /// Ausstehend, aber weder gelöscht noch in `payloads` (lokal verschwunden): ausgelassen.
  public static func outgoing(
    ledger: SyncLedger, payloads: [UUID: RecordPayload], excluding: Set<UUID>, now: Date
  ) -> [RecordEnvelope] {
    var result: [RecordEnvelope] = []
    for id in ledger.dirtyIDs.subtracting(excluding) {
      guard let entry = ledger.entries[id] else { continue }
      if entry.deleted {
        result.append(
          RecordEnvelope(
            id: id, model: entry.model, updatedAt: now, deviceID: ledger.deviceID, deleted: true, payload: nil))
      } else if let payload = payloads[id] {
        result.append(
          RecordEnvelope(
            id: id, model: payload.model, updatedAt: now, deviceID: ledger.deviceID, deleted: false,
            payload: payload))
      }
    }
    // Feste Reihenfolge: Eltern vor Kindern, dann nach Kennung.
    return result.sorted {
      let lhs = modelRank($0.model), rhs = modelRank($1.model)
      return lhs != rhs ? lhs < rhs : $0.id.uuidString < $1.id.uuidString
    }
  }

  /// Zu lesen: Datensätze und Konfliktkopien aus `ledger.remote.files`, deren eTag von `seenETags` abweicht oder fehlt;
  /// Reihenfolge `SyncModel.applyOrder`, dann Pfad.
  public static func filesToRead(ledger: SyncLedger) -> [RemoteFile] {
    var ranked: [(rank: Int, file: RemoteFile)] = []
    for file in ledger.remote.files {
      guard let entry = RemoteLayout.classify(path: file.path) else { continue }
      let model: SyncModel
      switch entry {
      case .record(let recordModel, _), .conflictCopy(let recordModel, _): model = recordModel
      default: continue  // library.json und Anhänge liest der Abgleich nicht als Datensatz
      }
      if ledger.seenETags[file.path] == file.eTag { continue }
      ranked.append((modelRank(model), file))
    }
    return ranked.sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.file.path < $1.file.path }.map(\.file)
  }

  /// eTag für If-Match beim Schreiben; `nil` = Datei unbekannt (neu anlegen).
  public static func ifMatch(for path: String, ledger: SyncLedger) -> String? {
    ledger.seenETags[path]
  }

  private static func modelRank(_ model: SyncModel) -> Int {
    SyncModel.applyOrder.firstIndex(of: model) ?? Int.max
  }
}

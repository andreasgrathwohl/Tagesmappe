import Foundation

/// Ergebnis des Lesens und Dekodierens einer Datei.
public enum ReadOutcome: Sendable {
  case decoded(RecordEnvelope)
  /// Kaputt oder Download fehlgeschlagen: der nächste Durchgang liest erneut.
  case unreadable
  /// Aus einer neueren App-Version.
  case newerFormat(Int)
}

public struct ReadFile: Sendable {
  public var file: RemoteFile
  public var outcome: ReadOutcome

  public init(file: RemoteFile, outcome: ReadOutcome) {
    self.file = file
    self.outcome = outcome
  }
}

/// Entscheidung über gelesene Dateien: was übernommen, neu geschrieben, entfernt oder abgewartet wird.
public struct IncomingResolution: Equatable, Sendable {
  /// In `SyncModel.applyOrder`.
  public var apply: [RecordEnvelope] = []
  /// Gewinner aus einer Konfliktkopie → Original neu schreiben.
  public var rewriteCanonical: [RecordEnvelope] = []
  /// Entschiedene Kopien, abgelaufene Löschmarken (samt Anhängen), verwaiste Anhänge.
  public var removeFiles: [RemoteFile] = []
  /// Nicht übernehmen und nicht schreiben; Dateien nicht als gesehen markieren.
  public var waitingIDs: Set<UUID> = []
  public var seenFiles: [RemoteFile] = []
  /// Abgelaufene Löschmarken.
  public var forgetIDs: Set<UUID> = []
  public var newerFormatCount: Int = 0

  public init() {}
}

public enum IncomingResolver {
  /// Löschmarken bleiben 90 Tage (Area daten).
  public static let tombstoneLifetime: TimeInterval = 90 * 24 * 3600
  /// Ein Anhang kann vor seiner JSON-Datei ankommen: 7 Tage Schonfrist (Entscheidung 7).
  public static let orphanAttachmentGrace: TimeInterval = 7 * 24 * 3600

  /// Je Kennung über Original und alle Konfliktkopien.
  public static func resolve(read: [ReadFile], ledger: SyncLedger, now: Date) -> IncomingResolution {
    var result = IncomingResolution()
    let remoteFiles = ledger.remote.files

    // Dateien der Kennungen gruppieren: gelesene Datensätze/Kopien und Anhänge aus dem Bild des Ordners.
    struct Group {
      var model: SyncModel
      var reads: [(read: ReadFile, isCopy: Bool)] = []
      var attachments: [(file: RemoteFile, hash: String)] = []
      var hasRecordFile = false
    }
    var groups: [UUID: Group] = [:]

    for item in read {
      switch RemoteLayout.classify(path: item.file.path) {
      case .record(let model, let id):
        groups[id, default: Group(model: model)].reads.append((item, false))
      case .conflictCopy(let model, let id):
        groups[id, default: Group(model: model)].reads.append((item, true))
      default:
        continue
      }
    }
    for file in remoteFiles {
      switch RemoteLayout.classify(path: file.path) {
      case .record(let model, let id), .conflictCopy(let model, let id):
        groups[id, default: Group(model: model)].hasRecordFile = true
      case .attachment(let model, let id, _, let hash):
        groups[id, default: Group(model: model)].attachments.append((file, hash))
      case .attachmentCopy:
        // 7. Fremde Anhang-Kopien ohne Hash-Schema werden immer entfernt.
        result.removeFiles.append(file)
      default:
        continue
      }
    }

    var removed = Set(result.removeFiles.map(\.path))
    func remove(_ file: RemoteFile) {
      if removed.insert(file.path).inserted { result.removeFiles.append(file) }
    }

    var applyList: [RecordEnvelope] = []
    var rewriteList: [RecordEnvelope] = []

    for (id, group) in groups {
      // Nur Kennungen, deren Dateien in diesem Durchgang gelesen wurden, werden entschieden.
      if group.reads.isEmpty {
        // 7. Anhänge einer Kennung ohne jede Datensatzdatei, die dem Buch unbekannt ist: verwaist nach Schonfrist.
        if !group.hasRecordFile, ledger.entries[id] == nil {
          for attachment in group.attachments where attachment.file.lastModified < now - orphanAttachmentGrace {
            remove(attachment.file)
          }
        }
        continue
      }

      // 1./2. Neueres Format und unlesbare Dateien: Kennung wartet, nichts wird angefasst.
      var waiting = false
      var decoded: [(envelope: RecordEnvelope, file: RemoteFile, isCopy: Bool)] = []
      for (item, isCopy) in group.reads {
        switch item.outcome {
        case .newerFormat:
          result.newerFormatCount += 1
          waiting = true
        case .unreadable:
          waiting = true
        case .decoded(let envelope):
          decoded.append((envelope, item.file, isCopy))
        }
      }
      if waiting {
        result.waitingIDs.insert(id)
        continue
      }

      // 3. Gewinner = neueste Hülle; bei Gleichstand das Original (steht zuerst).
      let ordered = decoded.sorted { !$0.isCopy && $1.isCopy }
      guard var best = ordered.first else { continue }
      for candidate in ordered.dropFirst()
      where candidate.envelope.isNewer(than: (best.envelope.updatedAt, best.envelope.deviceID)) {
        best = candidate
      }
      let winner = best.envelope

      // 3. Fehlt ein Anhang mit genau diesem Hash, wartet die Kennung.
      let availableHashes = Set(group.attachments.map(\.hash))
      let needed = winner.payload?.attachments.values.map(\.hash) ?? []
      if needed.contains(where: { !availableHashes.contains($0) }) {
        result.waitingIDs.insert(id)
        continue
      }

      // 4. Mit dem Buch vergleichen.
      var localWins = false
      var apply = false
      if let entry = ledger.entries[id] {
        if let dirtySince = entry.dirtySince {
          // Ausstehende lokale Änderung: übernehmen nur, wenn der gelesene Stand später entstand.
          apply = winner.updatedAt > dirtySince
          localWins = !apply
        } else {
          apply = winner.isNewer(than: (entry.updatedAt, entry.deviceID))
          // Sauberer Stand, der neuer ist als der Gewinner: das Original nicht mit Älterem überschreiben.
          localWins = !apply && (entry.updatedAt, entry.deviceID) != (winner.updatedAt, winner.deviceID)
        }
      } else {
        apply = true
      }
      if apply { applyList.append(winner) }

      // 5. Gewinner aus einer Konfliktkopie → Original neu schreiben; alle Kopien entfernen.
      if best.isCopy && !localWins { rewriteList.append(winner) }
      for item in ordered where item.isCopy { remove(item.file) }

      // 6. Abgelaufene Löschmarke im Original: Original und alle Anhänge der Kennung entfernen.
      if let original = ordered.first(where: { !$0.isCopy }), original.envelope.deleted,
        !best.isCopy, !localWins, original.envelope.updatedAt < now - tombstoneLifetime
      {
        remove(original.file)
        for attachment in group.attachments { remove(attachment.file) }
        result.forgetIDs.insert(id)
      } else if let original = ordered.first(where: { !$0.isCopy }) {
        result.seenFiles.append(original.file)
      }

      // 7. Verwaiste Anhänge: Hash in keinem bekannten Stand der Kennung und älter als die Schonfrist.
      let knownHashes = Set(decoded.flatMap { $0.envelope.payload?.attachments.values.map(\.hash) ?? [] })
      for attachment in group.attachments
      where !knownHashes.contains(attachment.hash) && attachment.file.lastModified < now - orphanAttachmentGrace {
        remove(attachment.file)
      }
      // 8. Fehlt die Datei einer im Buch bekannten Kennung, kommt sie gar nicht in `groups` vor: nichts passiert.
    }

    let rank: (RecordEnvelope) -> Int = { SyncModel.applyOrder.firstIndex(of: $0.model) ?? Int.max }
    let sorter: (RecordEnvelope, RecordEnvelope) -> Bool = {
      rank($0) != rank($1) ? rank($0) < rank($1) : $0.id.uuidString < $1.id.uuidString
    }
    result.apply = applyList.sorted(by: sorter)
    result.rewriteCanonical = rewriteList.sorted(by: sorter)
    result.removeFiles.sort { $0.path < $1.path }
    result.seenFiles.sort { $0.path < $1.path }
    return result
  }
}

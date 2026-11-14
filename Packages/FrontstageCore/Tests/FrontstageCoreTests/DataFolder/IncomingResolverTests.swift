import Foundation
import Testing
@testable import FrontstageCore

@Suite("DataFolder Incoming")
struct IncomingResolverTests {
  private let now = Date(timeIntervalSince1970: 200 * 24 * 3600)

  private func t(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }

  private func id(_ n: Int) -> UUID {
    let digits = String(n)
    let padded = String(repeating: "0", count: 12 - digits.count) + digits
    return UUID(uuidString: "00000000-0000-0000-0000-\(padded)")!
  }

  private func ledger() -> SyncLedger { SyncLedger(deviceID: "dev-A", appFolderID: "01APPROOT") }

  private func link() -> RecordPayload {
    .materialLink(
      MaterialLinkPayload(
        createdAt: t(1), lessonKeyText: "8b-Mo-1", dayText: "2026-11-16", position: 0,
        folderGrantName: "Material", relativePath: "Blatt.pdf", displayName: "Blatt", fileKindRaw: "pdf",
        oneDriveItemID: nil, oneDriveDriveID: nil))
  }

  private func note(hash: String) -> RecordPayload {
    .penNote(
      PenNotePayload(
        createdAt: t(1), materialLinkID: nil, pageIndex: 0, drawing: AttachmentRef(hash: hash, byteCount: 3),
        pageWidth: 10, pageHeight: 10, updatedAt: t(1)))
  }

  private func envelope(
    _ n: Int, at seconds: Double, device: String = "device-A", deleted: Bool = false,
    model: SyncModel = .materialLink, payload: RecordPayload? = nil
  ) -> RecordEnvelope {
    RecordEnvelope(
      id: id(n), model: model, updatedAt: t(seconds), deviceID: device, deleted: deleted,
      payload: deleted ? nil : (payload ?? link()))
  }

  private func file(_ path: String, modified: Double = 1_000) -> RemoteFile {
    RemoteFile(path: path, itemID: "I-\(path)", eTag: "e", size: 1, lastModified: t(modified))
  }

  private func recordFile(_ n: Int, model: SyncModel = .materialLink) -> RemoteFile {
    file(RemoteLayout.recordPath(model: model, id: id(n)))
  }

  private func copyFile(_ n: Int, model: SyncModel = .materialLink) -> RemoteFile {
    file("\(model.rawValue)/\(id(n).uuidString)-PC-LEHRER.json")
  }

  private func decoded(_ file: RemoteFile, _ envelope: RecordEnvelope) -> ReadFile {
    ReadFile(file: file, outcome: .decoded(envelope))
  }

  /// Bild des Ordners mit den angegebenen Dateien (Anhänge und Datensätze).
  private func ledger(withFiles files: [RemoteFile]) -> SyncLedger {
    var book = ledger()
    var items: [RemoteItem] = [
      RemoteItem(id: "F-link", name: "MaterialLink", parentID: "01APPROOT", isFolder: true, isDeleted: false, eTag: nil, size: nil, lastModified: nil),
      RemoteItem(id: "F-note", name: "PenNote", parentID: "01APPROOT", isFolder: true, isDeleted: false, eTag: nil, size: nil, lastModified: nil),
    ]
    for file in files {
      let parts = file.path.split(separator: "/")
      items.append(
        RemoteItem(
          id: file.itemID, name: String(parts[1]), parentID: parts[0] == "PenNote" ? "F-note" : "F-link",
          isFolder: false, isDeleted: false, eTag: file.eTag, size: file.size, lastModified: file.lastModified))
    }
    book.remote.apply(items)
    return book
  }

  private func setEntry(_ book: inout SyncLedger, _ n: Int, at seconds: Double, device: String = "device-A", dirty: Double? = nil, deleted: Bool = false) {
    book.entries[id(n)] = LedgerEntry(
      model: .materialLink, payloadHash: "h", updatedAt: t(seconds), deviceID: device, deleted: deleted,
      dirtySince: dirty.map(t))
  }

  @Test("Unbekannter Datensatz wird übernommen")
  func unknownRecordIsApplied() {
    let result = IncomingResolver.resolve(
      read: [decoded(recordFile(1), envelope(1, at: 10))], ledger: ledger(), now: now)
    #expect(result.apply.map(\.id) == [id(1)])
    #expect(result.seenFiles.map(\.path) == [recordFile(1).path])
  }

  @Test("Neuerer Stand gewinnt gegen sauberen lokalen Stand")
  func newerRemoteWinsOverClean() {
    var book = ledger()
    setEntry(&book, 1, at: 10)
    let result = IncomingResolver.resolve(read: [decoded(recordFile(1), envelope(1, at: 20))], ledger: book, now: now)
    #expect(result.apply.map(\.updatedAt) == [t(20)])
  }

  @Test("Gleicher Stand wie im Buch → nichts")
  func sameStateIsNoop() {
    var book = ledger()
    setEntry(&book, 1, at: 10)
    let result = IncomingResolver.resolve(read: [decoded(recordFile(1), envelope(1, at: 10))], ledger: book, now: now)
    #expect(result.apply.isEmpty)
    #expect(result.rewriteCanonical.isEmpty)
    #expect(result.waitingIDs.isEmpty)
  }

  @Test("Nebenläufigkeit: lokale Änderung nach dem gelesenen Stand gewinnt")
  func laterLocalChangeWins() {
    var book = ledger()
    setEntry(&book, 1, at: 5, dirty: 30)
    let result = IncomingResolver.resolve(read: [decoded(recordFile(1), envelope(1, at: 20))], ledger: book, now: now)
    #expect(result.apply.isEmpty)
    #expect(result.waitingIDs.isEmpty)
  }

  @Test("Nebenläufigkeit: gelesener Stand nach der lokalen Änderung gewinnt")
  func laterRemoteBeatsPendingLocal() {
    var book = ledger()
    setEntry(&book, 1, at: 5, dirty: 15)
    let result = IncomingResolver.resolve(read: [decoded(recordFile(1), envelope(1, at: 20))], ledger: book, now: now)
    #expect(result.apply.map(\.updatedAt) == [t(20)])
  }

  @Test("Löschmarke wird übernommen")
  func remoteTombstoneIsApplied() {
    var book = ledger()
    setEntry(&book, 1, at: 10)
    let result = IncomingResolver.resolve(
      read: [decoded(recordFile(1), envelope(1, at: 20, deleted: true))], ledger: book, now: now)
    #expect(result.apply.count == 1)
    #expect(result.apply.first?.deleted == true)
  }

  @Test("Neuere Konfliktkopie gewinnt, Original neu, Kopie entfernt")
  func newerConflictCopyWins() {
    let copy = copyFile(1)
    let result = IncomingResolver.resolve(
      read: [
        decoded(recordFile(1), envelope(1, at: 10, device: "device-A")),
        decoded(copy, envelope(1, at: 20, device: "device-B")),
      ],
      ledger: ledger(), now: now)
    #expect(result.apply.map(\.updatedAt) == [t(20)])
    #expect(result.rewriteCanonical.map(\.updatedAt) == [t(20)])
    #expect(result.removeFiles.map(\.path) == [copy.path])
  }

  @Test("Ältere Konfliktkopie wird nur entfernt")
  func olderConflictCopyIsRemoved() {
    var book = ledger()
    setEntry(&book, 1, at: 20)
    let copy = copyFile(1)
    let result = IncomingResolver.resolve(
      read: [
        decoded(recordFile(1), envelope(1, at: 20)),
        decoded(copy, envelope(1, at: 10, device: "device-B")),
      ],
      ledger: book, now: now)
    #expect(result.apply.isEmpty)
    #expect(result.rewriteCanonical.isEmpty)
    #expect(result.removeFiles.map(\.path) == [copy.path])
  }

  @Test("Fehlender Anhang → wartet, Datei nicht gesehen")
  func waitsForMissingAttachment() {
    let result = IncomingResolver.resolve(
      read: [decoded(recordFile(1, model: .penNote), envelope(1, at: 10, model: .penNote, payload: note(hash: "abc")))],
      ledger: ledger(), now: now)
    #expect(result.waitingIDs == [id(1)])
    #expect(result.apply.isEmpty)
    #expect(result.seenFiles.isEmpty)
  }

  @Test("Unlesbare Datei wird erneut gelesen, nicht entfernt")
  func undecodableFileIsRetriedNotDeleted() {
    let result = IncomingResolver.resolve(
      read: [ReadFile(file: recordFile(1), outcome: .unreadable)], ledger: ledger(), now: now)
    #expect(result.waitingIDs == [id(1)])
    #expect(result.removeFiles.isEmpty)
    #expect(result.seenFiles.isEmpty)
  }

  @Test("Fehlende Datei löscht lokal nichts")
  func absentFileNeverDeletesLocal() {
    var book = ledger()
    setEntry(&book, 1, at: 10)
    let result = IncomingResolver.resolve(read: [], ledger: book, now: now)
    #expect(result == IncomingResolution())
  }

  @Test("Datei neuerer Formatversion wird nie überschrieben")
  func newerFormatFileIsNeverOverwritten() {
    var book = ledger()
    setEntry(&book, 1, at: 5, dirty: 30)
    let result = IncomingResolver.resolve(
      read: [ReadFile(file: recordFile(1), outcome: .newerFormat(2))], ledger: book, now: now)
    #expect(result.newerFormatCount == 1)
    #expect(result.waitingIDs == [id(1)])
    #expect(result.removeFiles.isEmpty)
    #expect(result.apply.isEmpty)
    #expect(result.rewriteCanonical.isEmpty)
  }

  @Test("Löschmarke älter als 90 Tage wird mit Anhängen entfernt")
  func expiredTombstoneIsRemoved() {
    let original = recordFile(1, model: .penNote)
    let attachment = file("PenNote/\(id(1).uuidString).drawing.abc.bin")
    let book = ledger(withFiles: [original, attachment])
    let old = now.timeIntervalSince1970 - IncomingResolver.tombstoneLifetime - 10
    let result = IncomingResolver.resolve(
      read: [decoded(original, envelope(1, at: old, deleted: true, model: .penNote))], ledger: book, now: now)
    #expect(Set(result.removeFiles.map(\.path)) == [original.path, attachment.path])
    #expect(result.forgetIDs == [id(1)])
  }

  @Test("Löschmarke jünger als 90 Tage bleibt")
  func freshTombstoneStays() {
    let result = IncomingResolver.resolve(
      read: [decoded(recordFile(1), envelope(1, at: now.timeIntervalSince1970 - 3_600, deleted: true))],
      ledger: ledger(), now: now)
    #expect(result.removeFiles.isEmpty)
    #expect(result.forgetIDs.isEmpty)
  }

  @Test("Verwaister Anhang älter als 7 Tage wird entfernt")
  func oldOrphanAttachmentIsRemoved() {
    let original = recordFile(1, model: .penNote)
    let orphan = file("PenNote/\(id(1).uuidString).drawing.old.bin", modified: now.timeIntervalSince1970 - IncomingResolver.orphanAttachmentGrace - 10)
    let current = file("PenNote/\(id(1).uuidString).drawing.abc.bin", modified: now.timeIntervalSince1970 - IncomingResolver.orphanAttachmentGrace - 10)
    let book = ledger(withFiles: [original, orphan, current])
    let result = IncomingResolver.resolve(
      read: [decoded(original, envelope(1, at: 10, model: .penNote, payload: note(hash: "abc")))], ledger: book, now: now)
    #expect(result.removeFiles.map(\.path) == [orphan.path])
    #expect(result.apply.count == 1)
  }

  @Test("Frischer verwaister Anhang bleibt (kommt vor seiner JSON-Datei an)")
  func freshOrphanAttachmentIsKept() {
    let original = recordFile(1, model: .penNote)
    let fresh = file("PenNote/\(id(1).uuidString).drawing.old.bin", modified: now.timeIntervalSince1970 - 60)
    let current = file("PenNote/\(id(1).uuidString).drawing.abc.bin", modified: now.timeIntervalSince1970 - 60)
    let book = ledger(withFiles: [original, fresh, current])
    let result = IncomingResolver.resolve(
      read: [decoded(original, envelope(1, at: 10, model: .penNote, payload: note(hash: "abc")))], ledger: book, now: now)
    #expect(result.removeFiles.isEmpty)
  }

  @Test("Anhang-Kopie ohne Hash-Schema wird immer entfernt")
  func attachmentCopyIsAlwaysRemoved() {
    let stray = file("PenNote/\(id(1).uuidString)-Kopie.bin", modified: now.timeIntervalSince1970)
    let result = IncomingResolver.resolve(read: [], ledger: ledger(withFiles: [stray]), now: now)
    #expect(result.removeFiles.map(\.path) == [stray.path])
  }

  @Test("Anwenden in Eltern-vor-Kind-Reihenfolge")
  func applyIsOrderedByModel() {
    let attachment = file("PenNote/\(id(2).uuidString).drawing.abc.bin")
    let result = IncomingResolver.resolve(
      read: [
        decoded(recordFile(2, model: .penNote), envelope(2, at: 10, model: .penNote, payload: note(hash: "abc"))),
        decoded(recordFile(1), envelope(1, at: 10)),
      ],
      ledger: ledger(withFiles: [attachment]), now: now)
    #expect(result.apply.map(\.model) == [.materialLink, .penNote])
  }
}

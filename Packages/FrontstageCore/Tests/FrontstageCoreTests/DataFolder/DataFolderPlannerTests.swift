import Foundation
import Testing
@testable import FrontstageCore

@Suite("DataFolder Planner")
struct DataFolderPlannerTests {
  private let now = Date(timeIntervalSince1970: 5_000)

  private func id(_ n: Int) -> UUID {
    let digits = String(n)
    let padded = String(repeating: "0", count: 12 - digits.count) + digits
    return UUID(uuidString: "00000000-0000-0000-0000-\(padded)")!
  }

  private func ledger() -> SyncLedger {
    SyncLedger(deviceID: "dev-A", appFolderID: "01APPROOT")
  }

  private func linkPayload(_ name: String = "Blatt") -> RecordPayload {
    .materialLink(
      MaterialLinkPayload(
        createdAt: Date(timeIntervalSince1970: 1), lessonKeyText: "8b-Mo-1", dayText: "2026-11-16", position: 0,
        folderGrantName: "Material", relativePath: "\(name).pdf", displayName: name, fileKindRaw: "pdf",
        oneDriveItemID: nil, oneDriveDriveID: nil))
  }

  private func written(_ ledger: inout SyncLedger, id: UUID, hash: String?, deleted: Bool = false, eTag: String = "e1") {
    let envelope = RecordEnvelope(
      id: id, model: .materialLink, updatedAt: Date(timeIntervalSince1970: 1_000), deviceID: "dev-A",
      deleted: deleted, payload: deleted ? nil : linkPayload())
    let path = RemoteLayout.recordPath(model: .materialLink, id: id)
    ledger.recordWritten(
      envelope, payloadHash: hash,
      file: RemoteFile(path: path, itemID: "I\(id)", eTag: eTag, size: 1, lastModified: Date(timeIntervalSince1970: 1_000)))
  }

  private func remoteItem(_ itemID: String, _ name: String, parent: String, eTag: String) -> RemoteItem {
    RemoteItem(
      id: itemID, name: name, parentID: parent, isFolder: false, isDeleted: false, eTag: eTag, size: 1,
      lastModified: Date(timeIntervalSince1970: 1_000))
  }

  @Test("Neuer Datensatz wird ausstehend")
  func newRecordBecomesDirty() {
    let result = DataFolderPlanner.markLocalChanges(
      changed: [LocalRecordState(id: id(1), model: .materialLink, payloadHash: "h1")],
      liveIDs: [id(1)], ledger: ledger(), now: now)
    #expect(result.dirtyIDs == [id(1)])
    #expect(result.entries[id(1)]?.dirtySince == now)
    #expect(result.entries[id(1)]?.deleted == false)
  }

  @Test("Unveränderte Prüfsumme bleibt sauber")
  func unchangedHashStaysClean() {
    var book = ledger()
    written(&book, id: id(1), hash: "h1")
    let result = DataFolderPlanner.markLocalChanges(
      changed: [LocalRecordState(id: id(1), model: .materialLink, payloadHash: "h1")],
      liveIDs: [id(1)], ledger: book, now: now)
    #expect(result.dirtyIDs.isEmpty)
  }

  @Test("Geänderte Prüfsumme markiert, früheres dirtySince bleibt")
  func changedHashKeepsEarlierDirtySince() {
    var book = ledger()
    written(&book, id: id(1), hash: "h1")
    let first = DataFolderPlanner.markLocalChanges(
      changed: [LocalRecordState(id: id(1), model: .materialLink, payloadHash: "h2")],
      liveIDs: [id(1)], ledger: book, now: now)
    let second = DataFolderPlanner.markLocalChanges(
      changed: [LocalRecordState(id: id(1), model: .materialLink, payloadHash: "h3")],
      liveIDs: [id(1)], ledger: first, now: now.addingTimeInterval(60))
    #expect(second.entries[id(1)]?.dirtySince == now)
  }

  @Test("Lokal gelöscht → Löschmarke ausstehend")
  func missingLiveIDBecomesTombstone() {
    var book = ledger()
    written(&book, id: id(1), hash: "h1")
    written(&book, id: id(2), hash: "h2")
    let result = DataFolderPlanner.markLocalChanges(changed: [], liveIDs: [id(2)], ledger: book, now: now)
    #expect(result.dirtyIDs == [id(1)])
    #expect(result.entries[id(1)]?.deleted == true)
    #expect(result.entries[id(1)]?.dirtySince == now)
  }

  @Test("liveIDs nil prüft keine Löschungen")
  func nilLiveIDsSkipsDeletion() {
    var book = ledger()
    written(&book, id: id(1), hash: "h1")
    let result = DataFolderPlanner.markLocalChanges(changed: [], liveIDs: nil, ledger: book, now: now)
    #expect(result.dirtyIDs.isEmpty)
  }

  @Test("Bereits geschriebene Löschmarke wird nicht erneut ausstehend")
  func writtenTombstoneStaysClean() {
    var book = ledger()
    written(&book, id: id(1), hash: nil, deleted: true)
    let result = DataFolderPlanner.markLocalChanges(changed: [], liveIDs: [], ledger: book, now: now)
    #expect(result.dirtyIDs.isEmpty)
  }

  @Test("Ausgehend: eigenes Gerät, jetzt, Löschmarke ohne Inhalt; Ausgenommene fehlen")
  func outgoingBuildsEnvelopes() {
    var book = ledger()
    written(&book, id: id(2), hash: "h2")
    book = DataFolderPlanner.markLocalChanges(
      changed: [
        LocalRecordState(id: id(1), model: .materialLink, payloadHash: "h1"),
        LocalRecordState(id: id(3), model: .materialLink, payloadHash: "h3"),
      ],
      liveIDs: [id(1), id(3)], ledger: book, now: now)
    let result = DataFolderPlanner.outgoing(
      ledger: book, payloads: [id(1): linkPayload("a"), id(3): linkPayload("c")], excluding: [id(3)],
      now: now.addingTimeInterval(10))
    #expect(result.map(\.id).sorted { $0.uuidString < $1.uuidString } == [id(1), id(2)])
    let fresh = result.first { $0.id == id(1) }
    #expect(fresh?.deviceID == "dev-A")
    #expect(fresh?.updatedAt == now.addingTimeInterval(10))
    #expect(fresh?.deleted == false)
    #expect(fresh?.payload == linkPayload("a"))
    let tombstone = result.first { $0.id == id(2) }
    #expect(tombstone?.deleted == true)
    #expect(tombstone?.payload == nil)
  }

  @Test("Ausstehend, aber lokal verschwunden und nicht gelöscht → nichts")
  func outgoingSkipsVanished() {
    let book = DataFolderPlanner.markLocalChanges(
      changed: [LocalRecordState(id: id(1), model: .materialLink, payloadHash: "h1")],
      liveIDs: [id(1)], ledger: ledger(), now: now)
    let result = DataFolderPlanner.outgoing(ledger: book, payloads: [:], excluding: [], now: now)
    #expect(result.isEmpty)
  }

  @Test("Nur Dateien mit neuem eTag werden gelesen; Anhänge und library.json nie")
  func filesToReadComparesETags() {
    var book = ledger()
    let a = RemoteLayout.recordPath(model: .materialLink, id: id(1))
    let b = RemoteLayout.recordPath(model: .materialLink, id: id(2))
    let aCopyName = "\(id(1).uuidString) (1).json"
    book.seenETags = [a: "e1"]
    book.remote.apply([
      RemoteItem(id: "F1", name: "MaterialLink", parentID: "01APPROOT", isFolder: true, isDeleted: false, eTag: nil, size: nil, lastModified: nil),
      remoteItem("I1", "\(id(1).uuidString).json", parent: "F1", eTag: "e1"),
      remoteItem("I2", "\(id(2).uuidString).json", parent: "F1", eTag: "e2"),
      remoteItem("I3", aCopyName, parent: "F1", eTag: "e3"),
      remoteItem("I4", "\(id(1).uuidString).drawing.abc.bin", parent: "F1", eTag: "e4"),
      remoteItem("I5", "library.json", parent: "01APPROOT", eTag: "e5"),
    ])
    let result = DataFolderPlanner.filesToRead(ledger: book)
    #expect(result.map(\.path) == ["MaterialLink/\(aCopyName)", b])
    #expect(!result.map(\.path).contains(a))
  }

  @Test("Lesereihenfolge: Eltern vor Kindern")
  func filesToReadFollowsApplyOrder() {
    var book = ledger()
    book.remote.apply([
      RemoteItem(id: "F1", name: "PenNote", parentID: "01APPROOT", isFolder: true, isDeleted: false, eTag: nil, size: nil, lastModified: nil),
      RemoteItem(id: "F2", name: "MaterialLink", parentID: "01APPROOT", isFolder: true, isDeleted: false, eTag: nil, size: nil, lastModified: nil),
      remoteItem("I1", "\(id(1).uuidString).json", parent: "F1", eTag: "e1"),
      remoteItem("I2", "\(id(2).uuidString).json", parent: "F2", eTag: "e2"),
    ])
    #expect(DataFolderPlanner.filesToRead(ledger: book).map(\.path).first?.hasPrefix("MaterialLink/") == true)
  }

  @Test("If-Match nur für bekannte Dateien")
  func ifMatchFromSeenETags() {
    var book = ledger()
    written(&book, id: id(1), hash: "h1", eTag: "e7")
    #expect(DataFolderPlanner.ifMatch(for: RemoteLayout.recordPath(model: .materialLink, id: id(1)), ledger: book) == "e7")
    #expect(DataFolderPlanner.ifMatch(for: RemoteLayout.recordPath(model: .materialLink, id: id(2)), ledger: book) == nil)
  }

  @Test("recordApplied übernimmt den Stand und räumt ausstehend ab")
  func recordAppliedClearsDirty() {
    var book = DataFolderPlanner.markLocalChanges(
      changed: [LocalRecordState(id: id(1), model: .materialLink, payloadHash: "h1")],
      liveIDs: [id(1)], ledger: ledger(), now: now)
    let envelope = RecordEnvelope(
      id: id(1), model: .materialLink, updatedAt: Date(timeIntervalSince1970: 2_000), deviceID: "dev-B",
      deleted: false, payload: linkPayload())
    book.recordApplied(envelope, payloadHash: "h9")
    #expect(book.dirtyIDs.isEmpty)
    #expect(book.entries[id(1)]?.deviceID == "dev-B")
    #expect(book.entries[id(1)]?.payloadHash == "h9")
  }

  private func folderItem(_ itemID: String, _ name: String) -> RemoteItem {
    RemoteItem(
      id: itemID, name: name, parentID: "01APPROOT", isFolder: true, isDeleted: false, eTag: nil, size: nil,
      lastModified: nil)
  }

  private func deletedItem(_ itemID: String) -> RemoteItem {
    RemoteItem(id: itemID, name: nil, parentID: nil, isFolder: false, isDeleted: true, eTag: nil, size: nil, lastModified: nil)
  }

  @Test("Entfernte Datei vergisst ihr gemerktes eTag")
  func applyRemoteDropsSeenETagOfDeletedFile() {
    var book = ledger()
    let a = RemoteLayout.recordPath(model: .materialLink, id: id(1))
    let b = RemoteLayout.recordPath(model: .materialLink, id: id(2))
    book.applyRemote([
      folderItem("F1", "MaterialLink"),
      remoteItem("I1", "\(id(1).uuidString).json", parent: "F1", eTag: "e1"),
      remoteItem("I2", "\(id(2).uuidString).json", parent: "F1", eTag: "e2"),
    ])
    book.seenETags = [a: "e1", b: "e2"]
    book.applyRemote([deletedItem("I1")])
    #expect(book.seenETags == [b: "e2"])
    #expect(DataFolderPlanner.ifMatch(for: a, ledger: book) == nil)
  }

  @Test("Nach vollständiger Aufzählung bleiben nur eTags vorhandener Dateien")
  func pruneSeenETagsKeepsListedPaths() {
    var book = ledger()
    let a = RemoteLayout.recordPath(model: .materialLink, id: id(1))
    let gone = RemoteLayout.recordPath(model: .materialLink, id: id(2))
    book.applyRemote([
      folderItem("F1", "MaterialLink"),
      remoteItem("I1", "\(id(1).uuidString).json", parent: "F1", eTag: "e1"),
    ])
    book.seenETags = [a: "e1", gone: "e9"]
    book.pruneSeenETags()
    #expect(book.seenETags == [a: "e1"])
  }

  @Test("Vergessene Kennung verliert Eintrag und gemerktes eTag")
  func forgetDropsEntryAndSeenETag() {
    var book = ledger()
    written(&book, id: id(1), hash: "h1")
    written(&book, id: id(2), hash: "h2")
    book.forget(id(1))
    #expect(book.entries[id(1)] == nil)
    #expect(book.seenETags[RemoteLayout.recordPath(model: .materialLink, id: id(1))] == nil)
    #expect(book.seenETags[RemoteLayout.recordPath(model: .materialLink, id: id(2))] == "e1")
  }

  @Test("Buch hin und zurück als JSON")
  func ledgerCodableRoundTrip() throws {
    var book = ledger()
    written(&book, id: id(1), hash: "h1")
    book = DataFolderPlanner.markLocalChanges(
      changed: [LocalRecordState(id: id(2), model: .materialLink, payloadHash: "h2")],
      liveIDs: [id(1), id(2)], ledger: book, now: now)
    book.lastSuccessfulSync = now
    let data = try JSONEncoder().encode(book)
    let back = try JSONDecoder().decode(SyncLedger.self, from: data)
    #expect(back == book)
  }
}

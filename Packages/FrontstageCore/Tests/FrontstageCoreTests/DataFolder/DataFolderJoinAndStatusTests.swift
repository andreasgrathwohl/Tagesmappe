import Foundation
import Testing
@testable import FrontstageCore

@Suite("DataFolder Join and Status")
struct DataFolderJoinAndStatusTests {
  private func t(_ seconds: Double) -> Date { Date(timeIntervalSince1970: seconds) }

  private func id(_ n: Int) -> UUID {
    let digits = String(n)
    let padded = String(repeating: "0", count: 12 - digits.count) + digits
    return UUID(uuidString: "00000000-0000-0000-0000-\(padded)")!
  }

  private func state(_ id: UUID, _ model: SyncModel, _ hash: String) -> LocalRecordState {
    LocalRecordState(id: id, model: model, payloadHash: hash)
  }

  private func payload(_ name: String) -> RecordPayload {
    .materialLink(
      MaterialLinkPayload(
        createdAt: t(1), lessonKeyText: "8b-Mo-1", dayText: "2026-11-16", position: 0,
        folderGrantName: "Material", relativePath: "\(name).pdf", displayName: name, fileKindRaw: "pdf",
        oneDriveItemID: nil, oneDriveDriveID: nil))
  }

  @Test("Review Focus 5: beim Beitreten gewinnt der Datenordner, nur lokal Vorhandenes wird geschrieben")
  func joinPrefersFolderForSharedRecords() {
    let ledger = DataFolderJoin.ledger(
      local: [state(id(1), .materialLink, "lokal"), state(id(2), .materialLink, "neu")],
      deviceID: "device-A", appFolderID: "01APPROOT")
    // Im Datenordner liegt id(1) von device-B.
    let path = RemoteLayout.recordPath(model: .materialLink, id: id(1))
    let file = RemoteFile(path: path, itemID: "I1", eTag: "e", size: 1, lastModified: t(5))
    var book = ledger
    book.remote.apply([
      RemoteItem(id: "F-link", name: "MaterialLink", parentID: "01APPROOT", isFolder: true, isDeleted: false, eTag: nil, size: nil, lastModified: nil),
      RemoteItem(id: "I1", name: String(path.split(separator: "/")[1]), parentID: "F-link", isFolder: false, isDeleted: false, eTag: "e", size: 1, lastModified: t(5)),
    ])
    let envelope = RecordEnvelope(
      id: id(1), model: .materialLink, updatedAt: t(5), deviceID: "device-B", deleted: false, payload: payload("fern"))
    let r = IncomingResolver.resolve(
      read: [ReadFile(file: file, outcome: .decoded(envelope))], ledger: book, now: t(100))
    #expect(r.apply.map(\.id) == [id(1)])

    var after = ledger
    for applied in r.apply { after.recordApplied(applied, payloadHash: "fern") }
    let out = DataFolderPlanner.outgoing(
      ledger: after, payloads: [id(2): payload("neu")], excluding: [], now: t(100))
    #expect(out.map(\.id) == [id(2)])
  }

  @Test("Review Focus 1: Statuszeile – Vorrangfolge")
  func summaryPriority() {
    typealias S = DataFolderSyncStatus
    let done = t(50)
    #expect(S(phase: .signInRequired, lastSuccess: done, pendingCount: 1, waitingCount: 1, newerFormatCount: 1).summary == .signInRequired)
    #expect(S(phase: .offline, pendingCount: 3, waitingCount: 2).summary == .offline(pending: 3))
    #expect(S(phase: .failed, lastSuccess: done).summary == .failed(lastSuccess: done))
    #expect(S(phase: .offline, pendingCount: 3).summary == .offline(pending: 3))
    #expect(S(phase: .failed, lastSuccess: done, pendingCount: 3).summary == .failed(lastSuccess: done))
    #expect(S(phase: .syncing, pendingCount: 2, waitingCount: 1).summary == .syncing)
    #expect(S(phase: .idle, lastSuccess: done, pendingCount: 2, waitingCount: 1).summary == .waiting(count: 1))
    #expect(S(phase: .idle, lastSuccess: done, pendingCount: 2).summary == .pending(count: 2))
    #expect(S(phase: .idle, lastSuccess: done).summary == .upToDate(since: done))
  }

  @Test("Neuere App-Version nötig")
  func summaryNeedsNewerApp() {
    #expect(DataFolderSyncStatus(phase: .offline, newerFormatCount: 1).summary == .needsNewerApp)
    #expect(DataFolderSyncStatus(phase: .idle, lastSuccess: t(1), newerFormatCount: 2).summary == .needsNewerApp)
  }

  @Test("Ohne je erfolgreichen Durchgang: noch nicht abgeglichen")
  func summaryNeverSynced() {
    #expect(DataFolderSyncStatus().summary == .neverSynced)
  }
}

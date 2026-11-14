import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

/// Steuerbare Uhr, von beiden Testgeräten geteilt.
@MainActor private final class TestClock {
  var date = Date(timeIntervalSince1970: 1_800_000_000)
  func advance(_ seconds: TimeInterval = 10) { date = date.addingTimeInterval(seconds) }
}

/// Ein Testgerät: eigener In-Memory-Speicher, eigenes Buch, eigene Geräte-Kennung.
@MainActor private struct Device {
  let store: DataStore
  let sync: DataFolderSync
  let ledger: LedgerStore
}

@MainActor private func makeDevice(_ name: String, remote: any RemoteDataFolder, clock: TestClock) throws
  -> Device
{
  let store = try makeStore()
  let fileURL = FileManager.default.temporaryDirectory.appending(path: "ledger-\(UUID().uuidString).json")
  let ledger = LedgerStore(fileURL: fileURL)
  ledger.ledger = SyncLedger(deviceID: name, appFolderID: InMemoryRemoteDataFolder.appFolderID)
  let sync = DataFolderSync(
    store: store, remote: remote, ledger: ledger, now: { clock.date },
    saveDebounce: .milliseconds(20), pollInterval: .seconds(3600))
  return Device(store: store, sync: sync, ledger: ledger)
}

/// Reicht alles an den gemeinsamen Datenordner weiter und führt vor dem ersten Hochladen eine Aktion aus –
/// so entsteht ein Wettlauf, den ein einzelnes Gerät nicht herstellen kann.
private actor HookedRemote: RemoteDataFolder {
  private let inner: InMemoryRemoteDataFolder
  private var beforeUpload: (@Sendable () async -> Void)?

  init(_ inner: InMemoryRemoteDataFolder) { self.inner = inner }

  func runBeforeNextUpload(_ action: @escaping @Sendable () async -> Void) { beforeUpload = action }

  func appFolder() async throws -> AppFolderInfo { try await inner.appFolder() }
  func delta(link: String?) async throws -> DeltaPage { try await inner.delta(link: link) }
  func listAll() async throws -> [RemoteItem] { try await inner.listAll() }
  func download(itemID: String) async throws -> Data { try await inner.download(itemID: itemID) }
  func upload(_ data: Data, to path: String, ifMatch: String?) async throws -> RemoteFile {
    if let action = beforeUpload {
      beforeUpload = nil
      await action()
    }
    return try await inner.upload(data, to: path, ifMatch: ifMatch)
  }
  func delete(_ file: RemoteFile) async throws { try await inner.delete(file) }
  func ensureModelFolders() async throws { try await inner.ensureModelFolders() }
}

@MainActor @Suite struct DataFolderSyncTests {
  let remote = InMemoryRemoteDataFolder()
  private let clock = TestClock()
  let di8b = LessonKey(date: tue17, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)

  private func device(_ name: String) throws -> Device {
    try makeDevice(name, remote: remote, clock: clock)
  }

  /// Wartet, bis die Bedingung gilt (höchstens `timeout`).
  private func waitUntil(timeout: Duration = .seconds(5), _ condition: () async -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if await condition() { return true }
      try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
  }

  private func syncBoth(_ first: Device, _ second: Device) async {
    clock.advance()
    await first.sync.runCycle()
    clock.advance()
    await second.sync.runCycle()
  }

  @Test("AK-43 (Daten): Zuordnung am Mac erscheint nach einem Durchgang am iPad")
  func linkTravelsBetweenDevices() async throws {
    let mac = try device("mac"), ipad = try device("ipad")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    await syncBoth(mac, ipad)
    #expect(try ipad.store.links(for: di8b).map(\.displayName) == ["Vokabeln.pdf"])
    #expect(mac.sync.status.phase == .idle)
    #expect(mac.sync.status.pendingCount == 0)
  }

  @Test("AK-43 (Daten): Stiftnotiz (Ersatz im Datenort) samt Zeichnung kommt an")
  func penNoteWithDrawingTravels() async throws {
    let mac = try device("mac"), ipad = try device("ipad")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    let link = try #require(try mac.store.links(for: di8b).first)
    try mac.store.savePenNote(
      for: link, pageIndex: 0, drawingData: Data([1, 2, 3]), pageWidth: 595, pageHeight: 842)
    await syncBoth(mac, ipad)
    let ipadLink = try #require(try ipad.store.link(id: link.id))
    let note = try #require(try ipad.store.penNote(for: ipadLink, pageIndex: 0))
    #expect(note.drawingData == Data([1, 2, 3]))
  }

  @Test("Löschen erreicht das andere Gerät als Löschmarke")
  func deletionTravelsAsTombstone() async throws {
    let mac = try device("mac"), ipad = try device("ipad")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    let link = try #require(try mac.store.links(for: di8b).first)
    let id = link.id
    await syncBoth(mac, ipad)
    #expect(try ipad.store.links(for: di8b).count == 1)

    try mac.store.removeLink(link)
    await syncBoth(mac, ipad)
    #expect(try ipad.store.links(for: di8b).isEmpty)
    let stored = try #require(await remote.content(at: RemoteLayout.recordPath(model: .materialLink, id: id)))
    #expect(try DataFolderCoding.decode(stored).deleted)
  }

  @Test("Übernommene Stände werden nicht zurückgeschrieben")
  func appliedStateIsNotEchoed() async throws {
    let mac = try device("mac"), ipad = try device("ipad")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    clock.advance()
    await mac.sync.runCycle()
    let uploadsAfterMac = await remote.uploadCount
    clock.advance()
    await ipad.sync.runCycle()
    clock.advance()
    await ipad.sync.runCycle()
    #expect(await remote.uploadCount == uploadsAfterMac)
    #expect(ipad.sync.status.pendingCount == 0)
  }

  @Test("Speichern löst nach der Entprellzeit das Schreiben aus")
  func saveTriggersWrite() async throws {
    let mac = try device("mac")
    mac.sync.start()
    defer { mac.sync.stop() }
    let started = await waitUntil { mac.sync.cycleCount >= 1 && mac.sync.status.phase == .idle }
    #expect(started)

    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    let written = await waitUntil { await remote.paths.contains { $0.hasPrefix("MaterialLink/") } }
    #expect(written)
  }

  @Test("Doppelter Ausfall von zwei Geräten wird nach dem Abgleich eins")
  func duplicatesMergeAfterSync() async throws {
    let mac = try device("mac"), ipad = try device("ipad")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    try ipad.store.assign(reference("Vokabeln.pdf"), to: di8b)
    await syncBoth(mac, ipad)
    await syncBoth(mac, ipad)
    #expect(try mac.store.links(for: di8b).count == 1)
    #expect(try ipad.store.links(for: di8b).count == 1)
  }

  @Test("Review Focus 1: Anmeldung nötig → Änderungen bleiben ausstehend, nach Anmeldung geschrieben")
  func signInRequiredKeepsChangesPending() async throws {
    let mac = try device("mac"), ipad = try device("ipad")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    await remote.failNextCalls(with: .signInRequired)
    clock.advance()
    await mac.sync.runCycle()
    #expect(mac.sync.status.phase == .signInRequired)
    #expect(mac.sync.status.pendingCount > 0)
    #expect(await remote.paths.isEmpty)

    await syncBoth(mac, ipad)
    #expect(mac.sync.status.phase == .idle)
    #expect(try ipad.store.links(for: di8b).count == 1)
  }

  @Test("Review Focus 1: offline → Status offline, nichts verloren")
  func offlineKeepsChangesPending() async throws {
    let mac = try device("mac"), ipad = try device("ipad")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    await remote.failNextCalls(with: .offline)
    clock.advance()
    await mac.sync.runCycle()
    #expect(mac.sync.status.phase == .offline)
    #expect(mac.sync.status.pendingCount > 0)

    await syncBoth(mac, ipad)
    #expect(try ipad.store.links(for: di8b).count == 1)
  }

  @Test("Review Focus 2: 412 → kein Überschreiben, nächster Durchgang entscheidet nach Zeitpunkt")
  func preconditionFailedRereadsInsteadOfOverwriting() async throws {
    let mac = try device("mac")
    let hooked = HookedRemote(remote)
    let ipad = try makeDevice("ipad", remote: hooked, clock: clock)

    try mac.store.setLessonInfo(LessonInfo(topic: "alt"), for: di8b)
    await syncBoth(mac, ipad)
    #expect(try ipad.store.lessonInfo(for: di8b).topic == "alt")

    // iPad und Mac ändern je für sich; der Mac schreibt, nachdem das iPad seinen Stand gelesen hat.
    clock.advance()
    try ipad.store.setLessonInfo(LessonInfo(topic: "iPad"), for: di8b)
    try mac.store.setLessonInfo(LessonInfo(topic: "Mac"), for: di8b)
    let macClock = clock
    await hooked.runBeforeNextUpload {
      await MainActor.run {
        macClock.advance()
      }
      await mac.sync.runCycle()
    }
    clock.advance()
    await ipad.sync.runCycle()

    // Der spätere Stand (Mac) gewinnt am iPad; das iPad hat ihn nicht überschrieben.
    #expect(try ipad.store.lessonInfo(for: di8b).topic == "Mac")
    let path = RemoteLayout.recordPath(model: .lessonInfo, id: try #require(try lessonInfoID(mac)))
    let stored = try #require(await remote.content(at: path))
    #expect(try DataFolderCoding.decode(stored).deviceID == "mac")
  }

  private func lessonInfoID(_ device: Device) throws -> UUID? {
    try device.store.modelContext.fetch(FetchDescriptor<LessonInfoRecord>()).first?.id
  }

  @Test("Review Focus 3: nach 410 wird nichts doppelt gelesen und nichts gelöscht")
  func resyncAfterGoneReadsNothingTwice() async throws {
    let mac = try device("mac"), ipad = try device("ipad")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    await syncBoth(mac, ipad)
    let downloads = await remote.downloadCount
    let paths = await remote.paths

    await remote.expireDeltaLinks()
    clock.advance()
    await ipad.sync.runCycle()
    #expect(await remote.downloadCount == downloads)
    #expect(await remote.paths == paths)
    #expect(try ipad.store.links(for: di8b).count == 1)
    #expect(ipad.sync.status.phase == .idle)
  }

  @Test("Ohne Delta (Q-33): Auflisten liefert dasselbe Ergebnis")
  func listFallbackSyncs() async throws {
    let mac = try device("mac"), ipad = try device("ipad")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    clock.advance()
    await mac.sync.runCycle()
    await remote.failNextCalls(with: .server(501))
    clock.advance()
    await ipad.sync.runCycle()
    #expect(try ipad.store.links(for: di8b).map(\.displayName) == ["Vokabeln.pdf"])
    #expect(ipad.sync.status.phase == .idle)
  }

  @Test("Zweiter gleichzeitiger Aufruf läuft danach, nicht parallel")
  func cyclesDoNotOverlap() async throws {
    let mac = try device("mac")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    async let first: Void = mac.sync.runCycle()
    async let second: Void = mac.sync.runCycle()
    _ = await (first, second)
    #expect(mac.sync.cycleCount == 2)
    #expect(mac.sync.status.phase == .idle)
  }

  @Test("revision steigt nach übernommenen Änderungen")
  func revisionBumpsOnApply() async throws {
    let mac = try device("mac"), ipad = try device("ipad")
    try mac.store.assign(reference("Vokabeln.pdf"), to: di8b)
    clock.advance()
    await mac.sync.runCycle()
    let before = ipad.store.revision
    clock.advance()
    await ipad.sync.runCycle()
    #expect(ipad.store.revision > before)
  }
}

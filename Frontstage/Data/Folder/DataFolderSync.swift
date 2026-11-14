import Foundation
import FrontstageCore
import Observation
import OSLog
import SwiftData

/// Die Kennungen aus einer `ModelContext.didSave`-Mitteilung.
private struct SavedIdentifiers: Sendable {
  var changed: [PersistentIdentifier] = []
  var deleted: [PersistentIdentifier] = []

  init(_ notification: Notification) {
    changed =
      Self.identifiers(notification, .insertedIdentifiers) + Self.identifiers(notification, .updatedIdentifiers)
    deleted = Self.identifiers(notification, .deletedIdentifiers)
  }

  /// Swift-Hinweis: Die Schlüssel des `userInfo` sind die Rohwerte (`String`) der `NotificationKey`-Werte.
  private static func identifiers(_ notification: Notification, _ key: ModelContext.NotificationKey)
    -> [PersistentIdentifier]
  {
    let info = notification.userInfo
    return (info?[key.rawValue] as? [PersistentIdentifier]) ?? []
  }
}

/// Gleicht die lokale Datenbank mit dem Datenordner in OneDrive ab (ADR-0012, Teilplan 08).
///
/// Ein Durchgang (`runCycle()`): lesen → anwenden → zusammenführen → schreiben. Nie zwei Durchgänge
/// gleichzeitig. Fehler werden protokolliert und im `status` gemeldet, nie als Dialog gezeigt; das Buch
/// bleibt in jedem Fall gültig gespeichert, ausstehende Änderungen gehen nie verloren.
///
/// Swift-Hinweis: Die Klasse läuft auf dem Hauptakteur. Zwischen zwei `await`-Punkten kann nichts anderes
/// auf dem Hauptakteur dazwischenfunken; deshalb sind „Datenbank ändern und Buch fortschreiben“
/// (Schritte 4–5) ein unteilbarer Schritt, solange kein `await` dazwischen steht.
@MainActor @Observable final class DataFolderSync {
  private(set) var status = DataFolderSyncStatus()
  /// Anzahl begonnener Durchgänge (für Tests: zwei gleichzeitige Aufrufe laufen nacheinander).
  private(set) var cycleCount = 0

  @ObservationIgnored private let store: DataStore
  @ObservationIgnored private let remote: any RemoteDataFolder
  @ObservationIgnored private let ledgerStore: LedgerStore
  @ObservationIgnored private let now: @MainActor () -> Date
  @ObservationIgnored private let saveDebounce: Duration
  @ObservationIgnored private let pollInterval: Duration

  @ObservationIgnored private var observer: NSObjectProtocol?
  @ObservationIgnored private var pollTask: Task<Void, Never>?
  @ObservationIgnored private var debounceTask: Task<Void, Never>?

  @ObservationIgnored private var isRunning = false
  @ObservationIgnored private var rerunRequested = false

  /// Ein erster Durchgang prüft alles; danach genügen die im `didSave` gesammelten Kennungen.
  @ObservationIgnored private var didInitialScan = false
  @ObservationIgnored private var changedIDs: Set<PersistentIdentifier> = []
  @ObservationIgnored private var localChangeSeen = false
  /// Zuletzt ausgelesene Datensätze mit lokaler Änderung (samt Anhängen), bis sie geschrieben sind.
  @ObservationIgnored private var exportCache: [UUID: ExportedRecord] = [:]

  /// Q-33: Der Server kennt Delta nicht (HTTP 400/501); gilt bis zum nächsten Start der App.
  @ObservationIgnored private var deltaUnsupported = false
  @ObservationIgnored private var lastWaitingCount = 0
  @ObservationIgnored private var lastNewerFormatCount = 0

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "DataFolderSync")

  init(
    store: DataStore, remote: any RemoteDataFolder, ledger: LedgerStore,
    now: @escaping @MainActor () -> Date = { .now },
    saveDebounce: Duration = .seconds(1), pollInterval: Duration = .seconds(60)
  ) {
    self.store = store
    self.remote = remote
    self.ledgerStore = ledger
    self.now = now
    self.saveDebounce = saveDebounce
    self.pollInterval = pollInterval
  }

  // MARK: - Auslöser

  /// `didSave` beobachten, Abfrage alle `pollInterval` starten, einmal `runCycle()`.
  ///
  /// Swift-Hinweis: Der Beobachter-Block ist nicht als `@MainActor` markiert, läuft mit `queue: .main` aber
  /// auf der Hauptwarteschlange; `MainActor.assumeIsolated` sagt das dem Compiler zu (wie `SyncMergeTrigger`).
  func start() {
    if observer == nil {
      observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: store.modelContext, queue: .main
      ) { [weak self] notification in
        let saved = SavedIdentifiers(notification)
        MainActor.assumeIsolated { self?.contextDidSave(saved) }
      }
    }
    startPolling()
    Task { await runCycle() }
  }

  /// Beobachter und Abfrage beenden.
  func stop() {
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
    pollTask?.cancel()
    pollTask = nil
    debounceTask?.cancel()
    debounceTask = nil
  }

  func sceneDidBecomeActive() {
    startPolling()
    Task { await runCycle() }
  }

  /// Abfrage aus; ausstehende Änderungen sofort schreiben (Schritte 8–10).
  func sceneDidEnterBackground() {
    pollTask?.cancel()
    pollTask = nil
    debounceTask?.cancel()
    debounceTask = nil
    Task { await runSerialized(writeOnly: true) }
  }

  func networkDidBecomeAvailable() {
    Task { await runCycle() }
  }

  private func startPolling() {
    pollTask?.cancel()
    pollTask = Task { [pollInterval] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: pollInterval) } catch { return }
        await runCycle()
      }
    }
  }

  /// Sammelt Kennungen und startet die Entprellzeit neu; danach werden die Schritte 7–10 ausgeführt.
  private func contextDidSave(_ saved: SavedIdentifiers) {
    changedIDs.formUnion(saved.changed)
    // Gelöschte Datensätze nicht mehr exportieren; ihre Löschmarke ergibt sich aus der Prüfung der lebenden Kennungen.
    changedIDs.subtract(saved.deleted)
    localChangeSeen = true
    debounceTask?.cancel()
    debounceTask = Task { [saveDebounce] in
      do { try await Task.sleep(for: saveDebounce) } catch { return }
      await runSerialized(writeOnly: true)
    }
  }

  // MARK: - Durchgang

  /// Lesen → anwenden → zusammenführen → schreiben. Nie doppelt: Ein Aufruf während eines laufenden
  /// Durchgangs merkt sich „noch einmal“ und kehrt sofort zurück.
  func runCycle() async {
    await runSerialized(writeOnly: false)
  }

  private func runSerialized(writeOnly: Bool) async {
    if isRunning {
      rerunRequested = true
      return
    }
    isRunning = true
    defer { isRunning = false }

    var writeOnly = writeOnly
    var directRerunUsed = false
    while true {
      rerunRequested = false
      let conflict = await execute(writeOnly: writeOnly)
      // Nach einem 412 höchstens einmal direkt hintereinander noch einmal (Schritt 8).
      if conflict && !directRerunUsed {
        directRerunUsed = true
        writeOnly = false
        continue
      }
      if rerunRequested {
        writeOnly = false
        continue
      }
      return
    }
  }

  /// Ein Durchgang; `true`, wenn ein Schreiben an `preconditionFailed` scheiterte.
  /// `writeOnly`: nur die Schritte 7–10 (nach einem Speichern, beim Wechsel in den Hintergrund).
  private func execute(writeOnly: Bool) async -> Bool {
    cycleCount += 1
    status.phase = .syncing
    let cycleNow = now()

    var ledger: SyncLedger
    do {
      ledger = try await currentLedger()
    } catch {
      fail(with: error, pending: status.pendingCount)
      return false
    }

    var conflict = false
    var resolution = IncomingResolution()
    var waiting = Set<UUID>()
    var forceFullScan = false
    do {
      if !writeOnly {
        // 1. Delta abholen (bzw. auflisten).
        try await fetchRemoteIndex(&ledger)
        // 2./3. Lesen und entscheiden.
        let read = try await readChangedFiles(ledger)
        resolution = IncomingResolver.resolve(read: read, ledger: ledger, now: cycleNow)
        // 4./5. Anwenden und Buch fortschreiben, ohne `await` dazwischen.
        let extraWaiting = try await applyIncoming(resolution, ledger: &ledger)
        waiting = resolution.waitingIDs.union(extraWaiting)
        resolution.removeFiles.removeAll { file in
          if case .record(_, let id)? = RemoteLayout.classify(path: file.path) { return extraWaiting.contains(id) }
          if case .conflictCopy(_, let id)? = RemoteLayout.classify(path: file.path) { return extraWaiting.contains(id) }
          return false
        }
        resolution.rewriteCanonical.removeAll { extraWaiting.contains($0.id) }
        ledgerStore.ledger = ledger
        lastWaitingCount = waiting.count
        lastNewerFormatCount = resolution.newerFormatCount
        // 6. Doppelte zusammenführen.
        let plan = try store.mergeDuplicates()
        // Nach eigenen Änderungen durch Anwenden oder Zusammenführen ist die Menge der gesammelten Kennungen
        // womöglich veraltet (gelöschte Datensätze): dann wird alles geprüft.
        forceFullScan = !resolution.apply.isEmpty || !plan.isEmpty
      }
      // 7. Lokale Änderungen erfassen.
      try captureLocalChanges(&ledger, now: cycleNow, forceFull: forceFullScan)
      // 8. Schreiben.
      conflict = try await writeOutgoing(&ledger, resolution: resolution, waiting: waiting, now: cycleNow)
      // 9. Entschiedene Dateien entfernen.
      for file in resolution.removeFiles {
        do {
          try await remote.delete(file)
        } catch RemoteDataFolderError.preconditionFailed {
          continue  // zwischenzeitlich geändert: der nächste Durchgang entscheidet neu
        }
      }
      // 10. Erfolg.
      ledger.lastSuccessfulSync = now()
      ledgerStore.ledger = ledger
      status = DataFolderSyncStatus(
        phase: .idle, lastSuccess: ledger.lastSuccessfulSync, pendingCount: ledger.dirtyIDs.count,
        waitingCount: lastWaitingCount, newerFormatCount: lastNewerFormatCount)
      return conflict
    } catch {
      // Lokale Änderungen trotzdem erfassen, damit sie ausstehend vermerkt sind und nichts verloren geht.
      try? captureLocalChanges(&ledger, now: cycleNow)
      ledgerStore.ledger = ledger
      fail(with: error, pending: ledger.dirtyIDs.count)
      return false
    }
  }

  /// 10. Fehler protokollieren (nie Token oder Inhalte) und als Status melden.
  private func fail(with error: Error, pending: Int) {
    let phase: DataFolderSyncStatus.Phase
    switch error as? RemoteDataFolderError {
    case .offline?: phase = .offline
    case .signInRequired?: phase = .signInRequired
    default: phase = .failed
    }
    Self.logger.error("Abgleich fehlgeschlagen: \(String(describing: error), privacy: .public)")
    status.phase = phase
    status.pendingCount = pending
  }

  /// Das Buch dieses Geräts; beim ersten Mal wird es angelegt.
  private func currentLedger() async throws -> SyncLedger {
    if let existing = ledgerStore.ledger { return existing }
    let folder = try await remote.appFolder()
    let created = SyncLedger(deviceID: DeviceIdentity.current(), appFolderID: folder.folderItemID)
    ledgerStore.ledger = created
    return created
  }

  /// Fehler, die den ganzen Durchgang betreffen (nicht eine einzelne Datei).
  private static func isInfrastructure(_ error: RemoteDataFolderError) -> Bool {
    switch error {
    case .offline, .signInRequired, .throttled: true
    default: false
    }
  }

  // MARK: - 1. Delta

  private func fetchRemoteIndex(_ ledger: inout SyncLedger) async throws {
    if deltaUnsupported {
      try await listAllFallback(&ledger)
      return
    }
    var link = ledger.remote.deltaLink
    // Ohne Delta-Link beginnt eine frische Aufzählung: nichts Altes darf im Bild stehen bleiben.
    if link == nil { ledger.remote.beginResync() }
    var firstCall = true
    var restarted = false
    while true {
      do {
        let page = try await remote.delta(link: link)
        ledger.remote.apply(page.items)
        if let next = page.nextLink {
          link = next
          firstCall = false
          continue
        }
        ledger.remote.deltaLink = page.deltaLink
        return
      } catch RemoteDataFolderError.resyncRequired {
        // 410: von vorn. Die gemerkten eTags bleiben, es wird also nichts doppelt gelesen.
        guard !restarted else { throw RemoteDataFolderError.resyncRequired }
        restarted = true
        ledger.remote.beginResync()
        link = nil
        firstCall = true
      } catch RemoteDataFolderError.server(let code) where firstCall && (code == 400 || code == 501) {
        deltaUnsupported = true
        Self.logger.notice("Delta wird nicht unterstützt (\(code)); es wird aufgelistet")
        try await listAllFallback(&ledger)
        return
      }
    }
  }

  private func listAllFallback(_ ledger: inout SyncLedger) async throws {
    let items = try await remote.listAll()
    ledger.remote.beginResync()
    ledger.remote.apply(items)
  }

  // MARK: - 2. Lesen

  private func readChangedFiles(_ ledger: SyncLedger) async throws -> [ReadFile] {
    var result: [ReadFile] = []
    for file in DataFolderPlanner.filesToRead(ledger: ledger) {
      var outcome: ReadOutcome = .unreadable
      do {
        let data = try await remote.download(itemID: file.itemID)
        do {
          let envelope = try DataFolderCoding.decode(data)
          // Kennung und Modell der Hülle müssen zum Pfad passen, sonst gilt die Datei als kaputt.
          switch RemoteLayout.classify(path: file.path) {
          case .record(let model, let id)?, .conflictCopy(let model, let id)?:
            if envelope.id == id && envelope.model == model { outcome = .decoded(envelope) }
          default: break
          }
        } catch DataFolderCodingError.unsupportedFormatVersion(let version) {
          outcome = .newerFormat(version)
        } catch {
          outcome = .unreadable
        }
      } catch let error as RemoteDataFolderError where Self.isInfrastructure(error) {
        throw error
      } catch {
        outcome = .unreadable  // z. B. 404: der nächste Durchgang liest erneut
      }
      result.append(ReadFile(file: file, outcome: outcome))
    }
    return result
  }

  // MARK: - 4./5. Anwenden

  /// Lädt erst die Anhänge, wendet dann alle Hüllen in einem Speichern an und schreibt das Buch fort.
  /// Gibt die Kennungen zurück, die zusätzlich warten müssen (Anhang fehlt, Elterndatensatz fehlt).
  private func applyIncoming(_ resolution: IncomingResolution, ledger: inout SyncLedger) async throws
    -> Set<UUID>
  {
    var extraWaiting = Set<UUID>()
    var prepared: [(envelope: RecordEnvelope, attachments: [String: Data], hash: String?)] = []

    // 4. Anhänge zuerst: Die Closure von `applyExternalChanges` ist synchron, ein `await` darin geht nicht.
    for envelope in resolution.apply {
      guard let attachments = try await downloadAttachments(of: envelope, ledger: ledger) else {
        extraWaiting.insert(envelope.id)
        continue
      }
      let hash = try envelope.payload.map { try DataFolderCoding.payloadHash($0) }
      prepared.append((envelope, attachments, hash))
    }

    // Ab hier kein `await` mehr bis zum Fortschreiben des Buchs (Schritt 5).
    var applied: [(envelope: RecordEnvelope, hash: String?)] = []
    if !prepared.isEmpty {
      try store.applyExternalChanges { context in
        for item in prepared {
          do {
            if item.envelope.deleted {
              try RecordCodec.delete(id: item.envelope.id, model: item.envelope.model, from: context)
            } else if let payload = item.envelope.payload {
              try RecordCodec.upsert(
                payload, id: item.envelope.id, attachmentData: item.attachments, into: context)
            }
            applied.append((item.envelope, item.hash))
          } catch RecordCodecError.missingParent {
            extraWaiting.insert(item.envelope.id)  // der Elterndatensatz kommt womöglich erst noch
          }
        }
      }
    }

    // 5. Im selben Haupt-Akteur-Schritt: Das `didSave` wirkt erst nach der Entprellzeit, dann stimmen die
    //    Prüfsummen schon mit dem Buch, und übernommene Stände werden nicht zurückgeschrieben.
    for item in applied { ledger.recordApplied(item.envelope, payloadHash: item.hash) }
    let allWaiting = resolution.waitingIDs.union(extraWaiting)
    for file in resolution.seenFiles {
      switch RemoteLayout.classify(path: file.path) {
      case .record(_, let id)?, .conflictCopy(_, let id)?:
        if !allWaiting.contains(id) { ledger.recordSeen(file) }
      default: break
      }
    }
    for id in resolution.forgetIDs { ledger.entries[id] = nil }
    ledgerStore.ledger = ledger
    return extraWaiting
  }

  /// `nil`, wenn ein Anhang fehlt oder nicht geladen werden konnte (die Kennung wartet dann).
  private func downloadAttachments(of envelope: RecordEnvelope, ledger: SyncLedger) async throws
    -> [String: Data]?
  {
    guard let payload = envelope.payload else { return [:] }
    var result: [String: Data] = [:]
    for (field, ref) in payload.attachments {
      let path = RemoteLayout.attachmentPath(
        model: envelope.model, id: envelope.id, field: field, hash: ref.hash)
      guard let file = ledger.remote.file(at: path) else { return nil }
      do {
        result[field] = try await remote.download(itemID: file.itemID)
      } catch let error as RemoteDataFolderError where Self.isInfrastructure(error) {
        throw error
      } catch {
        return nil
      }
    }
    return result
  }

  // MARK: - 7. Lokale Änderungen

  private func captureLocalChanges(_ ledger: inout SyncLedger, now: Date, forceFull: Bool = false) throws {
    // Ohne Beobachter wird nichts gesammelt: dann wird jedes Mal alles geprüft.
    let fullScan = forceFull || !didInitialScan || observer == nil
    guard fullScan || localChangeSeen else { return }

    let context = store.modelContext
    let exported =
      fullScan
      ? try RecordCodec.exportAll(from: context)
      : try RecordCodec.export(changedIDs, from: context)
    let states = try exported.map { try RecordCodec.state(of: $0) }
    let liveIDs = try RecordCodec.liveIDs(in: context)
    ledger = DataFolderPlanner.markLocalChanges(changed: states, liveIDs: liveIDs, ledger: ledger, now: now)

    // Nur Datensätze aufheben, die noch geschrieben werden müssen.
    for record in exported { exportCache[record.id] = record }
    let dirty = ledger.dirtyIDs
    exportCache = exportCache.filter { dirty.contains($0.key) }

    didInitialScan = true
    changedIDs.removeAll()
    localChangeSeen = false
  }

  // MARK: - 8. Schreiben

  /// `true`, wenn ein Schreiben an `preconditionFailed` scheiterte (Datensatz bleibt ausstehend).
  private func writeOutgoing(
    _ ledger: inout SyncLedger, resolution: IncomingResolution, waiting: Set<UUID>, now: Date
  ) async throws -> Bool {
    // Ausstehende, lebende Datensätze, die nicht im Zwischenspeicher liegen, werden neu ausgelesen.
    let neededLive = ledger.dirtyIDs.subtracting(waiting).filter { ledger.entries[$0]?.deleted == false }
    if neededLive.contains(where: { exportCache[$0] == nil }) {
      for record in try RecordCodec.exportAll(from: store.modelContext) where neededLive.contains(record.id) {
        exportCache[record.id] = record
      }
    }
    var payloads: [UUID: RecordPayload] = [:]
    for (id, record) in exportCache { payloads[id] = record.payload }

    let rewrites = resolution.rewriteCanonical
    let rewriteIDs = Set(rewrites.map(\.id))
    let outgoing =
      rewrites
      + DataFolderPlanner.outgoing(
        ledger: ledger, payloads: payloads, excluding: waiting.union(rewriteIDs), now: now)

    var conflict = false
    var uploadedAttachments = Set<String>()
    for envelope in outgoing {
      do {
        // Erst die Anhänge (inhaltsadressiert, daher ohne If-Match), dann die JSON-Datei.
        var attachmentsComplete = true
        for (field, ref) in envelope.payload?.attachments ?? [:] {
          let path = RemoteLayout.attachmentPath(
            model: envelope.model, id: envelope.id, field: field, hash: ref.hash)
          if uploadedAttachments.contains(path) || ledger.remote.file(at: path) != nil { continue }
          guard let data = exportCache[envelope.id]?.attachmentData[field] else {
            attachmentsComplete = false  // Daten nicht greifbar: ausstehend lassen
            break
          }
          _ = try await remote.upload(data, to: path, ifMatch: nil)
          uploadedAttachments.insert(path)
        }
        guard attachmentsComplete else { continue }

        let path = RemoteLayout.recordPath(model: envelope.model, id: envelope.id)
        let ifMatch = DataFolderPlanner.ifMatch(for: path, ledger: ledger)
        // Eine Datei, die wir noch nie gelesen haben, nie blind überschreiben.
        if ifMatch == nil, ledger.remote.file(at: path) != nil {
          conflict = true
          continue
        }
        let file = try await remote.upload(try DataFolderCoding.encode(envelope), to: path, ifMatch: ifMatch)
        let hash = try envelope.payload.map { try DataFolderCoding.payloadHash($0) }
        ledger.recordWritten(envelope, payloadHash: hash, file: file)
        exportCache[envelope.id] = nil
      } catch RemoteDataFolderError.preconditionFailed {
        conflict = true  // 412: nicht überschreiben, der nächste Durchgang liest und entscheidet
      }
    }
    ledgerStore.ledger = ledger
    return conflict
  }
}

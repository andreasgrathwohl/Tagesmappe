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

  /// Der laufende Durchgang samt seiner Wiederholungen; `nil`, wenn keiner läuft.
  @ObservationIgnored private var currentRun: Task<Void, Never>?
  @ObservationIgnored private var rerunRequested = false
  /// Ein Aufruf während des laufenden Durchgangs wollte den Fortschritt sichtbar haben (`runCycle()`).
  @ObservationIgnored private var rerunVisible = false
  /// Nach `stop()`: kein neuer Durchgang, kein weiterer Schritt eines laufenden, kein Schreiben des Buchs.
  /// Das Buch gehört dann womöglich schon einem anderen Datenort (Wechsel auf iCloud und zurück).
  @ObservationIgnored private var isStopped = false

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
    isStopped = false
    if observer == nil {
      observer = NotificationCenter.default.addObserver(
        forName: ModelContext.didSave, object: store.modelContext, queue: .main
      ) { [weak self] notification in
        let saved = SavedIdentifiers(notification)
        MainActor.assumeIsolated { self?.contextDidSave(saved) }
      }
    }
    startPolling()
    Task { await runSerialized(writeOnly: false, quiet: true) }
  }

  /// Beobachter und Abfrage beenden. Ein laufender Durchgang bricht beim nächsten Schritt ab und schreibt
  /// das Buch nicht mehr; wer darauf warten muss, nimmt `stopAndWait()`.
  func stop() {
    isStopped = true
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
    pollTask?.cancel()
    pollTask = nil
    debounceTask?.cancel()
    debounceTask = nil
  }

  /// `stop()` und warten, bis ein laufender Durchgang beendet ist. Danach fasst dieses Objekt weder Buch
  /// noch Datenbank noch an – Voraussetzung, bevor der Controller das Buch entfernt oder neu anlegt.
  func stopAndWait() async {
    stop()
    await currentRun?.value
  }

  func sceneDidBecomeActive() {
    guard !isStopped else { return }
    startPolling()
    Task { await runSerialized(writeOnly: false, quiet: true) }
  }

  /// Abfrage aus; ausstehende Änderungen sofort schreiben (Schritte 8–10).
  func sceneDidEnterBackground() {
    pollTask?.cancel()
    pollTask = nil
    debounceTask?.cancel()
    debounceTask = nil
    Task { await runSerialized(writeOnly: true, quiet: true) }
  }

  func networkDidBecomeAvailable() {
    Task { await runSerialized(writeOnly: false, quiet: true) }
  }

  private func startPolling() {
    pollTask?.cancel()
    pollTask = Task { [pollInterval] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: pollInterval) } catch { return }
        await runSerialized(writeOnly: false, quiet: true)
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
      await runSerialized(writeOnly: true, quiet: true)
    }
  }

  // MARK: - Durchgang

  /// Lesen → anwenden → zusammenführen → schreiben. Nie doppelt: Ein Aufruf während eines laufenden
  /// Durchgangs merkt sich „noch einmal“ und wartet, bis der laufende Durchgang samt dieser Wiederholung
  /// fertig ist – danach sind ausstehende Änderungen geschrieben (soweit das Netz es zuließ).
  /// Der Status zeigt dabei „wird abgeglichen“; Durchgänge im Hintergrund (Abfrage, Speichern) behalten
  /// die bisherige Aussage, damit „Stand des Abgleichs“ nicht jede Minute flackert.
  func runCycle() async {
    await runSerialized(writeOnly: false, quiet: false)
  }

  /// Swift-Hinweis: `Task { … }` in einer Methode des Hauptakteurs läuft selbst auf dem Hauptakteur. Der
  /// Durchgang steckt in einer eigenen Aufgabe, damit spätere Aufrufer auf genau diese warten können
  /// (`await currentRun.value`), statt sofort zurückzukehren.
  private func runSerialized(writeOnly: Bool, quiet: Bool) async {
    guard !isStopped else { return }
    if let currentRun {
      rerunRequested = true
      if !quiet { rerunVisible = true }
      await currentRun.value
      return
    }
    let run = Task { await self.runLoop(writeOnly: writeOnly, quiet: quiet) }
    currentRun = run
    await run.value
  }

  private func runLoop(writeOnly: Bool, quiet: Bool) async {
    // Im selben Hauptakteur-Schritt wie die letzte Prüfung von `rerunRequested`: Wer `currentRun` noch
    // gesetzt sieht, dessen Wunsch wird von dieser Schleife noch bedient.
    defer { currentRun = nil }
    var writeOnly = writeOnly
    var quiet = quiet
    var directRerunUsed = false
    while !isStopped {
      rerunRequested = false
      rerunVisible = false
      let conflict = await execute(writeOnly: writeOnly, quiet: quiet)
      if isStopped { return }
      // Nach einem 412 höchstens einmal direkt hintereinander noch einmal (Schritt 8).
      if conflict && !directRerunUsed {
        directRerunUsed = true
        writeOnly = false
        continue
      }
      if rerunRequested {
        writeOnly = false
        quiet = !rerunVisible
        continue
      }
      return
    }
  }

  /// Bricht einen Durchgang ab, sobald `stop()` gerufen wurde (nach jedem `await` geprüft).
  private struct Stopped: Error {}

  private func checkStopped() throws {
    if isStopped { throw Stopped() }
  }

  /// Schreibt das Buch – nie nach `stop()`.
  private func persist(_ ledger: SyncLedger) {
    guard !isStopped else { return }
    ledgerStore.ledger = ledger
  }

  /// Ein Durchgang; `true`, wenn ein Schreiben an `preconditionFailed` scheiterte.
  /// `writeOnly`: nur die Schritte 7–10 (nach einem Speichern, beim Wechsel in den Hintergrund).
  /// `quiet`: „wird abgeglichen“ nur zeigen, wenn bisher kein ruhiger Stand angezeigt wird.
  private func execute(writeOnly: Bool, quiet: Bool) async -> Bool {
    cycleCount += 1
    if !quiet || status.phase != .idle || status.lastSuccess == nil {
      status.phase = .syncing
    }
    let cycleNow = now()

    var ledger: SyncLedger
    do {
      ledger = try await currentLedger()
      try checkStopped()
    } catch {
      if isStopped { return false }
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
        try checkStopped()
        // 2./3. Lesen und entscheiden.
        let read = try await readChangedFiles(ledger)
        try checkStopped()
        resolution = IncomingResolver.resolve(read: read, ledger: ledger, now: cycleNow)
        // 4./5. Anwenden und Buch fortschreiben, ohne `await` dazwischen.
        let extraWaiting = try await applyIncoming(resolution, ledger: &ledger)
        try checkStopped()
        waiting = resolution.waitingIDs.union(extraWaiting)
        resolution.removeFiles.removeAll { file in
          if case .record(_, let id)? = RemoteLayout.classify(path: file.path) { return extraWaiting.contains(id) }
          if case .conflictCopy(_, let id)? = RemoteLayout.classify(path: file.path) { return extraWaiting.contains(id) }
          return false
        }
        resolution.rewriteCanonical.removeAll { extraWaiting.contains($0.id) }
        persist(ledger)
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
      // Nach einem frischen Delta ist das Bild des Ordners aktuell; nach einem reinen Schreiben nicht.
      let outcome = try await writeOutgoing(
        &ledger, resolution: resolution, waiting: waiting, indexIsFresh: !writeOnly, now: cycleNow)
      try checkStopped()
      conflict = outcome.conflict
      // Konfliktkopien, deren Gewinner nicht ins Original zurückgeschrieben werden konnte, bleiben liegen:
      // sonst ginge der Gewinner verloren (das Buch führt ihn als sauber, localWins verhindert Neuschreiben).
      if !outcome.failedRewrites.isEmpty {
        resolution.removeFiles.removeAll { file in
          if case .conflictCopy(_, let id)? = RemoteLayout.classify(path: file.path) {
            return outcome.failedRewrites.contains(id)
          }
          return false
        }
      }
      // 9. Entschiedene Dateien entfernen. Alle Schreibvorgänge sind da schon gelungen: Ein Fehler beim
      //    Entfernen einer einzelnen Datei bricht den Durchgang nicht ab. Ihr eTag wird vergessen, damit der
      //    nächste Durchgang sie erneut liest und neu entscheidet (sonst bliebe sie als „gesehen“ liegen).
      for file in resolution.removeFiles {
        if isStopped { break }
        do {
          try await remote.delete(file)
        } catch let error as RemoteDataFolderError {
          ledger.seenETags[file.path] = nil
          if case .preconditionFailed = error { continue }  // zwischenzeitlich geändert
          Self.logger.notice(
            "Entfernen verschoben: \(file.path, privacy: .public) – \(String(describing: error), privacy: .public)")
          // Ohne Netz, ohne Anmeldung oder gedrosselt scheitern auch alle weiteren: aufhören, nicht abbrechen.
          if Self.isInfrastructure(error) { break }
        } catch {
          ledger.seenETags[file.path] = nil
          Self.logger.notice("Entfernen verschoben: \(file.path, privacy: .public)")
        }
      }
      try checkStopped()
      // 10. Erfolg.
      ledger.lastSuccessfulSync = now()
      persist(ledger)
      status = DataFolderSyncStatus(
        phase: .idle, lastSuccess: ledger.lastSuccessfulSync, pendingCount: ledger.dirtyIDs.count,
        waitingCount: lastWaitingCount, newerFormatCount: lastNewerFormatCount)
      return conflict
    } catch {
      // Nach `stop()` gehört das Buch womöglich schon einem anderen Datenort: nichts mehr schreiben.
      if isStopped { return false }
      // Lokale Änderungen trotzdem erfassen, damit sie ausstehend vermerkt sind und nichts verloren geht.
      try? captureLocalChanges(&ledger, now: cycleNow)
      persist(ledger)
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
    persist(created)
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
    var fullEnumeration = link == nil
    if fullEnumeration { ledger.remote.beginResync() }
    var firstCall = true
    var restarted = false
    while true {
      do {
        let page = try await remote.delta(link: link)
        // Entfernte Dateien vergessen dabei ihr eTag (kein `If-Match` mehr auf eine verschwundene Datei).
        ledger.applyRemote(page.items)
        if let next = page.nextLink {
          link = next
          firstCall = false
          continue
        }
        ledger.remote.deltaLink = page.deltaLink
        // Eine vollständige Aufzählung meldet keine Löschungen: eTags fehlender Dateien hier vergessen.
        if fullEnumeration { ledger.pruneSeenETags() }
        return
      } catch RemoteDataFolderError.resyncRequired {
        // 410: von vorn. Die gemerkten eTags vorhandener Dateien bleiben, es wird also nichts doppelt gelesen.
        guard !restarted else { throw RemoteDataFolderError.resyncRequired }
        restarted = true
        ledger.remote.beginResync()
        link = nil
        fullEnumeration = true
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
    ledger.applyRemote(items)
    ledger.pruneSeenETags()
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
    //    Das Wörterbuch der Dateien einmal bilden, nicht je Anhang (läuft auf dem Hauptakteur).
    let remoteFiles: [String: RemoteFile] = resolution.apply.isEmpty ? [:] : ledger.remote.filesByPath
    for envelope in resolution.apply {
      guard let attachments = try await downloadAttachments(of: envelope, files: remoteFiles) else {
        extraWaiting.insert(envelope.id)
        continue
      }
      let hash = try envelope.payload.map { try DataFolderCoding.payloadHash($0) }
      prepared.append((envelope, attachments, hash))
    }
    // Nach `stop()` gehört die Datenbank womöglich nicht mehr zum aktuellen Datenort: nichts anwenden.
    try checkStopped()

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
    // Vergessen samt eTag: Die Datei wird in diesem Durchgang entfernt.
    for id in resolution.forgetIDs { ledger.forget(id) }
    persist(ledger)
    return extraWaiting
  }

  /// `nil`, wenn ein Anhang fehlt oder nicht geladen werden konnte (die Kennung wartet dann).
  private func downloadAttachments(of envelope: RecordEnvelope, files: [String: RemoteFile]) async throws
    -> [String: Data]?
  {
    guard let payload = envelope.payload else { return [:] }
    var result: [String: Data] = [:]
    for (field, ref) in payload.attachments {
      let path = RemoteLayout.attachmentPath(
        model: envelope.model, id: envelope.id, field: field, hash: ref.hash)
      guard let file = files[path] else { return nil }
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

  /// `conflict`: ein Schreiben scheiterte an `preconditionFailed` oder an einer ungelesenen Datei (Datensatz bleibt
  /// ausstehend). `failedRewrites`: Kennungen der Zurückschreibungen eines Konfliktgewinners, die nicht gelangen.
  /// `indexIsFresh`: Das Bild des Ordners stammt aus dem Delta dieses Durchgangs. Nur dann heißt „gemerktes eTag,
  /// aber keine Datei“, dass die Datei wirklich fort ist (nach einem reinen Schreiben fehlen dort eigene, eben
  /// geschriebene Dateien noch).
  private func writeOutgoing(
    _ ledger: inout SyncLedger, resolution: IncomingResolution, waiting: Set<UUID>, indexIsFresh: Bool,
    now: Date
  ) async throws -> (conflict: Bool, failedRewrites: Set<UUID>) {
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
    var writtenIDs = Set<UUID>()
    var uploadedAttachments = Set<String>()
    // Einmal je Durchgang statt je Datensatz und Anhang (`file(at:)` baut die ganze Liste neu).
    let remoteFiles: [String: RemoteFile] = outgoing.isEmpty ? [:] : ledger.remote.filesByPath
    for envelope in outgoing {
      if isStopped { break }
      do {
        // Erst prüfen, ob die JSON-Datei geschrieben werden darf – sonst blieben hochgeladene Anhänge verwaist.
        let path = RemoteLayout.recordPath(model: envelope.model, id: envelope.id)
        if indexIsFresh, remoteFiles[path] == nil, ledger.seenETags[path] != nil {
          // Die Datei ist fort (abgelaufene Löschmarke anderswo entfernt, im Browser gelöscht): neu anlegen.
          ledger.seenETags[path] = nil
        }
        let ifMatch = DataFolderPlanner.ifMatch(for: path, ledger: ledger)
        // Eine Datei, die wir noch nie gelesen haben, nie blind überschreiben.
        if ifMatch == nil, remoteFiles[path] != nil {
          conflict = true
          continue
        }

        // Dann die Anhänge (inhaltsadressiert, daher ohne If-Match), zuletzt die JSON-Datei.
        var attachmentsComplete = true
        for (field, ref) in envelope.payload?.attachments ?? [:] {
          let attachmentPath = RemoteLayout.attachmentPath(
            model: envelope.model, id: envelope.id, field: field, hash: ref.hash)
          if uploadedAttachments.contains(attachmentPath) || remoteFiles[attachmentPath] != nil { continue }
          guard let data = exportCache[envelope.id]?.attachmentData[field] else {
            attachmentsComplete = false  // Daten nicht greifbar: ausstehend lassen
            break
          }
          _ = try await remote.upload(data, to: attachmentPath, ifMatch: nil)
          uploadedAttachments.insert(attachmentPath)
        }
        guard attachmentsComplete else { continue }

        let data = try DataFolderCoding.encode(envelope)
        let file: RemoteFile
        do {
          file = try await remote.upload(data, to: path, ifMatch: ifMatch)
        } catch RemoteDataFolderError.server(let code) where code == 404 && ifMatch != nil {
          // 404 auf ein bedingtes Schreiben: Die Datei gibt es nicht mehr. Ohne If-Match neu anlegen.
          ledger.seenETags[path] = nil
          file =try await remote.upload(data, to: path, ifMatch: nil)
        }
        let hash = try envelope.payload.map { try DataFolderCoding.payloadHash($0) }
        ledger.recordWritten(envelope, payloadHash: hash, file: file)
        exportCache[envelope.id] = nil
        writtenIDs.insert(envelope.id)
      } catch RemoteDataFolderError.preconditionFailed {
        conflict = true  // 412: nicht überschreiben, der nächste Durchgang liest und entscheidet
      }
    }
    persist(ledger)
    return (conflict, rewriteIDs.subtracting(writtenIDs))
  }
}

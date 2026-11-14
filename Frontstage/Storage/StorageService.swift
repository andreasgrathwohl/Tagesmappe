import Foundation
import FrontstageCore
import Observation

/// Ergebnis von „Neu verknüpfen“.
enum RelinkResult: Equatable {
  case relinked(MaterialReference)
  /// Die gewählte Datei liegt in keinem freigegebenen Ordner dieses Geräts.
  case outsideGrants
  /// Die Zuordnungen ließen sich nicht speichern; der alte Ort bleibt bestehen.
  case saveFailed
}

enum StorageReadError: Error, Equatable {
  /// Freigabe oder Datei löst auf diesem Gerät nicht auf.
  case unresolvable
  case unavailable(UnavailableReason)
  case readFailed
}

/// Was nach dem Öffnen geschieht; die Oberfläche übersetzt es in Anzeige oder Meldung.
enum OpenOutcome {
  /// An die zuständige App übergeben.
  case handedOff
  /// Als Cloud-Dokument in der Office-App geöffnet (FR-5.1).
  case openedAsCloudDocument
  /// Teilplan 06 zeigt die Datei an und ruft danach `close()`.
  case showInViewer(ScopedFile)
  /// Für diese Datei wartet schon ein anderer Aufruf auf das Herunterladen; er öffnet sie von selbst.
  case waitingForDownload
  /// Die Oberfläche bietet „Neu verknüpfen“ an.
  case unavailable(UnavailableReason)
  case failed
}

/// Fassade der Ablage für die Oberflächen (Teilplan 04, 06, 07): Freigaben, Neu verknüpfen, Öffnen,
/// Bereithalten. Sie verdrahtet nur; entschieden wird in `OpenRouter`, `CloudOpenPolicy` und `PrefetchPlanner`.
@MainActor @Observable final class StorageService {
  /// Aktuelle Ordnerfreigaben dieses Geräts (Spiegel des Speichers, damit Ansichten sie beobachten).
  private(set) var grants: [FolderGrant]
  /// Zustand je Ort (Schlüssel `MaterialReference.locationKey`) für die Tagesansicht.
  private(set) var availability: [String: MaterialAvailability] = [:]
  /// Gesetzt nach einer Cloud-Übergabe; Teilplan 04 fragt beim Zurückkehren `offerOpenWithoutAutoSave(now:)`.
  private(set) var lastCloudHandOver: (reference: MaterialReference, at: ContinuousClock.Instant)?

  @ObservationIgnored private let grantStore: FolderGrantStore
  @ObservationIgnored private let references: any MaterialReferenceStore
  @ObservationIgnored private let resolver: MaterialResolver
  @ObservationIgnored private let prefetcher: Prefetcher
  @ObservationIgnored private let network: NetworkMonitor
  @ObservationIgnored private let account: MicrosoftAccount
  @ObservationIgnored private let oneDrive: OneDriveService
  @ObservationIgnored private let handOff: any DocumentHandingOff
  @ObservationIgnored private let uriForm: OfficeURIForm
  @ObservationIgnored private let preparationLimit: Duration
  @ObservationIgnored private let handOverLimit: Duration
  @ObservationIgnored private let pollInterval: Duration
  @ObservationIgnored private let downloadLimit: Duration
  @ObservationIgnored private let clock = ContinuousClock()
  /// Orte, für die schon ein Aufruf auf das Herunterladen wartet.
  @ObservationIgnored private var waiting: Set<String> = []

  convenience init(
    grants: FolderGrantStore, references: any MaterialReferenceStore, resolver: MaterialResolver,
    prefetcher: Prefetcher, network: NetworkMonitor, account: MicrosoftAccount, oneDrive: OneDriveService,
    handOff: any DocumentHandingOff, uriForm: OfficeURIForm = .webStyle
  ) {
    self.init(
      grants: grants, references: references, resolver: resolver, prefetcher: prefetcher, network: network,
      account: account, oneDrive: oneDrive, handOff: handOff, uriForm: uriForm,
      preparationLimit: CloudOpenPolicy.preparationLimit, handOverLimit: CloudOpenPolicy.handOverLimit)
  }

  /// Interner Initialisierer für Tests: verkürzte Fristen (sonst `CloudOpenPolicy.preparationLimit`/`handOverLimit`).
  /// Abfrage-Takt und Höchstdauer des Wartens auf einen Download sind hier ebenfalls einstellbar.
  init(
    grants: FolderGrantStore, references: any MaterialReferenceStore, resolver: MaterialResolver,
    prefetcher: Prefetcher, network: NetworkMonitor, account: MicrosoftAccount, oneDrive: OneDriveService,
    handOff: any DocumentHandingOff, uriForm: OfficeURIForm, preparationLimit: Duration, handOverLimit: Duration,
    pollInterval: Duration = .seconds(2), downloadLimit: Duration = .seconds(120)
  ) {
    self.grantStore = grants
    self.grants = grants.grants
    self.references = references
    self.resolver = resolver
    self.prefetcher = prefetcher
    self.network = network
    self.account = account
    self.oneDrive = oneDrive
    self.handOff = handOff
    self.uriForm = uriForm
    self.preparationLimit = preparationLimit
    self.handOverLimit = handOverLimit
    self.pollInterval = pollInterval
    self.downloadLimit = downloadLimit
    // Nach der Anmeldung die OneDrive-Ordner der Freigaben suchen (Teilplan 03, Task 9).
    account.onSignedIn = { [weak self] in await self?.detectOneDriveFolders() }
  }

  // MARK: Freigaben

  func suggestedGrantName(for folderURL: URL) -> GrantNameSuggestion {
    // Ein Lesefehler im Speicher heißt nur: kein Namensvorschlag aus anderen Geräten.
    let mirrored = (try? references.folderGrantNames()) ?? []
    return FolderGrantNaming.suggestion(
      folderName: folderURL.lastPathComponent, localGrantNames: Set(grants.map(\.name)), mirroredNames: mirrored)
  }

  /// Legt die Freigabe an und sucht danach den OneDrive-Ordner, falls ein Konto angemeldet ist.
  func addGrant(folderURL: URL, name: String) async throws -> FolderGrant {
    let grant = try grantStore.add(folderURL: folderURL, name: name)
    grants = grantStore.grants
    await detectOneDriveFolders()
    return grantStore.grants.first { $0.id == grant.id } ?? grant
  }

  func renameGrant(id: UUID, to name: String) throws {
    try grantStore.rename(id: id, to: name)
    grants = grantStore.grants
  }

  func removeGrant(id: UUID) {
    grantStore.remove(id: id)
    grants = grantStore.grants
  }

  private func detectOneDriveFolders() async {
    guard account.isSignedIn else { return }
    await oneDrive.detectOneDriveFolders()
    grants = grantStore.grants
  }

  // MARK: Zuordnen und Neu verknüpfen

  /// Datei aus der Ordnerauswahl → Verweis; `nil` = außerhalb der freigegebenen Ordner.
  func reference(forPickedFile url: URL) -> MaterialReference? {
    resolver.reference(forPickedFile: url)
  }

  /// Ersetzt den Ort an allen Zuordnungen mit dem alten Ort (ADR-0003); Zuordnungen und Stiftnotizen bleiben.
  func relink(_ old: MaterialReference, toPickedFile url: URL) -> RelinkResult {
    guard let new = resolver.reference(forPickedFile: url) else { return .outsideGrants }
    // Bei einem Speicherfehler bleibt der alte Ort bestehen.
    guard (try? references.replaceReferences(atLocation: old.locationKey, with: new)) != nil else {
      return .saveFailed
    }
    availability[old.locationKey] = nil
    refreshAvailability(for: [new])
    return .relinked(new)
  }

  // MARK: Zustand

  func refreshAvailability(for references: [MaterialReference]) {
    for reference in references { updateAvailability(of: reference) }
  }

  @discardableResult
  private func updateAvailability(of reference: MaterialReference) -> MaterialAvailability {
    let state = resolver.availability(of: reference, isOnline: network.isOnline)
    availability[reference.locationKey] = state
    return state
  }

  // MARK: Öffnen

  func open(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome {
    await perform(reference, anchor: anchor, allowCloud: true)
  }

  /// Übergabe der Datei erzwingen, auch wenn ein Cloud-Dokument möglich wäre.
  func openWithoutAutoSave(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome {
    await perform(reference, anchor: anchor, allowCloud: false)
  }

  /// Nach der Rückkehr in die App: der Verweis der letzten Cloud-Übergabe, wenn sie höchstens
  /// `CloudOpenPolicy.returnWindow` zurückliegt. Das Angebot gilt einmal.
  func offerOpenWithoutAutoSave(now: ContinuousClock.Instant) -> MaterialReference? {
    guard let last = lastCloudHandOver else { return nil }
    lastCloudHandOver = nil
    return CloudOpenPolicy.offersOpenWithoutAutoSave(returnedAfter: last.at.duration(to: now)) ? last.reference : nil
  }

  /// Anzeige (Teilplan 06) ohne Wegentscheidung; `nil` = löst nicht auf.
  func readableFile(for reference: MaterialReference) -> ScopedFile? {
    resolver.open(reference)
  }

  /// Vorlage (Teilplan 07): liest die Datei nur lesend (koordiniert, `.withoutChanges`), ruft `body` mit der
  /// URL außerhalb des Hauptthreads und beendet den Zugriff danach in jedem Fall.
  ///
  /// Swift-Hinweis: `Task.detached` verlässt den Hauptakteur; `NSFileCoordinator` blockiert den
  /// aufrufenden Thread, bis die Datei bereit ist, und gehört deshalb nie auf den Hauptthread.
  func withFileURL<T: Sendable>(
    for reference: MaterialReference, _ body: @escaping @Sendable (URL) throws -> T
  ) async throws -> T {
    guard let file = resolver.open(reference) else { throw StorageReadError.unresolvable }
    defer { file.close() }
    if case .unavailable(let reason) = updateAvailability(of: reference) {
      throw StorageReadError.unavailable(reason)
    }
    let url = file.url
    do {
      return try await Task.detached { try Self.coordinatedRead(of: url, body) }.value
    } catch {
      throw StorageReadError.readFailed
    }
  }

  nonisolated private static func coordinatedRead<T: Sendable>(
    of url: URL, _ body: @Sendable (URL) throws -> T
  ) throws -> T {
    var coordinationError: NSError?
    var result: Result<T, Error>?
    NSFileCoordinator(filePresenter: nil).coordinate(
      readingItemAt: url, options: .withoutChanges, error: &coordinationError
    ) { readURL in
      result = Result { try body(readURL) }
    }
    if let coordinationError { throw coordinationError }
    guard let result else { throw StorageReadError.readFailed }
    return try result.get()
  }

  // MARK: Bereithalten

  /// Hält Dateien von heute und vom nächsten Unterrichtstag bereit (NFR-1) und holt fehlende
  /// OneDrive-Kennungen der Office-Dateien (FR-5.1), damit das Öffnen später nicht suchen muss.
  func prepareForTeaching(
    today: CalendarDay, timetable: Timetable, nonTeachingPeriods: [NonTeachingPeriod], changes: [ScheduleChange]
  ) async {
    let keys = PrefetchPlanner.lessonKeys(
      today: today, timetable: timetable, nonTeachingPeriods: nonTeachingPeriods, changes: changes)
    // Ein Lesefehler bricht das Bereithalten nur ab; es läuft beim nächsten Anlass erneut.
    guard let links = try? references.linkedReferences(for: keys) else { return }
    let planned = PrefetchPlanner.references(for: keys, links: links)
    await prefetcher.prefetch(planned)
    refreshAvailability(for: planned)

    guard account.isSignedIn, network.isOnline else { return }
    for reference in planned
    where OfficeApp(fileExtension: reference.fileExtension) != nil && (reference.oneDriveItemID ?? "").isEmpty
      && hasOneDriveLocation(reference)
    {
      if let item = await fetchItem(for: reference) { _ = storeIdentifiers(of: item, in: reference) }
    }
  }

  /// Beim Zuordnen sofort bereithalten.
  func didAssign(_ references: [MaterialReference]) async {
    await prefetcher.prefetch(references)
    refreshAvailability(for: references)
  }

  // MARK: Öffnen – Ablauf

  private func perform(_ original: MaterialReference, anchor: HandOffAnchor, allowCloud: Bool) async -> OpenOutcome {
    var reference = original
    let officeApp = allowCloud ? OfficeApp(fileExtension: reference.fileExtension) : nil
    var context = OpenContext(
      // Erzwungene Übergabe: Dateiart „andere“ führt den Router auf den Weg „übergeben“.
      fileKind: allowCloud ? reference.fileKind : .other,
      officeApp: officeApp,
      availability: updateAvailability(of: reference),
      isOnline: network.isOnline,
      isMicrosoftSignedIn: account.isSignedIn,
      isOfficeAppInstalled: officeApp.map { handOff.isInstalled($0) } ?? false,
      oneDriveDocumentURL: nil)

    // Die Adresse wird nur gesucht, wenn der Router sie auch verwenden könnte.
    if officeApp != nil, context.isMicrosoftSignedIn, context.isOnline, context.isOfficeAppInstalled,
      hasOneDriveLocation(reference), let item = await fetchItem(for: reference)
    {
      reference = storeIdentifiers(of: item, in: reference)
      context.oneDriveDocumentURL = OfficeAddress.documentURL(for: item)
    }
    return await execute(OpenRouter.route(context), reference: reference, context: context, anchor: anchor)
  }

  private func execute(
    _ route: OpenRoute, reference: MaterialReference, context: OpenContext, anchor: HandOffAnchor
  ) async -> OpenOutcome {
    switch route {
    case .viewer:
      guard let file = resolver.open(reference) else { return .failed }
      return .showInViewer(file)
    case .handOff:
      return await handOffFile(reference, anchor: anchor)
    case .officeCloud(let documentURL):
      return await openCloudDocument(documentURL, reference: reference, context: context, anchor: anchor)
    case .waitForDownload(let target):
      return await waitForDownload(reference, then: target, context: context, anchor: anchor)
    case .unavailable(let reason):
      return .unavailable(reason)
    }
  }

  private func handOffFile(_ reference: MaterialReference, anchor: HandOffAnchor) async -> OpenOutcome {
    guard let file = resolver.open(reference) else { return .failed }
    let accepted = await handOff.handOff(file, anchor: anchor)
    // Nach einer Übergabe hält die Übergabe den Zugriff; sonst endet er hier (zweites `close()` schadet nicht).
    if !accepted { file.close() }
    return accepted ? .handedOff : .failed
  }

  private func openCloudDocument(
    _ documentURL: String, reference: MaterialReference, context: OpenContext, anchor: HandOffAnchor
  ) async -> OpenOutcome {
    guard let app = context.officeApp else {
      return await fallBackToFile(reference, context: context, anchor: anchor)
    }
    let uri = OfficeAddress.officeURI(
      app: app, documentURL: documentURL, form: uriForm, origin: UUID(), correlation: UUID(),
      timestampMillis: Int64(Date().timeIntervalSince1970 * 1000))
    let start = clock.now
    let accepted = await handOff.openOfficeURI(uri, limit: handOverLimit)
    // `nil` heißt: keine Antwort binnen Frist – die Frist ist dann per Definition erreicht.
    let elapsed = accepted == nil ? max(start.duration(to: clock.now), CloudOpenPolicy.handOverLimit) : start.duration(to: clock.now)
    switch CloudOpenPolicy.afterHandOver(accepted: accepted, elapsed: elapsed) {
    case .done:
      lastCloudHandOver = (reference, clock.now)
      return .openedAsCloudDocument
    case .keepWaiting, .fallBackToHandOff:
      // Die Adresse kann veraltet sein (Datei in OneDrive verschoben oder umbenannt): beim nächsten Mal neu suchen.
      oneDrive.forgetItem(for: reference)
      return await fallBackToFile(reference, context: context, anchor: anchor)
    }
  }

  /// Rückfall: dieselbe Entscheidung des Routers, nur ohne Cloud-Adresse (Übergabe der Datei).
  private func fallBackToFile(
    _ reference: MaterialReference, context: OpenContext, anchor: HandOffAnchor
  ) async -> OpenOutcome {
    var local = context
    local.oneDriveDocumentURL = nil
    local.availability = updateAvailability(of: reference)
    return await execute(OpenRouter.route(local), reference: reference, context: local, anchor: anchor)
  }

  /// Fordert das Herunterladen an und liest den Zustand alle `pollInterval` neu; höchstens `downloadLimit`.
  private func waitForDownload(
    _ reference: MaterialReference, then target: OpenRoute, context: OpenContext, anchor: HandOffAnchor
  ) async -> OpenOutcome {
    let key = reference.locationKey
    guard waiting.insert(key).inserted else { return .waitingForDownload }
    defer { waiting.remove(key) }

    await prefetcher.prefetch([reference])
    let start = clock.now
    while start.duration(to: clock.now) < downloadLimit {
      do { try await Task.sleep(for: pollInterval) } catch { return .failed }
      switch updateAvailability(of: reference) {
      case .onDevice:
        return await execute(target, reference: reference, context: context, anchor: anchor)
      case .unavailable(let reason):
        return .unavailable(reason)
      case .downloading:
        continue
      }
    }
    return .failed
  }

  // MARK: OneDrive

  /// Nur Verweise mit Kennung oder mit einer Freigabe, deren OneDrive-Ordner bekannt ist, haben eine Adresse.
  private func hasOneDriveLocation(_ reference: MaterialReference) -> Bool {
    if let id = reference.oneDriveItemID, !id.isEmpty { return true }
    return grantStore.grant(named: reference.folderGrantName)?.oneDrivePath != nil
  }

  /// Element zum Verweis mit harter Frist `preparationLimit`; `nil` = nicht gefunden, Fehler oder Frist.
  ///
  /// Swift-Hinweis: kein `withTaskGroup` – die Gruppe wartet nach `cancelAll()` auf alle Kind-Aufgaben, und
  /// die Token-Abfrage (MSAL `acquireTokenSilent` hinter einer Fortsetzung) ist nicht abbrechbar. `FirstOutcome`
  /// kehrt beim ersten Ergebnis zurück; eine verspätete Abfrage läuft im Hintergrund aus und wird verworfen.
  private func fetchItem(for reference: MaterialReference) async -> OneDriveItem? {
    let service = oneDrive
    let limit = preparationLimit
    return await withCheckedContinuation { (continuation: CheckedContinuation<OneDriveItem?, Never>) in
      let outcome = FirstOutcome(continuation)
      outcome.adopt(Task { @MainActor in outcome.finish(try? await service.item(for: reference)) })
      outcome.adopt(
        Task { @MainActor in
          // Abbruch (Ergebnis kam zuerst) darf keine Frist melden.
          guard (try? await Task.sleep(for: limit)) != nil else { return }
          outcome.finish(nil)
        })
    }
  }

  /// Schreibt neue OneDrive-Kennungen an alle Zuordnungen des Ortes zurück (gespiegelt: das zweite Gerät
  /// muss dann nicht erneut suchen) und liefert den aktualisierten Verweis.
  private func storeIdentifiers(of item: OneDriveItem, in reference: MaterialReference) -> MaterialReference {
    let driveID = item.parentReference.driveId
    guard reference.oneDriveItemID != item.id || reference.oneDriveDriveID != driveID else { return reference }
    var updated = reference
    updated.oneDriveItemID = item.id
    updated.oneDriveDriveID = driveID
    // Ein Schreibfehler ist folgenlos: Das Öffnen nutzt die Kennung trotzdem, der nächste Anlass schreibt erneut.
    _ = try? references.replaceReferences(atLocation: reference.locationKey, with: updated)
    return updated
  }
}

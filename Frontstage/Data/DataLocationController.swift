import Foundation
import FrontstageCore
import Observation
import OSLog
import SwiftData

enum DataLocationError: Error, Equatable {
  /// Die Anmeldung bei Microsoft wurde nicht abgeschlossen.
  case notSignedIn
  /// Die Zustimmung zu `Files.ReadWrite` fehlt oder wurde abgelehnt.
  case consentMissing
  /// Kein Netz (der Datenordner ließ sich nicht erreichen).
  case offline
  /// Der Umzug ist gescheitert; der alte Datenort gilt weiter.
  case moveFailed
}

/// Schmale Sicht auf die Microsoft-Anmeldung, damit Tests Zustimmung und Ablehnung nachstellen können:
/// `MicrosoftAccount(signedInUsernameForTesting:)` aus 03 wirft bei jedem MSAL-Weg `.notConfigured`.
///
/// Swift-Hinweis: `extension MicrosoftAccount: DataLocationAccount {}` genügt, weil die Klasse die
/// geforderten Mitglieder schon hat (`private(set) var` erfüllt eine reine Lese-Anforderung).
@MainActor protocol DataLocationAccount: AnyObject {
  var signedInUsername: String? { get }
  var isSignedIn: Bool { get }
  func signIn(anchor: AuthPresentationAnchor) async throws
  func requestScopes(_ scopes: [String], anchor: AuthPresentationAnchor) async throws
}

extension MicrosoftAccount: DataLocationAccount {}

/// Hält den Container, den `DataStore` und die Abgleich-Dienste des gewählten Datenorts und wechselt
/// zur Laufzeit zwischen iCloud und OneDrive (FR-14, ADR-0012).
///
/// Genau ein `ModelContainer` ist zur Zeit aktiv. Ein Wechsel baut Container, Store und Dienste neu auf und
/// erhöht `generation`; `DataScopedRoot` zeichnet daraufhin alles darunter mit `.id(generation)` neu.
/// Scheitert ein Schritt, bevor `settings.location` gesetzt ist, bleibt alles beim alten Datenort.
@MainActor @Observable final class DataLocationController {
  private(set) var location: DataLocation
  private(set) var container: ModelContainer
  private(set) var store: DataStore
  /// Nur bei `.oneDrive`.
  private(set) var folderSync: DataFolderSync?
  /// Steigt bei jedem Wechsel; die Oberfläche baut sich darauf neu auf.
  private(set) var generation: Int = 0
  private(set) var isMoving: Bool = false

  var dataFolder: DataFolder? { settings.dataFolder }

  @ObservationIgnored private let settings: DataLocationSettings
  @ObservationIgnored private let account: any DataLocationAccount
  @ObservationIgnored private let makeContainer: @MainActor (DataLocation) throws -> ModelContainer
  @ObservationIgnored private let makeRemote: @MainActor () -> any RemoteDataFolder
  @ObservationIgnored private let removeOneDriveStore: @MainActor () throws -> Void
  @ObservationIgnored private let ledgerStore: LedgerStore
  @ObservationIgnored private let deviceID: String
  @ObservationIgnored private var trigger: SyncMergeTrigger?

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "DataLocation")

  init(
    settings: DataLocationSettings = .init(), account: any DataLocationAccount,
    makeContainer: @escaping @MainActor (DataLocation) throws -> ModelContainer = {
      try ModelContainerFactory.makeContainer(for: $0)
    },
    makeRemote: @escaping @MainActor () -> any RemoteDataFolder,
    ledgerStore: LedgerStore = .init(), deviceID: String = DeviceIdentity.current(),
    removeOneDriveStore: @escaping @MainActor () throws -> Void = {
      try ModelContainerFactory.removeOneDriveStore()
    }
  ) {
    self.settings = settings
    self.account = account
    self.makeContainer = makeContainer
    self.makeRemote = makeRemote
    self.removeOneDriveStore = removeOneDriveStore
    self.ledgerStore = ledgerStore
    self.deviceID = deviceID

    let initialLocation = settings.location
    let initialContainer: ModelContainer
    do {
      initialContainer = try makeContainer(initialLocation)
    } catch {
      fatalError("Der Datenspeicher konnte nicht geöffnet werden: \(error)")
    }
    let initialStore = DataStore(modelContext: initialContainer.mainContext)
    self.location = initialLocation
    self.container = initialContainer
    self.store = initialStore
    self.trigger = SyncMergeTrigger(store: initialStore)
    if initialLocation == .oneDrive {
      self.folderSync = DataFolderSync(store: initialStore, remote: makeRemote(), ledger: ledgerStore)
    }
  }

  // MARK: - Lebenszyklus

  /// Zusammenführen beim Start; bei OneDrive zusätzlich den Abgleich anlaufen lassen.
  func start() {
    trigger?.start()
    folderSync?.start()
  }

  func sceneDidBecomeActive() {
    trigger?.sceneDidBecomeActive()
    folderSync?.sceneDidBecomeActive()
  }

  func sceneDidEnterBackground() {
    folderSync?.sceneDidEnterBackground()
  }

  func networkDidBecomeAvailable() {
    folderSync?.networkDidBecomeAvailable()
  }

  // MARK: - Wechsel auf OneDrive

  /// Wechsel auf OneDrive: Zustimmung zu `Files.ReadWrite` (anchor), App-Ordner holen, `library.json` lesen
  /// oder anlegen, Umzug, Beitreten. Mit `expected` (Koppeln) wird vorher geprüft, ob der Datenordner der
  /// erwartete ist; bei einem anderen Urteil als `.ok` wird nichts geändert und das Urteil zurückgegeben.
  @discardableResult
  func switchToOneDrive(anchor: AuthPresentationAnchor, expected: PairingPayload? = nil) async throws
    -> PairingVerdict
  {
    guard !isMoving else { throw DataLocationError.moveFailed }
    isMoving = true
    defer { isMoving = false }
    do {
      return try await moveToOneDrive(anchor: anchor, expected: expected)
    } catch {
      Self.logger.error("Wechsel auf OneDrive gescheitert: \(String(describing: error), privacy: .public)")
      throw Self.map(error)
    }
  }

  private func moveToOneDrive(anchor: AuthPresentationAnchor, expected: PairingPayload?) async throws
    -> PairingVerdict
  {
    // 1. Anmeldung und Zustimmung
    if !account.isSignedIn {
      do { try await account.signIn(anchor: anchor) } catch { throw DataLocationError.notSignedIn }
    }
    do {
      try await account.requestScopes(MicrosoftAccount.dataLocationScopes, anchor: anchor)
    } catch {
      throw DataLocationError.consentMissing
    }

    // 2. App-Ordner und library.json
    let remote = makeRemote()
    let folder = try await remote.appFolder()
    var index = RemoteIndex(appFolderID: folder.folderItemID)
    index.apply(try await remote.listAll())
    var marker: LibraryMarker?
    if let file = index.file(at: RemoteLayout.libraryPath) {
      marker = try Self.decodeMarker(try await remote.download(itemID: file.itemID))
    }

    // 3. Koppeln: stimmt der Datenordner? Sonst nichts ändern.
    if let expected {
      let verdict = PairingVerifier.verify(
        expected, foundDriveID: folder.driveID, foundFolderItemID: folder.folderItemID, library: marker)
      guard verdict == .ok else { return verdict }
    } else if let marker, marker.formatVersion > RecordEnvelope.currentFormatVersion {
      return .needsNewerApp
    }

    // Schon auf OneDrive: der offene Container ist die OneDrive-Datei und darf nicht überschrieben werden.
    if location == .oneDrive {
      if let current = settings.dataFolder, current.driveID == folder.driveID,
        current.folderItemID == folder.folderItemID, current.libraryID == marker?.libraryID
      {
        await folderSync?.runCycle()
        return .ok
      }
      throw DataLocationError.moveFailed
    }

    // 4. Datenordner vorbereiten; fehlt library.json, wird sie angelegt.
    try await remote.ensureModelFolders()
    let library: LibraryMarker
    if let marker {
      library = marker
    } else {
      library = LibraryMarker(libraryID: UUID(), createdAt: Date())
      _ = try await remote.upload(try Self.encodeMarker(library), to: RemoteLayout.libraryPath, ifMatch: nil)
    }

    // 5. Umzug: alles aus dem aktuellen Container in den neuen OneDrive-Container
    let records = Self.inApplyOrder(try RecordCodec.exportAll(from: store.modelContext))
    let states = try records.map { try RecordCodec.state(of: $0) }
    try removeOneDriveStore()
    let newContainer = try makeContainer(.oneDrive)
    let newStore = DataStore(modelContext: newContainer.mainContext)
    try Self.apply(records, to: newStore)

    // 6. Ab hier gibt es kein Zurück mehr: nichts davon kann scheitern.
    ledgerStore.ledger = DataFolderJoin.ledger(
      local: states, deviceID: deviceID, appFolderID: folder.folderItemID)
    settings.dataFolder = DataFolder(
      driveID: folder.driveID, folderItemID: folder.folderItemID, libraryID: library.libraryID,
      accountUsername: account.signedInUsername ?? "")
    settings.location = .oneDrive

    stopServices()
    location = .oneDrive
    container = newContainer
    store = newStore
    let newTrigger = SyncMergeTrigger(store: newStore)
    trigger = newTrigger
    let sync = DataFolderSync(store: newStore, remote: remote, ledger: ledgerStore)
    folderSync = sync
    generation += 1

    newTrigger.start()
    // `start()` stößt selbst einen Durchgang an; unserer läuft zuerst und wird hier abgewartet.
    sync.start()
    await sync.runCycle()
    return .ok
  }

  // MARK: - Wechsel auf iCloud

  /// Nimmt die Daten mit zurück nach iCloud. Der Datenordner in OneDrive bleibt unberührt.
  func switchToICloud() async throws {
    guard !isMoving else { throw DataLocationError.moveFailed }
    guard location == .oneDrive else { return }
    isMoving = true
    defer { isMoving = false }
    do {
      // Ausstehende Änderungen noch hinaus; offline geht es trotzdem weiter (Hinweis im Status des Abgleichs).
      await folderSync?.runCycle()

      let records = Self.inApplyOrder(try RecordCodec.exportAll(from: store.modelContext))
      let newContainer = try makeContainer(.iCloud)
      let newStore = DataStore(modelContext: newContainer.mainContext)
      try Self.apply(records, to: newStore)  // nach Kennung einfügen oder überschreiben, nichts löschen
      try newStore.mergeDuplicates()

      ledgerStore.remove()
      settings.dataFolder = nil
      settings.location = .iCloud

      stopServices()
      location = .iCloud
      container = newContainer
      store = newStore
      folderSync = nil
      let newTrigger = SyncMergeTrigger(store: newStore)
      trigger = newTrigger
      generation += 1
      newTrigger.start()
    } catch {
      Self.logger.error("Wechsel auf iCloud gescheitert: \(String(describing: error), privacy: .public)")
      throw Self.map(error)
    }
  }

  // MARK: - Hilfen

  private func stopServices() {
    trigger?.stop()
    folderSync?.stop()
  }

  /// Eltern vor Kindern (`SyncModel.applyOrder`); die Reihenfolge innerhalb eines Modells bleibt.
  private static func inApplyOrder(_ records: [ExportedRecord]) -> [ExportedRecord] {
    var rank: [SyncModel: Int] = [:]
    for (position, model) in SyncModel.applyOrder.enumerated() { rank[model] = position }
    return records.enumerated().sorted { lhs, rhs in
      let left = rank[lhs.element.payload.model] ?? Int.max
      let right = rank[rhs.element.payload.model] ?? Int.max
      return left != right ? left < right : lhs.offset < rhs.offset
    }.map(\.element)
  }

  /// Schreibt alle Datensätze in einem Zug und speichert; scheitert einer, wird alles verworfen.
  private static func apply(_ records: [ExportedRecord], to store: DataStore) throws {
    try store.applyExternalChanges { context in
      for record in records {
        try RecordCodec.upsert(
          record.payload, id: record.id, attachmentData: record.attachmentData, into: context)
      }
    }
  }

  private static func encodeMarker(_ marker: LibraryMarker) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(marker)
  }

  /// Liest `library.json`; eine nicht lesbare Datei bricht den Wechsel ab (nichts wird überschrieben).
  private static func decodeMarker(_ data: Data) throws -> LibraryMarker {
    let iso = JSONDecoder()
    iso.dateDecodingStrategy = .iso8601
    if let marker = try? iso.decode(LibraryMarker.self, from: data) { return marker }
    do {
      return try JSONDecoder().decode(LibraryMarker.self, from: data)
    } catch {
      throw DataLocationError.moveFailed
    }
  }

  private static func map(_ error: Error) -> DataLocationError {
    if let known = error as? DataLocationError { return known }
    if let remote = error as? RemoteDataFolderError {
      switch remote {
      case .offline: return .offline
      case .signInRequired: return .consentMissing
      default: return .moveFailed
      }
    }
    return .moveFailed
  }
}

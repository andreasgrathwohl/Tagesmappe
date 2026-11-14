import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Attrappe: merkt sich ersetzte Verweise und liefert feste gespiegelte Freigabe-Namen.
@MainActor private final class RecordingReferenceStore: MaterialReferenceStore {
  var mirroredGrantNames: Set<String> = []
  var replaced: [(locationKey: String, reference: MaterialReference)] = []

  func linkedReferences(for keys: [LessonKey]) throws -> [(key: LessonKey, reference: MaterialReference)] { [] }
  func folderGrantNames() throws -> Set<String> { mirroredGrantNames }
  func replaceReferences(atLocation locationKey: String, with reference: MaterialReference) throws -> Int {
    replaced.append((locationKey, reference))
    return 1
  }
}

/// Attrappe: fordert nie wirklich an.
private struct NoopDownloader: FileDownloading {
  func requestDownload(of url: URL) async {}
}

/// Attrappe der Übergabe: zählt Aufrufe und antwortet mit einstellbaren Werten.
@MainActor private final class SpyHandOff: DocumentHandingOff {
  var handOffCount = 0
  var officeURIs: [String] = []
  var officeResult: Bool? = true
  var installed = true

  func handOff(_ file: ScopedFile, anchor: HandOffAnchor) async -> Bool {
    handOffCount += 1
    file.close()
    return true
  }
  func openOfficeURI(_ uri: String, limit: Duration) async -> Bool? {
    officeURIs.append(uri)
    return officeResult
  }
  func isInstalled(_ app: OfficeApp) -> Bool { installed }
}

@MainActor @Suite struct StorageServiceTests {
  nonisolated private static let itemJSON =
    #"{"id":"01ABC","name":"Vokabeln Unit 4.pptx","webUrl":"https://example-my.sharepoint.com/personal/m_example_com/Documents/Unterricht/Vokabeln%20Unit%204.pptx","parentReference":{"driveId":"b!x","driveType":"business","path":"/drive/root:/Unterricht"}}"#

  let root: URL
  let folder: URL
  let grants: FolderGrantStore
  private let store = RecordingReferenceStore()
  private let spy = SpyHandOff()

  init() throws {
    root = FileManager.default.temporaryDirectory.appending(
      path: "storage-service-\(UUID().uuidString)", directoryHint: .isDirectory)
    folder = root.appending(path: "Unterricht", directoryHint: .isDirectory)
    let classFolder = folder.appending(path: "8b", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: classFolder, withIntermediateDirectories: true)
    for name in ["Arbeitsblatt Vokabeln.pdf", "Vokabeln Unit 4.pptx", "8b/Arbeitsblatt Vokabeln neu.pdf"] {
      try Data("x".utf8).write(to: folder.appending(path: name, directoryHint: .notDirectory))
    }
    grants = FolderGrantStore(fileURL: root.appending(path: "FolderGrants.json", directoryHint: .notDirectory))
    _ = try grants.add(folderURL: folder, name: "Unterricht")
  }

  private func makeService(
    username: String? = nil, isOnline: Bool = true, preparationLimit: Duration = .seconds(5),
    handler: @escaping StubURLProtocol.Handler = { _ in (404, "{}") }
  ) -> StorageService {
    let server = StubURLProtocol.Server(handler: handler)
    let account = MicrosoftAccount(signedInUsernameForTesting: username)
    let resolver = MaterialResolver(grants: grants)
    let oneDrive = OneDriveService(
      account: account, graph: GraphClient(tokens: FakeTokens(), session: server.session),
      grants: grants, resolver: resolver)
    return StorageService(
      grants: grants, references: store, resolver: resolver,
      prefetcher: Prefetcher(resolver: resolver, store: store, downloader: NoopDownloader()),
      network: NetworkMonitor(isOnline: isOnline), account: account, oneDrive: oneDrive, handOff: spy,
      uriForm: .webStyle, preparationLimit: preparationLimit, handOverLimit: .seconds(10))
  }

  private func reference(_ path: String, kind: MaterialFileKind) -> MaterialReference {
    MaterialReference(
      folderGrantName: "Unterricht", relativePath: path,
      displayName: (path as NSString).deletingPathExtension, fileKind: kind)
  }

  private var presentation: MaterialReference { reference("Vokabeln Unit 4.pptx", kind: .presentation) }

  /// Freigabe mit bekanntem OneDrive-Ordner: Voraussetzung für eine Cloud-Adresse.
  private func markGrantAsOneDriveFolder() throws {
    let grant = try #require(grants.grant(named: "Unterricht"))
    grants.setOneDrivePath(id: grant.id, "Unterricht")
  }

  @Test("PDF öffnet in der Anzeige mit offenem Zugriff (FR-6)")
  func pdfOpensViewer() async throws {
    let service = makeService()
    let outcome = await service.open(reference("Arbeitsblatt Vokabeln.pdf", kind: .pdf), anchor: HandOffAnchor())
    guard case .showInViewer(let file) = outcome else {
      Issue.record("erwartet .showInViewer, erhalten \(outcome)")
      return
    }
    #expect(file.url.lastPathComponent == "Arbeitsblatt Vokabeln.pdf")
    file.close()
  }

  @Test("Präsentation ohne Anmeldung wird übergeben (FR-5, AK-11)")
  func presentationIsHandedOff() async {
    let service = makeService(username: nil)
    let outcome = await service.open(presentation, anchor: HandOffAnchor())
    guard case .handedOff = outcome else {
      Issue.record("erwartet .handedOff, erhalten \(outcome)")
      return
    }
    #expect(spy.handOffCount == 1)
    #expect(spy.officeURIs.isEmpty)
  }

  @Test("Cloud-Übergabe abgelehnt: Rückfall auf Übergabe der Datei (FR-5.1)")
  func rejectedCloudFallsBackToHandOff() async throws {
    try markGrantAsOneDriveFolder()
    spy.officeResult = false
    let service = makeService(username: "max@example.com") { _ in (200, Self.itemJSON) }
    let outcome = await service.open(presentation, anchor: HandOffAnchor())
    guard case .handedOff = outcome else {
      Issue.record("erwartet .handedOff, erhalten \(outcome)")
      return
    }
    #expect(spy.officeURIs.count == 1)
    #expect(spy.handOffCount == 1)
  }

  @Test("Graph antwortet nicht binnen Frist: Übergabe")
  func slowPreparationFallsBack() async throws {
    try markGrantAsOneDriveFolder()
    let service = makeService(username: "max@example.com", preparationLimit: .milliseconds(50)) { _ in
      // Die Attrappe antwortet erst nach der Frist.
      Thread.sleep(forTimeInterval: 0.3)
      return (200, Self.itemJSON)
    }
    let outcome = await service.open(presentation, anchor: HandOffAnchor())
    guard case .handedOff = outcome else {
      Issue.record("erwartet .handedOff, erhalten \(outcome)")
      return
    }
    #expect(spy.officeURIs.isEmpty)
    #expect(spy.handOffCount == 1)
  }

  @Test("Cloud-Übergabe angenommen: Rückkehr binnen 60 s bietet Öffnen ohne AutoSpeichern an")
  func acceptedCloudOffersFallbackOnReturn() async throws {
    try markGrantAsOneDriveFolder()
    let service = makeService(username: "max@example.com") { _ in (200, Self.itemJSON) }

    let first = await service.open(presentation, anchor: HandOffAnchor())
    guard case .openedAsCloudDocument = first else {
      Issue.record("erwartet .openedAsCloudDocument, erhalten \(first)")
      return
    }
    #expect(spy.handOffCount == 0)
    let withinWindow = service.offerOpenWithoutAutoSave(now: .now.advanced(by: .seconds(30)))
    #expect(withinWindow?.locationKey == presentation.locationKey)

    // Zweiter Versuch: nach mehr als 60 s kein Angebot mehr.
    _ = await service.open(presentation, anchor: HandOffAnchor())
    #expect(service.offerOpenWithoutAutoSave(now: .now.advanced(by: .seconds(61))) == nil)
  }

  @Test("Neu verknüpfen ersetzt den Ort an allen Zuordnungen (ADR-0003)")
  func relinkReplacesAllAtOldLocation() async throws {
    let service = makeService()
    let old = reference("Arbeitsblatt Vokabeln.pdf", kind: .pdf)
    let picked = folder.appending(path: "8b/Arbeitsblatt Vokabeln neu.pdf", directoryHint: .notDirectory)

    let result = service.relink(old, toPickedFile: picked)

    let expected = MaterialReference(
      folderGrantName: "Unterricht", relativePath: "8b/Arbeitsblatt Vokabeln neu.pdf",
      displayName: "Arbeitsblatt Vokabeln neu", fileKind: .pdf)
    #expect(result == .relinked(expected))
    #expect(store.replaced.count == 1)
    #expect(store.replaced.first?.locationKey == old.locationKey)
    #expect(store.replaced.first?.reference == expected)
  }

  @Test("Neu verknüpfen mit Datei außerhalb der Freigaben: outsideGrants")
  func relinkOutsideGrants() async throws {
    let service = makeService()
    let outside = root.appending(path: "Fremd.pdf", directoryHint: .notDirectory)
    try Data("x".utf8).write(to: outside)

    let result = service.relink(reference("Arbeitsblatt Vokabeln.pdf", kind: .pdf), toPickedFile: outside)

    #expect(result == .outsideGrants)
    #expect(store.replaced.isEmpty)
  }

  @Test("withFileURL liest die Datei und schließt den Zugriff danach (Vorlage, Teilplan 07)")
  func withFileURLReadsAndCloses() async throws {
    let service = makeService()
    let openBefore = ScopedFile.openCount

    let size = try await service.withFileURL(for: reference("Arbeitsblatt Vokabeln.pdf", kind: .pdf)) {
      try Data(contentsOf: $0).count
    }

    #expect(size > 0)
    #expect(ScopedFile.openCount == openBefore)

    let unknown = MaterialReference(
      folderGrantName: "Unbekannt", relativePath: "x.pdf", displayName: "x", fileKind: .pdf)
    await #expect(throws: StorageReadError.unresolvable) {
      _ = try await service.withFileURL(for: unknown) { _ in 1 }
    }
    #expect(ScopedFile.openCount == openBefore)
  }

  @Test("Gefundene OneDrive-Kennung wird zurückgeschrieben")
  func resolvedOneDriveIDIsStored() async throws {
    try markGrantAsOneDriveFolder()
    let service = makeService(username: "max@example.com") { _ in (200, Self.itemJSON) }

    _ = await service.open(presentation, anchor: HandOffAnchor())

    let written = try #require(store.replaced.last)
    #expect(written.locationKey == presentation.locationKey)
    #expect(written.reference.oneDriveItemID == "01ABC")
    #expect(written.reference.oneDriveDriveID == "b!x")
  }

  @Test("Freigabe mit gespiegeltem Namen wird vorgeschlagen (Area ablage, zweites Gerät)")
  func suggestsMirroredGrantName() async {
    let service = makeService()
    // Keine lokale Freigabe mit diesem Namen: ein anderer Ordner, der ebenfalls „Unterricht“ heißt.
    service.removeGrant(id: grants.grants[0].id)
    store.mirroredGrantNames = ["Unterricht"]

    let suggestion = service.suggestedGrantName(for: folder)

    #expect(suggestion.name == "Unterricht")
    #expect(suggestion.matchesMirroredName)
  }
}

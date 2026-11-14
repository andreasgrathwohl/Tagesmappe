import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct OneDriveServiceTests {
  let root: URL
  let folder: URL
  let grants: FolderGrantStore

  init() throws {
    root = FileManager.default.temporaryDirectory.appending(path: "onedrive-\(UUID().uuidString)", directoryHint: .isDirectory)
    folder = root.appending(path: "Schule/Unterricht", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    try Data("x".utf8).write(to: folder.appending(path: "Vokabeln.pptx", directoryHint: .notDirectory))
    try Data("x".utf8).write(to: folder.appending(path: "Arbeitsblatt.pdf", directoryHint: .notDirectory))
    grants = FolderGrantStore(fileURL: root.appending(path: "FolderGrants.json", directoryHint: .notDirectory))
    _ = try grants.add(folderURL: folder, name: "Unterricht")
  }

  private func makeService(
    username: String?, handler: @escaping StubURLProtocol.Handler
  ) -> (OneDriveService, StubURLProtocol.Server) {
    let server = StubURLProtocol.Server(handler: handler)
    let account = MicrosoftAccount(signedInUsernameForTesting: username)
    let service = OneDriveService(
      account: account, graph: GraphClient(tokens: FakeTokens(), session: server.session),
      grants: grants, resolver: MaterialResolver(grants: grants))
    return (service, server)
  }

  @Test("Ordnererkennung: erster Kandidat fehlt, zweiter passt → oneDrivePath gesetzt")
  func detectsOneDriveFolder() async {
    let (service, _) = makeService(username: "max@example.com") { request in
      let address = request.url?.absoluteString ?? ""
      if address.contains("/root:/Schule/Unterricht:/children") {
        return (200, #"{"value":[{"name":"Vokabeln.pptx"},{"name":"Arbeitsblatt.pdf"},{"name":"Mehr.docx"}]}"#)
      }
      return (404, "{}")
    }
    await service.detectOneDriveFolders()
    #expect(grants.grant(named: "Unterricht")?.oneDrivePath == "Schule/Unterricht")
  }

  @Test("Gleicher Pfad, andere Dateien: kein OneDrive-Ordner")
  func differentChildrenAreNotMatched() async {
    let (service, _) = makeService(username: "max@example.com") { _ in
      (200, #"{"value":[{"name":"Fremd.docx"}]}"#)
    }
    await service.detectOneDriveFolders()
    #expect(grants.grant(named: "Unterricht")?.oneDrivePath == nil)
  }

  @Test("Nicht angemeldet: keine Graph-Anfrage")
  func signedOutMakesNoRequests() async throws {
    let (service, server) = makeService(username: nil) { _ in (200, "{}") }
    await service.detectOneDriveFolders()
    let reference = MaterialReference(
      folderGrantName: "Unterricht", relativePath: "Vokabeln.pptx", displayName: "Vokabeln", fileKind: .presentation,
      oneDriveItemID: "01ABC", oneDriveDriveID: "b!x")
    #expect(try await service.item(for: reference) == nil)
    #expect(server.requests.isEmpty)
  }

  @Test("Verweis ohne Kennung: Pfad der Freigabe plus relativer Pfad; zweiter Aufruf aus dem Sitzungsspeicher")
  func itemByPathIsCached() async throws {
    let (service, server) = makeService(username: "max@example.com") { _ in
      (
        200,
        #"{"id":"01ABC","name":"Vokabeln.pptx","webUrl":"https://example.com/x","parentReference":{"driveId":"b!x","driveType":"business","path":"/drive/root:/Schule/Unterricht"}}"#
      )
    }
    let grant = try #require(grants.grant(named: "Unterricht"))
    grants.setOneDrivePath(id: grant.id, "Schule/Unterricht")
    let reference = MaterialReference(
      folderGrantName: "Unterricht", relativePath: "Vokabeln.pptx", displayName: "Vokabeln", fileKind: .presentation)

    let first = try await service.item(for: reference)
    let second = try await service.item(for: reference)

    #expect(first?.id == "01ABC")
    #expect(second == first)
    #expect(server.requests.count == 1)
    #expect(
      server.requests.first?.url?.absoluteString.contains("/me/drive/root:/Schule/Unterricht/Vokabeln.pptx") == true)
  }
}

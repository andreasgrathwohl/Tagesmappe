import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@Suite struct OneDriveDataClientTests {
  private static let graph = "https://graph.microsoft.com/v1.0"

  /// Token-Lieferant, der die Zustimmung als fehlend meldet.
  private struct ConsentMissingTokens: AccessTokenProviding {
    func accessToken() async throws -> String { throw MicrosoftAccountError.interactionRequired }
  }

  private static func client(_ server: StubURLProtocol.Server) -> OneDriveDataClient {
    OneDriveDataClient(tokens: FakeTokens(), session: server.session)
  }

  private static func file(path: String, eTag: String = "\"e1\"") -> RemoteFile {
    RemoteFile(path: path, itemID: "ITEM1", eTag: eTag, size: 3, lastModified: Date(timeIntervalSince1970: 0))
  }

  @Test("App-Ordner: Kennung und Laufwerk")
  func appFolderDecodes() async throws {
    let server = StubURLProtocol.Server { _ in
      (200, #"{"id":"FOLDER1","parentReference":{"driveId":"b!drive","id":"ROOT"}}"#)
    }
    let info = try await Self.client(server).appFolder()

    #expect(info == AppFolderInfo(driveID: "b!drive", folderItemID: "FOLDER1"))
    let request = try #require(server.requests.first)
    #expect(request.url?.absoluteString == "\(Self.graph)/me/drive/special/approot?$select=id,parentReference")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
  }

  @Test("Delta: Seite mit nextLink, gelöschtes Element ohne Namen")
  func deltaDecodesPage() async throws {
    let body = """
      {"value":[
        {"id":"F1","name":"MaterialLink","parentReference":{"id":"FOLDER1"},"folder":{"childCount":1}},
        {"id":"A1","name":"x.json","parentReference":{"id":"F1"},"file":{},"eTag":"\\"e1\\"","size":12,
         "lastModifiedDateTime":"2026-11-14T08:30:00Z"},
        {"id":"A2","name":"y.json","parentReference":{"id":"F1"},"file":{},"eTag":"\\"e2\\"","size":7,
         "lastModifiedDateTime":"2026-11-14T08:30:00.123Z"},
        {"id":"D1","deleted":{"state":"deleted"}}
      ],"@odata.nextLink":"https://graph.microsoft.com/v1.0/next?token=2"}
      """
    let server = StubURLProtocol.Server { _ in (200, body) }

    let page = try await Self.client(server).delta(link: nil)

    #expect(page.nextLink == "https://graph.microsoft.com/v1.0/next?token=2")
    #expect(page.deltaLink == nil)
    #expect(page.items.count == 4)
    #expect(page.items[0].isFolder)
    #expect(page.items[1].eTag == "\"e1\"" && page.items[1].size == 12 && page.items[1].parentID == "F1")
    #expect(page.items[1].lastModified == Date(timeIntervalSince1970: 1_794_645_000))
    // Beide Datumsformen (mit und ohne Sekundenbruchteile) werden gelesen.
    #expect(page.items[2].lastModified != nil)
    #expect(page.items[3].isDeleted && page.items[3].name == nil)
    let url = try #require(server.requests.first?.url?.absoluteString)
    #expect(url.hasPrefix("\(Self.graph)/me/drive/special/approot/delta?$select=id,name,parentReference,"))
  }

  @Test("Delta mit Link fragt genau diese Adresse ab, fremde Hosts nicht")
  func deltaUsesLinkUnchanged() async throws {
    let server = StubURLProtocol.Server { _ in
      (200, #"{"value":[],"@odata.deltaLink":"https://graph.microsoft.com/v1.0/delta?token=9"}"#)
    }
    let client = Self.client(server)
    let page = try await client.delta(link: "https://graph.microsoft.com/v1.0/delta?token=8")
    #expect(page.deltaLink == "https://graph.microsoft.com/v1.0/delta?token=9")
    #expect(server.requests.first?.url?.absoluteString == "https://graph.microsoft.com/v1.0/delta?token=8")

    await #expect(throws: RemoteDataFolderError.invalidPath("https://evil.example.com/delta")) {
      _ = try await client.delta(link: "https://evil.example.com/delta")
    }
    #expect(server.requests.count == 1)
  }

  @Test("Review Focus 3: 410 wird resyncRequired")
  func goneIsResync() async throws {
    let server = StubURLProtocol.Server { _ in (410, #"{"error":{"code":"resyncRequired"}}"#) }
    await #expect(throws: RemoteDataFolderError.resyncRequired) {
      _ = try await Self.client(server).delta(link: "https://graph.microsoft.com/v1.0/delta?token=old")
    }
  }

  @Test("Review Focus 2: Hochladen sendet If-Match, 412 wird preconditionFailed")
  func uploadSendsIfMatchAndMaps412() async throws {
    let id = UUID()
    let path = RemoteLayout.recordPath(model: .materialLink, id: id)
    let ok = StubURLProtocol.Server { _ in
      (200, #"{"id":"NEW1","eTag":"\"e2\"","size":3,"lastModifiedDateTime":"2026-11-14T08:30:00Z"}"#)
    }

    let uploaded = try await Self.client(ok).upload(Data("abc".utf8), to: path, ifMatch: "\"e1\"")

    #expect(uploaded.itemID == "NEW1" && uploaded.eTag == "\"e2\"" && uploaded.path == path)
    let request = try #require(ok.requests.first)
    #expect(request.httpMethod == "PUT")
    #expect(request.url?.absoluteString == "\(Self.graph)/me/drive/special/approot:/MaterialLink/\(id.uuidString).json:/content")
    #expect(request.value(forHTTPHeaderField: "If-Match") == "\"e1\"")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "text/plain")

    let stale = StubURLProtocol.Server { _ in (412, "{}") }
    await #expect(throws: RemoteDataFolderError.preconditionFailed(path: path)) {
      _ = try await Self.client(stale).upload(Data("abc".utf8), to: path, ifMatch: "\"e1\"")
    }
  }

  @Test("Ungültiger Pfad wird nicht gesendet")
  func invalidPathIsRejectedLocally() async throws {
    let server = StubURLProtocol.Server { _ in (200, "{}") }
    let client = Self.client(server)

    await #expect(throws: RemoteDataFolderError.invalidPath("../Material/Vokabeln.pdf")) {
      _ = try await client.upload(Data(), to: "../Material/Vokabeln.pdf", ifMatch: nil)
    }
    await #expect(throws: RemoteDataFolderError.invalidPath("Fremd/notizen.txt")) {
      try await client.delete(Self.file(path: "Fremd/notizen.txt"))
    }
    #expect(server.requests.isEmpty)
  }

  @Test("Kein Netz → offline; Zustimmung fehlt → signInRequired; 429 → throttled")
  func mapsErrors() async throws {
    let offline = StubURLProtocol.Server.responding { _ in .failure(.notConnectedToInternet) }
    await #expect(throws: RemoteDataFolderError.offline) { _ = try await Self.client(offline).appFolder() }

    let lost = StubURLProtocol.Server.responding { _ in .failure(.networkConnectionLost) }
    await #expect(throws: RemoteDataFolderError.offline) { _ = try await Self.client(lost).appFolder() }

    let quiet = StubURLProtocol.Server { _ in (200, "{}") }
    let noConsent = OneDriveDataClient(tokens: ConsentMissingTokens(), session: quiet.session)
    await #expect(throws: RemoteDataFolderError.signInRequired) { _ = try await noConsent.appFolder() }
    #expect(quiet.requests.isEmpty)

    // 401 wird einmal wiederholt, dann ist eine Anmeldung nötig.
    let unauthorized = StubURLProtocol.Server { _ in (401, "{}") }
    await #expect(throws: RemoteDataFolderError.signInRequired) {
      _ = try await Self.client(unauthorized).appFolder()
    }
    #expect(unauthorized.requests.count == 2)

    let throttled = StubURLProtocol.Server.responding { _ in
      .response(status: 429, headers: ["Retry-After": "17"], body: "{}")
    }
    await #expect(throws: RemoteDataFolderError.throttled(retryAfter: 17)) {
      _ = try await Self.client(throttled).appFolder()
    }

    let busy = StubURLProtocol.Server { _ in (503, "{}") }
    await #expect(throws: RemoteDataFolderError.throttled(retryAfter: nil)) {
      _ = try await Self.client(busy).appFolder()
    }
  }

  @Test("Löschen: 404 gilt als erledigt")
  func deleteNotFoundIsDone() async throws {
    let id = UUID()
    let gone = StubURLProtocol.Server { _ in (404, "{}") }
    try await Self.client(gone).delete(Self.file(path: RemoteLayout.recordPath(model: .penNote, id: id)))

    let request = try #require(gone.requests.first)
    #expect(request.httpMethod == "DELETE")
    #expect(request.url?.absoluteString == "\(Self.graph)/me/drive/items/ITEM1")
    #expect(request.value(forHTTPHeaderField: "If-Match") == "\"e1\"")
  }

  @Test("Ordner anlegen: 409 gilt als vorhanden")
  func existingFoldersAreFine() async throws {
    let server = StubURLProtocol.Server { _ in (409, #"{"error":{"code":"nameAlreadyExists"}}"#) }
    try await Self.client(server).ensureModelFolders()
    #expect(server.requests.count == SyncModel.allCases.count)
    #expect(server.requests.allSatisfy { $0.httpMethod == "POST" })
  }

  @Test("Nur graph.microsoft.com wird angefragt (NFR-2)")
  func onlyGraphHost() async throws {
    let server = StubURLProtocol.Server { request in
      let path = request.url?.path ?? ""
      // Nur der Download (GET .../content) liefert Rohbytes; der Upload (PUT .../content) antwortet mit Item-JSON.
      if path.hasSuffix("/content") {
        if request.httpMethod == "PUT" { return (200, #"{"id":"U1","eTag":"\"e1\"","size":1}"#) }
        return (200, "abc")
      }
      return (200, #"{"id":"X1","parentReference":{"driveId":"d"},"value":[]}"#)
    }
    let client = Self.client(server)
    let id = UUID()

    _ = try await client.appFolder()
    _ = try await client.delta(link: nil)
    _ = try await client.listAll()
    _ = try await client.download(itemID: "X1")
    _ = try await client.upload(Data("a".utf8), to: RemoteLayout.recordPath(model: .lessonInfo, id: id), ifMatch: nil)
    try await client.ensureModelFolders()

    #expect(!server.requests.isEmpty)
    #expect(server.requests.allSatisfy { $0.url?.host == "graph.microsoft.com" && $0.url?.scheme == "https" })
  }
}

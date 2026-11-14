import Foundation
import Testing

@testable import Frontstage

@Suite struct GraphClientTests {
  private static let itemJSON = """
    {"id":"01ABC","name":"Vokabeln Unit 4.pptx",
     "webUrl":"https://example-my.sharepoint.com/personal/m_example_com/Documents/Unterricht/Vokabeln%20Unit%204.pptx",
     "parentReference":{"driveId":"b!x","driveType":"business","path":"/drive/root:/Unterricht"}}
    """

  @Test("Element wird decodiert und mit Bearer-Token abgefragt (FR-5.1)")
  func itemDecodesAndSendsBearer() async throws {
    let server = StubURLProtocol.Server { _ in (200, Self.itemJSON) }
    let client = GraphClient(tokens: FakeTokens(), session: server.session)

    let item = try await client.item(atRootPath: "Unterricht/Vokabeln Unit 4.pptx")

    #expect(item?.id == "01ABC")
    #expect(item?.parentReference.driveId == "b!x")
    let request = try #require(server.requests.first)
    #expect(
      request.url?.absoluteString
        == "https://graph.microsoft.com/v1.0/me/drive/root:/Unterricht/Vokabeln%20Unit%204.pptx?$select=id,name,webUrl,parentReference"
    )
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
  }

  @Test("404 ergibt nil, 500 wirft")
  func notFoundIsNilServerErrorThrows() async throws {
    let missing = StubURLProtocol.Server { _ in (404, "{}") }
    let client = GraphClient(tokens: FakeTokens(), session: missing.session)
    #expect(try await client.item(atRootPath: "Weg.pptx") == nil)
    #expect(try await client.childNames(atRootPath: "Weg") == nil)

    let broken = StubURLProtocol.Server { _ in (500, "{}") }
    let failing = GraphClient(tokens: FakeTokens(), session: broken.session)
    await #expect(throws: GraphError.httpStatus(500)) {
      _ = try await failing.item(atRootPath: "Weg.pptx")
    }
  }

  @Test("Abfrage über Laufwerks- und Elementkennung")
  func itemByIdentifiers() async throws {
    let server = StubURLProtocol.Server { _ in (200, Self.itemJSON) }
    let client = GraphClient(tokens: FakeTokens(), session: server.session)
    _ = try await client.item(driveID: "b!x", itemID: "01ABC")
    #expect(
      server.requests.first?.url?.absoluteString
        == "https://graph.microsoft.com/v1.0/drives/b%21x/items/01ABC?$select=id,name,webUrl,parentReference")
  }

  @Test("Kindernamen werden aus der Seite gelesen")
  func childNamesAreDecoded() async throws {
    let server = StubURLProtocol.Server { _ in (200, #"{"value":[{"name":"a.pdf"},{"name":"b.pptx"}]}"#) }
    let client = GraphClient(tokens: FakeTokens(), session: server.session)
    #expect(try await client.childNames(atRootPath: "Schule/Unterricht") == ["a.pdf", "b.pptx"])
    #expect(
      server.requests.first?.url?.absoluteString
        == "https://graph.microsoft.com/v1.0/me/drive/root:/Schule/Unterricht:/children?$select=name")
  }
}

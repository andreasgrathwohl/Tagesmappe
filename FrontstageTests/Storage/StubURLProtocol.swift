import Foundation

@testable import Frontstage

/// Liefert „test-token“ ohne MSAL.
struct FakeTokens: AccessTokenProviding {
  func accessToken() async throws -> String { "test-token" }
}

/// Netz-Attrappe für Graph-Tests. Jede Sitzung bekommt eine eigene Kennung (Kopfzeile `X-Stub-ID`),
/// damit parallel laufende Tests sich nicht in die Quere kommen.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
  /// Antwort der Attrappe: Status und Rumpf als JSON-Zeichenkette.
  typealias Handler = @Sendable (URLRequest) -> (status: Int, body: String)

  /// Eine Attrappe samt Aufzeichnung der eingegangenen Anfragen.
  final class Server: @unchecked Sendable {
    let id = UUID().uuidString
    let handler: Handler
    private let lock = NSLock()
    private var recorded: [URLRequest] = []

    init(handler: @escaping Handler) { self.handler = handler }

    var requests: [URLRequest] {
      lock.lock()
      defer { lock.unlock() }
      return recorded
    }

    fileprivate func record(_ request: URLRequest) {
      lock.lock()
      recorded.append(request)
      lock.unlock()
    }

    var session: URLSession {
      Registry.add(self)
      let configuration = URLSessionConfiguration.ephemeral
      configuration.protocolClasses = [StubURLProtocol.self]
      configuration.httpAdditionalHeaders = ["X-Stub-ID": id]
      return URLSession(configuration: configuration)
    }
  }

  private enum Registry {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var servers: [String: Server] = [:]

    static func add(_ server: Server) {
      lock.lock()
      servers[server.id] = server
      lock.unlock()
    }

    static func server(for request: URLRequest) -> Server? {
      guard let id = request.value(forHTTPHeaderField: "X-Stub-ID") else { return nil }
      lock.lock()
      defer { lock.unlock() }
      return servers[id]
    }
  }

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

  override func startLoading() {
    guard let server = Registry.server(for: request), let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
      return
    }
    server.record(request)
    let answer = server.handler(request)
    let response = HTTPURLResponse(url: url, statusCode: answer.status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(answer.body.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}

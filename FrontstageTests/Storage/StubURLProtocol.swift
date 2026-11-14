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

  /// Ausführliche Antwort: mit Antwortköpfen (z. B. `Retry-After`) oder als Netzfehler.
  enum Reply: Sendable {
    case response(status: Int, headers: [String: String], body: String)
    case failure(URLError.Code)
  }

  typealias Responder = @Sendable (URLRequest) -> Reply

  /// Eine Attrappe samt Aufzeichnung der eingegangenen Anfragen.
  final class Server: @unchecked Sendable {
    let id = UUID().uuidString
    let responder: Responder
    private let lock = NSLock()
    private var recorded: [URLRequest] = []

    init(handler: @escaping Handler) {
      self.responder = { request in
        let answer = handler(request)
        return .response(status: answer.status, headers: [:], body: answer.body)
      }
    }

    private init(responder: @escaping Responder) { self.responder = responder }

    /// Zweiter Weg neben `init(handler:)`: Antwortköpfe und Netzfehler. Als Fabrik statt zweitem
    /// Initialisierer, damit `Server { … }` mit nachgestelltem Abschluss eindeutig bleibt.
    static func responding(_ responder: @escaping Responder) -> Server { Server(responder: responder) }

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
    switch server.responder(request) {
    case .failure(let code):
      client?.urlProtocol(self, didFailWithError: URLError(code))
    case .response(let status, let headers, let body):
      let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)!
      client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      client?.urlProtocol(self, didLoad: Data(body.utf8))
      client?.urlProtocolDidFinishLoading(self)
    }
  }

  override func stopLoading() {}
}

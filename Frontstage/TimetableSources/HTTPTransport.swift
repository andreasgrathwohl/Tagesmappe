import Foundation

/// Dünne Schicht über dem Netz, damit die Quelle ohne echte Verbindung getestet werden kann.
protocol HTTPTransport: Sendable {
  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Standard-Umsetzung über `URLSession`.
struct URLSessionTransport: HTTPTransport {
  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
    return (data, http)
  }
}

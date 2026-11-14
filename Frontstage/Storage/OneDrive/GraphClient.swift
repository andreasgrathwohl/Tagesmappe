import Foundation
import FrontstageCore

/// Liefert ein Zugriffstoken für Microsoft Graph (still, ohne Oberfläche).
protocol AccessTokenProviding: Sendable {
  func accessToken() async throws -> String
}

enum GraphError: Error, Equatable {
  /// Ungültige Adresse oder keine HTTP-Antwort.
  case invalidResponse
  /// Unerwarteter HTTP-Status (404 wird nicht geworfen, sondern ergibt `nil`).
  case httpStatus(Int)
}

/// Schmaler Graph-Client, nur lesend (`Files.Read`). Einziger Host: `graph.microsoft.com` (NFR-2).
struct GraphClient: Sendable {
  private static let base = "https://graph.microsoft.com/v1.0"
  private let tokens: any AccessTokenProviding
  private let session: URLSession

  init(tokens: any AccessTokenProviding, session: URLSession = .shared) {
    self.tokens = tokens
    self.session = session
  }

  /// `GET /me/drive/root:/{path}`; 404 ergibt `nil`.
  func item(atRootPath path: String) async throws -> OneDriveItem? {
    let address = "\(Self.base)/me/drive/root:/\(Self.encode(path))?$select=id,name,webUrl,parentReference"
    return try await get(address, as: OneDriveItem.self)
  }

  /// `GET /drives/{driveID}/items/{itemID}`; 404 ergibt `nil`.
  func item(driveID: String, itemID: String) async throws -> OneDriveItem? {
    let address =
      "\(Self.base)/drives/\(OfficeAddress.encodeSegment(driveID))/items/\(OfficeAddress.encodeSegment(itemID))?$select=id,name,webUrl,parentReference"
    return try await get(address, as: OneDriveItem.self)
  }

  /// Namen der Kinder eines Ordners (nur die erste Seite genügt für den Vergleich); 404 ergibt `nil`.
  func childNames(atRootPath path: String) async throws -> [String]? {
    let address = "\(Self.base)/me/drive/root:/\(Self.encode(path)):/children?$select=name"
    return try await get(address, as: ChildrenPage.self)?.value.map(\.name)
  }

  // MARK: Intern

  private struct ChildrenPage: Decodable {
    struct Child: Decodable { let name: String }
    let value: [Child]
  }

  /// Je Segment kodiert (NFC), damit Leerzeichen, Umlaute und `#` im Pfad nicht die Adresse verändern.
  private static func encode(_ path: String) -> String {
    path.split(separator: "/", omittingEmptySubsequences: true)
      .map { OfficeAddress.encodeSegment(String($0)) }
      .joined(separator: "/")
  }

  private func get<Value: Decodable>(_ address: String, as type: Value.Type) async throws -> Value? {
    guard let url = URL(string: address) else { throw GraphError.invalidResponse }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(try await tokens.accessToken())", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw GraphError.invalidResponse }
    switch http.statusCode {
    case 200..<300: return try JSONDecoder().decode(Value.self, from: data)
    case 404: return nil
    default: throw GraphError.httpStatus(http.statusCode)
    }
  }
}

import Foundation
import FrontstageCore

/// Graph-Zugriff auf den App-Ordner (`/me/drive/special/approot`, Berechtigung `Files.ReadWrite`).
/// Einziger Host: `graph.microsoft.com` (NFR-2); Weiterleitungen beim Herunterladen folgt `URLSession` selbst.
///
/// Swift-Hinweis: Das Token wird pro Anfrage frisch vom `AccessTokenProviding` geholt und nie
/// gespeichert oder protokolliert.
struct OneDriveDataClient: RemoteDataFolder {
  private static let host = "graph.microsoft.com"
  private static let base = "https://graph.microsoft.com/v1.0"
  private static let approot = "\(base)/me/drive/special/approot"
  private static let itemSelect = "$select=id,name,parentReference,file,folder,deleted,eTag,size,lastModifiedDateTime"

  private let tokens: any AccessTokenProviding
  private let session: URLSession

  init(tokens: any AccessTokenProviding, session: URLSession = .shared) {
    self.tokens = tokens
    self.session = session
  }

  // MARK: RemoteDataFolder

  func appFolder() async throws -> AppFolderInfo {
    let reply = try await send(
      method: "GET", address: "\(Self.approot)?$select=id,parentReference", context: "approot")
    try Self.requireSuccess(reply)
    let item = try decode(AppFolderDTO.self, reply)
    guard let driveID = item.parentReference?.driveId else { throw RemoteDataFolderError.server(reply.status) }
    return AppFolderInfo(driveID: driveID, folderItemID: item.id)
  }

  func delta(link: String?) async throws -> DeltaPage {
    let address = link ?? "\(Self.approot)/delta?\(Self.itemSelect)"
    // Ein fremder Link darf nie mit unserem Token angefragt werden.
    guard Self.isGraphAddress(address) else { throw RemoteDataFolderError.invalidPath(address) }
    let reply = try await send(method: "GET", address: address, context: "delta")
    try Self.requireSuccess(reply)
    let page = try decode(ItemPageDTO.self, reply)
    return DeltaPage(
      items: page.value.map(\.remoteItem), nextLink: page.nextLink, deltaLink: page.deltaLink)
  }

  func listAll() async throws -> [RemoteItem] {
    var result = try await collectChildren("\(Self.approot)/children?\(Self.itemSelect)", missingIsEmpty: false)
    for model in SyncModel.allCases {
      let address =
        "\(Self.approot):/\(OfficeAddress.encodeSegment(model.rawValue)):/children?\(Self.itemSelect)&$top=200"
      // Ein Modellordner, der noch nicht existiert, ist einfach leer.
      result += try await collectChildren(address, missingIsEmpty: true)
    }
    return result
  }

  func download(itemID: String) async throws -> Data {
    let address = "\(Self.base)/me/drive/items/\(OfficeAddress.encodeSegment(itemID))/content"
    let reply = try await send(method: "GET", address: address, context: itemID)
    try Self.requireSuccess(reply)
    return reply.data
  }

  func upload(_ data: Data, to path: String, ifMatch: String?) async throws -> RemoteFile {
    guard Self.isWritablePath(path) else { throw RemoteDataFolderError.invalidPath(path) }
    let address = "\(Self.approot):/\(Self.encode(path)):/content"
    var headers = ["Content-Type": "text/plain"]  // laut Referenz Pflicht
    if let ifMatch { headers["If-Match"] = ifMatch }
    let reply = try await send(method: "PUT", address: address, headers: headers, body: data, context: path)
    try Self.requireSuccess(reply)
    let item = try decode(ItemDTO.self, reply)
    return RemoteFile(
      path: path, itemID: item.id, eTag: item.eTag ?? "", size: item.size ?? data.count,
      lastModified: Self.parseDate(item.lastModifiedDateTime) ?? Date())
  }

  func delete(_ file: RemoteFile) async throws {
    guard Self.isWritablePath(file.path) else { throw RemoteDataFolderError.invalidPath(file.path) }
    let address = "\(Self.base)/me/drive/items/\(OfficeAddress.encodeSegment(file.itemID))"
    var headers: [String: String] = [:]
    if !file.eTag.isEmpty { headers["If-Match"] = file.eTag }
    let reply = try await send(method: "DELETE", address: address, headers: headers, context: file.path)
    if reply.status == 404 { return }  // schon weg = erledigt
    try Self.requireSuccess(reply)
  }

  func ensureModelFolders() async throws {
    for model in SyncModel.allCases {
      let body = Data(
        #"{"name":"\#(model.rawValue)","folder":{},"@microsoft.graph.conflictBehavior":"fail"}"#.utf8)
      let reply = try await send(
        method: "POST", address: "\(Self.approot)/children",
        headers: ["Content-Type": "application/json"], body: body, context: model.rawValue)
      if reply.status == 409 { continue }  // Ordner existiert schon
      try Self.requireSuccess(reply)
    }
  }

  // MARK: Anfragen

  private struct Reply {
    let data: Data
    let status: Int
  }

  /// Sendet eine Anfrage und bildet Netz-, Anmelde-, Drossel-, 410- und 412-Fehler ab. Alle anderen
  /// Status gibt sie zurück; die Aufrufer entscheiden (z. B. 404, 409).
  private func send(
    method: String, address: String, headers: [String: String] = [:], body: Data? = nil, context: String
  ) async throws -> Reply {
    guard let url = URL(string: address) else { throw RemoteDataFolderError.invalidPath(address) }
    var renewed = false
    while true {
      var request = URLRequest(url: url)
      request.httpMethod = method
      request.setValue("Bearer \(try await token())", forHTTPHeaderField: "Authorization")
      request.setValue("application/json", forHTTPHeaderField: "Accept")
      for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
      request.httpBody = body

      let data: Data
      let response: URLResponse
      do {
        (data, response) = try await session.data(for: request)
      } catch let error as URLError where error.code.meansOffline {
        throw RemoteDataFolderError.offline
      }
      guard let http = response as? HTTPURLResponse else { throw RemoteDataFolderError.server(0) }

      switch http.statusCode {
      case 401:
        // Einmal mit neu geholtem Token wiederholen, danach ist eine Anmeldung nötig.
        if renewed { throw RemoteDataFolderError.signInRequired }
        renewed = true
      case 410:
        throw RemoteDataFolderError.resyncRequired
      case 412:
        throw RemoteDataFolderError.preconditionFailed(path: context)
      case 429, 503:
        let retry = http.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
        throw RemoteDataFolderError.throttled(retryAfter: retry)
      default:
        return Reply(data: data, status: http.statusCode)
      }
    }
  }

  private func token() async throws -> String {
    do {
      return try await tokens.accessToken()
    } catch MicrosoftAccountError.interactionRequired {
      throw RemoteDataFolderError.signInRequired
    } catch MicrosoftAccountError.offline {
      // Stilles Erneuern des Tokens ohne Netz: wie jede andere Anfrage ohne Netz „offline“, nicht „fehlgeschlagen“.
      throw RemoteDataFolderError.offline
    }
  }

  private static func requireSuccess(_ reply: Reply) throws {
    guard (200..<300).contains(reply.status) else { throw RemoteDataFolderError.server(reply.status) }
  }

  /// Sammelt alle Seiten einer children-Aufzählung über `@odata.nextLink`.
  private func collectChildren(_ firstAddress: String, missingIsEmpty: Bool) async throws -> [RemoteItem] {
    var items: [RemoteItem] = []
    var address: String? = firstAddress
    while let current = address {
      guard Self.isGraphAddress(current) else { throw RemoteDataFolderError.invalidPath(current) }
      let reply = try await send(method: "GET", address: current, context: "children")
      if reply.status == 404 && missingIsEmpty { return items }
      try Self.requireSuccess(reply)
      let page = try decode(ItemPageDTO.self, reply)
      items += page.value.map(\.remoteItem)
      address = page.nextLink
    }
    return items
  }

  // MARK: Pfade und Adressen

  /// Je Segment kodiert (NFC), damit Leerzeichen, Umlaute und `#` die Adresse nicht verändern.
  private static func encode(_ path: String) -> String {
    path.split(separator: "/", omittingEmptySubsequences: true)
      .map { OfficeAddress.encodeSegment(String($0)) }
      .joined(separator: "/")
  }

  /// Schreibend angefasst wird nur, was das Layout des Datenordners kennt.
  private static func isWritablePath(_ path: String) -> Bool {
    path == RemoteLayout.libraryPath || RemoteLayout.isValidPath(path)
  }

  private static func isGraphAddress(_ address: String) -> Bool {
    guard let url = URL(string: address) else { return false }
    return url.scheme == "https" && url.host?.lowercased() == host
  }

  // MARK: Antworten lesen

  private func decode<Value: Decodable>(_ type: Value.Type, _ reply: Reply) throws -> Value {
    do {
      return try JSONDecoder().decode(Value.self, from: reply.data)
    } catch {
      throw RemoteDataFolderError.server(reply.status)
    }
  }

  /// Graph liefert `lastModifiedDateTime` mal mit, mal ohne Sekundenbruchteile.
  fileprivate static func parseDate(_ text: String?) -> Date? {
    guard let text else { return nil }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    if let date = plain.date(from: text) { return date }
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: text)
  }
}

extension URLError.Code {
  /// Fehler, hinter denen fehlendes oder gestörtes Netz steckt; der Abgleich meldet dann „offline“ statt
  /// „fehlgeschlagen“ (Zeitüberschreitung, Name nicht auflösbar, Mobilfunkdaten gesperrt …).
  var meansOffline: Bool {
    switch self {
    case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
      .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
      true
    default:
      false
    }
  }
}

// MARK: - Graph-Antworten (nur die benötigten Felder)

/// Leeres Objekt: zählt nur, ob der Schlüssel (`file`, `folder`, `deleted`) vorhanden ist.
private struct GraphMarker: Decodable {}

private struct ParentDTO: Decodable {
  let id: String?
  let driveId: String?
}

private struct AppFolderDTO: Decodable {
  let id: String
  let parentReference: ParentDTO?
}

private struct ItemDTO: Decodable {
  let id: String
  let name: String?
  let parentReference: ParentDTO?
  let file: GraphMarker?
  let folder: GraphMarker?
  let deleted: GraphMarker?
  let eTag: String?
  let size: Int?
  let lastModifiedDateTime: String?

  var remoteItem: RemoteItem {
    RemoteItem(
      id: id, name: name, parentID: parentReference?.id, isFolder: folder != nil,
      isDeleted: deleted != nil, eTag: eTag, size: size,
      lastModified: OneDriveDataClient.parseDate(lastModifiedDateTime))
  }
}

private struct ItemPageDTO: Decodable {
  let value: [ItemDTO]
  let nextLink: String?
  let deltaLink: String?

  enum CodingKeys: String, CodingKey {
    case value
    case nextLink = "@odata.nextLink"
    case deltaLink = "@odata.deltaLink"
  }
}

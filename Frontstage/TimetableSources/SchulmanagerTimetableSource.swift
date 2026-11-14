import Foundation
import FrontstageCore

/// Stundenplan-Quelle „Schulmanager Online“. Inoffizielle Anbindung, ohne Gewähr (FR-13.1, ADR-0004).
///
/// Ablauf je Abfrage: Zugangsdaten laden → Salt holen → Passwort-Hash → Anmeldung → ein Sammelaufruf
/// (Stunden und Stundenzeiten) → Auswerten. Entweder entsteht ein vollständiger `SourceSnapshot`, oder es wird
/// ein Fehler geworfen – nie ein halbes Ergebnis. Das Sitzungs-Token (JWT) lebt nur als lokale Variable.
struct SchulmanagerTimetableSource: TimetableSource {
  private let credentials: any CredentialStore
  private let transport: any HTTPTransport
  private let shape: SchulmanagerAPIShape

  init(
    credentials: any CredentialStore,
    transport: any HTTPTransport = URLSessionTransport(),
    shape: SchulmanagerAPIShape = .recorded
  ) {
    self.credentials = credentials
    self.transport = transport
    self.shape = shape
  }

  var kind: TimetableSourceKind { .schulmanager }

  func fetch(range: ClosedRange<CalendarDay>, existing: Timetable?, now: Date) async throws
    -> SourceSnapshot?
  {
    guard let stored = try credentials.load() else { throw TimetableSourceError.notConfigured }

    // 1. Salt
    let saltData = try await post(
      path: shape.saltPath, body: SchulmanagerRequestBuilder.saltBody(username: stored.username),
      token: nil, unauthorizedIsInvalidCredentials: true)
    let salt = try SchulmanagerResponseParser.salt(from: saltData)

    // 2. Anmeldung (Passwort nur in diesem Body)
    let hash = SchulmanagerPasswordHash.make(password: stored.password, salt: salt)
    let loginData = try await post(
      path: shape.loginPath,
      body: SchulmanagerRequestBuilder.loginBody(
        username: stored.username, password: stored.password, hash: hash),
      token: nil, unauthorizedIsInvalidCredentials: true)
    let login = try SchulmanagerResponseParser.login(from: loginData, shape: shape)

    // 3. Ein Sammelaufruf: [0] Stunden, [1] Stundenzeiten
    let callsData = try await post(
      path: shape.callsPath,
      body: SchulmanagerRequestBuilder.callsBody(shape: shape, login: login, range: range),
      token: login.jwt, unauthorizedIsInvalidCredentials: false)

    // 4. Auswerten – jeder Fehler bricht ab, bevor etwas weitergereicht wird.
    let lessons = try SchulmanagerResponseParser.lessons(fromCalls: callsData, at: 0)
    let bellSchedule = try SchulmanagerResponseParser.bellSchedule(fromCalls: callsData, at: 1)
    let timetable = SchulmanagerTimetableDeriver.derive(
      lessons: lessons, teacherID: login.teacherID, existing: existing)
    let changes = SchulmanagerChangeExtractor.changes(in: lessons, teacherID: login.teacherID)
    return SourceSnapshot(
      kind: .schulmanager, fetchedAt: now, range: range, timetable: timetable,
      bellSchedule: bellSchedule, changes: changes)
  }

  // MARK: - HTTP

  private func post(
    path: String, body: Data, token: String?, unauthorizedIsInvalidCredentials: Bool
  ) async throws -> Data {
    var components = URLComponents()
    components.scheme = "https"
    components.host = shape.host
    components.path = path
    guard let url = components.url else {
      throw TimetableSourceError.unexpectedResponse("Adresse ungültig")
    }
    var request = URLRequest(url: url, timeoutInterval: 15)
    request.httpMethod = "POST"
    request.httpBody = body
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
    if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

    let result: (Data, HTTPURLResponse)
    do {
      result = try await transport.send(request)
    } catch let error as URLError {
      switch error.code {
      case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost:
        throw TimetableSourceError.offline
      default:
        // Nur der Code, keine URL und kein Body (könnten Kennungen enthalten).
        throw TimetableSourceError.unexpectedResponse("Netzwerkfehler \(error.code.rawValue)")
      }
    }
    let (data, response) = result
    switch response.statusCode {
    case 200..<300: return data
    case 401 where unauthorizedIsInvalidCredentials: throw TimetableSourceError.invalidCredentials
    default: throw TimetableSourceError.server(status: response.statusCode)
    }
  }

  /// Beschreibender User-Agent (Empfehlung der Codeberg-Quelle zur inoffiziellen Schnittstelle).
  private static var userAgent: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    return "Frontstage/\(version) (inoffizielle Anbindung)"
  }
}

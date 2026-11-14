import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Merkt sich die Anfragen und liefert vorbereitete Antworten der Reihe nach.
private actor FakeTransport: HTTPTransport {
  enum Reply {
    case body(String, status: Int = 200)
    case failure(URLError.Code)
  }

  private var replies: [Reply]
  private(set) var requests: [URLRequest] = []

  init(_ replies: [Reply]) { self.replies = replies }

  func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    requests.append(request)
    guard !replies.isEmpty else { throw URLError(.cannotConnectToHost) }
    switch replies.removeFirst() {
    case .failure(let code):
      throw URLError(code)
    case .body(let text, let status):
      guard let url = request.url,
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
      else { throw URLError(.badURL) }
      return (Data(text.utf8), response)
    }
  }
}

/// Zugangsdaten im Speicher – der Schlüsselbund wird hier nicht gebraucht.
private struct FixedCredentialStore: CredentialStore {
  var value: SchulmanagerCredentials?
  func load() throws -> SchulmanagerCredentials? { value }
  func save(_ credentials: SchulmanagerCredentials) throws {}
  func delete() throws {}
}

@Suite("SchulmanagerTimetableSource")
struct SchulmanagerTimetableSourceTests {
  // Erfundene Werte; Test-Form statt `.recorded` (Lehrer-Objekt unter `user.associatedTeacher`).
  private let shape = SchulmanagerAPIShape(
    host: "login.schulmanager-online.de", saltPath: "/api/get-salt", loginPath: "/api/login",
    callsPath: "/api/calls", teacherObjectPath: ["user", "associatedTeacher"], teacherIDPath: ["id"],
    lessonsModule: "schedules", lessonsEndpoint: "get-actual-lessons",
    teacherParameterKey: "teacher", passesWholeTeacherObject: true,
    classHoursModule: "schedules", classHoursEndpoint: "get-class-hours",
    classHoursParameters: ["scope": .string("all")], bundleVersion: nil)

  private let credentials = FixedCredentialStore(
    value: SchulmanagerCredentials(username: "max@example.com", password: "Beispiel-Passwort-1"))

  private let range = CalendarDay(year: 2026, month: 11, day: 16)...CalendarDay(year: 2026, month: 12, day: 13)

  private let saltReply = FakeTransport.Reply.body("\"beispielsalz\"")
  private let loginReply = FakeTransport.Reply.body(
    #"{"jwt":"jwt-beispiel","user":{"id":"U-1","associatedTeacher":{"id":"T-100"}}}"#)

  private func element(_ date: String, _ period: Int, _ className: String, _ subject: String) -> String {
    """
    {"date":"\(date)","classHour":{"number":\(period)},"type":"regularLesson",
     "actualLesson":{"subject":{"name":"\(subject)"},"teachers":[{"id":"T-100"}],"classes":[{"name":"\(className)"}],"studentGroups":[]},
     "originalLessons":[],"isCancelled":false,"isSubstitution":false,"isNew":false}
    """
  }

  /// Zwei gleiche Wochen (ab 2026-11-16 und 2026-11-23) mit je drei Stunden – AK-3: drei Einträge, keine Varianten.
  private var callsReply: FakeTransport.Reply {
    let elements = [
      element("2026-11-17", 2, "8b", "Englisch"), element("2026-11-18", 4, "7a", "Deutsch"),
      element("2026-11-20", 2, "8a", "Englisch"), element("2026-11-24", 2, "8b", "Englisch"),
      element("2026-11-25", 4, "7a", "Deutsch"), element("2026-11-27", 2, "8a", "Englisch"),
    ]
    let classHours =
      #"[{"number":1,"from":"08:00:00","until":"08:45:00"},{"number":2,"from":"08:50:00","until":"09:35:00"}]"#
    return .body(
      """
      {"results":[{"status":200,"data":[\(elements.joined(separator: ","))]},{"status":200,"data":\(classHours)}]}
      """)
  }

  private func source(_ transport: FakeTransport, credentials: FixedCredentialStore? = nil)
    -> SchulmanagerTimetableSource
  {
    SchulmanagerTimetableSource(
      credentials: credentials ?? self.credentials, transport: transport, shape: shape)
  }

  private func fetch(_ source: SchulmanagerTimetableSource) async throws -> SourceSnapshot? {
    try await source.fetch(range: range, existing: nil, now: Date(timeIntervalSince1970: 0))
  }

  @Test("Anmeldung sendet den Hash, Abfrage nutzt das Bearer-Token")
  func loginSendsHashAndUsesBearerToken() async throws {
    let transport = FakeTransport([saltReply, loginReply, callsReply])
    _ = try await fetch(source(transport))
    let requests = await transport.requests
    #expect(requests.count == 3)
    let loginBody = try #require(requests[1].httpBody)
    let login = try #require(try JSONSerialization.jsonObject(with: loginBody) as? [String: Any])
    let hash = try #require(login["hash"] as? String)
    #expect(hash.hasPrefix("f82673fd3caf5e8cb13026c51bd8746d"))
    #expect(requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer jwt-beispiel")
    #expect(requests[0].value(forHTTPHeaderField: "Authorization") == nil)
    // Das Token steht nie im Body.
    let callsBody = String(decoding: try #require(requests[2].httpBody), as: UTF8.self)
    #expect(!callsBody.contains("jwt-beispiel"))
  }

  @Test("Nur Schulmanager wird angesprochen (NFR-2, AK-18)")
  func allRequestsGoOnlyToSchulmanagerHost() async throws {
    let transport = FakeTransport([saltReply, loginReply, callsReply])
    _ = try await fetch(source(transport))
    let requests = await transport.requests
    #expect(requests.count == 3)
    for request in requests {
      #expect(request.url?.scheme == "https")
      #expect(request.url?.host == "login.schulmanager-online.de")
      #expect(request.httpMethod == "POST")
      #expect(request.timeoutInterval == 15)
      #expect(request.value(forHTTPHeaderField: "User-Agent")?.contains("inoffizielle Anbindung") == true)
    }
  }

  @Test("Import aus dem Testkonto (AK-3)")
  func fetchProducesSnapshotWithThreeEntries() async throws {
    let transport = FakeTransport([saltReply, loginReply, callsReply])
    let snapshot = try #require(try await fetch(source(transport)))
    #expect(snapshot.kind == .schulmanager)
    guard case .derived(let timetable) = snapshot.timetable else {
      Issue.record("Stundenplan nicht abgeleitet")
      return
    }
    #expect(timetable.entries.count == 3)
    #expect(try #require(snapshot.bellSchedule).periods.count == 2)
  }

  @Test("Leere Stundenzeiten: der Stand trägt kein Zeitraster (Q-16)")
  func emptyClassHoursYieldNoBellSchedule() async throws {
    let calls = FakeTransport.Reply.body(
      """
      {"results":[{"status":200,"data":[\(element("2026-11-17", 2, "8b", "Englisch"))]},{"status":200,"data":[]}]}
      """)
    let transport = FakeTransport([saltReply, loginReply, calls])
    let snapshot = try #require(try await fetch(source(transport)))
    #expect(snapshot.bellSchedule == nil)
  }

  @Test("Ohne Zugangsdaten: nicht eingerichtet, kein Netzzugriff")
  func missingCredentialsIsNotConfigured() async throws {
    let transport = FakeTransport([])
    await #expect(throws: TimetableSourceError.notConfigured) {
      _ = try await fetch(source(transport, credentials: FixedCredentialStore(value: nil)))
    }
    #expect(await transport.requests.isEmpty)
  }

  @Test("Falsches Passwort: keine Abfrage nach der Anmeldung")
  func wrongPasswordIsInvalidCredentials() async throws {
    let transport = FakeTransport([saltReply, .body("{}", status: 401)])
    await #expect(throws: TimetableSourceError.invalidCredentials) {
      _ = try await fetch(source(transport))
    }
    #expect(await transport.requests.count == 2)
  }

  @Test("Kein Netz wird als offline gemeldet")
  func offlineIsOffline() async throws {
    let transport = FakeTransport([.failure(.notConnectedToInternet)])
    await #expect(throws: TimetableSourceError.offline) {
      _ = try await fetch(source(transport))
    }
  }

  @Test("Serverfehler bei der Abfrage")
  func serverErrorIsServer() async throws {
    let transport = FakeTransport([saltReply, loginReply, .body("{}", status: 503)])
    await #expect(throws: TimetableSourceError.server(status: 503)) {
      _ = try await fetch(source(transport))
    }
  }

  @Test("Teilantwort mit Status 500: kein halber Import")
  func nonOkSubResultThrowsInsteadOfPartialSnapshot() async throws {
    let broken = FakeTransport.Reply.body(
      #"{"results":[{"status":200,"data":[]},{"status":500,"data":null}]}"#)
    let transport = FakeTransport([saltReply, loginReply, broken])
    await #expect(throws: TimetableSourceError.self) {
      _ = try await fetch(source(transport))
    }
  }
}

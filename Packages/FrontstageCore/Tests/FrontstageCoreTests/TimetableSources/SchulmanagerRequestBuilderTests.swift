import Foundation
import Testing

@testable import FrontstageCore

@Suite("SchulmanagerRequestBuilder")
struct SchulmanagerRequestBuilderTests {
  private typealias F = SchulmanagerFixtures

  private func login() -> SchulmanagerLogin {
    SchulmanagerLogin(
      jwt: "jwt-beispiel", teacherObject: .object(["id": .string("T-100")]), teacherID: "T-100")
  }

  private func decode(_ data: Data) throws -> JSONValue {
    try JSONDecoder().decode(JSONValue.self, from: data)
  }

  @Test func saltBodyFields() throws {
    let body = try decode(SchulmanagerRequestBuilder.saltBody(username: "max@example.com"))
    #expect(body[["emailOrUsername"]] == .string("max@example.com"))
    #expect(body[["mobileApp"]] == .bool(false))
    #expect(body[["institutionId"]] == .null)
  }

  @Test func loginBodyFields() throws {
    let body = try decode(
      SchulmanagerRequestBuilder.loginBody(
        username: "max@example.com", password: "pw-beispiel", hash: "abcdef"))
    #expect(body[["emailOrUsername"]] == .string("max@example.com"))
    #expect(body[["password"]] == .string("pw-beispiel"))
    #expect(body[["hash"]] == .string("abcdef"))
    #expect(body[["mobileApp"]] == .bool(false))
    #expect(body[["institutionId"]] == .null)
  }

  @Test func callsBodyHasTwoRequestsAndRange() throws {
    let data = try SchulmanagerRequestBuilder.callsBody(
      shape: F.shape, login: login(), range: d(2026, 11, 16)...d(2026, 12, 13))
    let body = try decode(data)
    guard case .array(let requests)? = body[["requests"]] else {
      Issue.record("requests fehlt")
      return
    }
    #expect(requests.count == 2)
    #expect(requests[0][["moduleName"]] == .string("schedules"))
    #expect(requests[0][["endpointName"]] == .string("get-actual-lessons"))
    #expect(requests[0][["parameters", "start"]] == .string("2026-11-16"))
    #expect(requests[0][["parameters", "end"]] == .string("2026-12-13"))
    #expect(requests[0][["parameters", "teacher", "id"]] == .string("T-100"))
    #expect(requests[1][["endpointName"]] == .string("get-class-hours"))
    #expect(requests[1][["parameters", "scope"]] == .string("all"))
    #expect(body[["bundleVersion"]] == nil)
  }

  @Test func callsBodyIncludesBundleVersionWhenKnown() throws {
    var shape = F.shape
    shape.bundleVersion = "bv-beispiel"
    let body = try decode(
      SchulmanagerRequestBuilder.callsBody(
        shape: shape, login: login(), range: d(2026, 11, 16)...d(2026, 11, 20)))
    #expect(body[["bundleVersion"]] == .string("bv-beispiel"))
  }

  @Test func callsBodyCanPassOnlyTheTeacherID() throws {
    var shape = F.shape
    shape.passesWholeTeacherObject = false
    let body = try decode(
      SchulmanagerRequestBuilder.callsBody(
        shape: shape, login: login(), range: d(2026, 11, 16)...d(2026, 11, 20)))
    guard case .array(let requests)? = body[["requests"]] else {
      Issue.record("requests fehlt")
      return
    }
    #expect(requests[0][["parameters", "teacher"]] == .string("T-100"))
  }

  @Test func callsBodyNeverContainsTheToken() throws {
    let data = try SchulmanagerRequestBuilder.callsBody(
      shape: F.shape, login: login(), range: d(2026, 11, 16)...d(2026, 11, 20))
    #expect(!String(decoding: data, as: UTF8.self).contains("jwt-beispiel"))
  }

  @Test func recordedShapeUsesOnlyTheSingleHost() {
    #expect(SchulmanagerAPIShape.recorded.host == "login.schulmanager-online.de")
    for path in [
      SchulmanagerAPIShape.recorded.saltPath, SchulmanagerAPIShape.recorded.loginPath,
      SchulmanagerAPIShape.recorded.callsPath,
    ] {
      #expect(path.hasPrefix("/api/"))
    }
  }
}

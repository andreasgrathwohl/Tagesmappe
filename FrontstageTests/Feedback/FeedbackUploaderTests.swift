import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Zählt Aufrufe und sammelt Werte aus `@Sendable`-Abschlüssen.
private final class Recorder<Value: Sendable>: @unchecked Sendable {
  private let lock = NSLock()
  private var values: [Value] = []

  func add(_ value: Value) -> Int {
    lock.lock()
    defer { lock.unlock() }
    values.append(value)
    return values.count
  }

  var all: [Value] {
    lock.lock()
    defer { lock.unlock() }
    return values
  }
}

@Suite struct FeedbackUploaderTests {
  private let endpoint = FeedbackServiceEndpoint.resolve("https://feedback.kunde.de")!
  private let receiptID = UUID()

  private var receiptBody: String { "{\"id\":\"\(receiptID.uuidString)\",\"reference\":\"AB12CD34\"}" }

  private func makePayload() -> FeedbackUploadPayload {
    var draft = FeedbackDraft(kind: .idea, topic: nil)
    draft.text = "Beispieltext"
    return FeedbackUploadPayload(draftID: draft.id, draft: draft, deviceInfo: nil, appVersion: "0.1.0 (1)")
  }

  private func upload(
    _ server: StubURLProtocol.Server, sleeps: Recorder<Double> = Recorder(),
    progress: @escaping @Sendable (Double) -> Void = { _ in }
  ) async throws(FeedbackUploadError) -> FeedbackUploadReceipt {
    let uploader = FeedbackUploader(session: server.session, sleep: { _ = sleeps.add($0) })
    return try await uploader.upload(
      payload: makePayload(), attachments: [("Bildschirmfoto-1.jpg", Data([1, 2, 3]))], to: endpoint,
      appKey: "test-key", progress: progress)
  }

  @Test("Vertrag: Methode, Pfad, Header, Teile")
  func sendsContract() async throws {
    let server = StubURLProtocol.Server { _ in (201, receiptBody) }
    _ = try await upload(server)
    let request = try #require(server.requests.first)
    #expect(request.httpMethod == "POST")
    #expect(request.url?.absoluteString == "https://feedback.kunde.de/api/v1/feedback")
    #expect(request.value(forHTTPHeaderField: "X-Frontstage-App-Key") == "test-key")
    let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
    #expect(contentType.hasPrefix("multipart/form-data; boundary="))
    #expect(request.timeoutInterval == 60)

    // Der Rumpf eines Upload-Tasks ist in der Attrappe nicht sichtbar; die Teile prüft `multipartBody` direkt.
    let json = Data("{\"a\":1}".utf8)
    let body = FeedbackUploader.multipartBody(
      boundary: "BOUND", json: json,
      attachments: [("Bildschirmfoto-1.jpg", Data([9])), ("Bildschirmfoto-2.jpg", Data([8]))])
    let text = String(decoding: body, as: UTF8.self)
    #expect(text.contains("--BOUND\r\nContent-Disposition: form-data; name=\"feedback\"\r\nContent-Type: application/json\r\n\r\n{\"a\":1}\r\n"))
    #expect(text.contains("name=\"attachment\"; filename=\"Bildschirmfoto-1.jpg\"\r\nContent-Type: image/jpeg"))
    #expect(text.contains("name=\"attachment\"; filename=\"Bildschirmfoto-2.jpg\"\r\nContent-Type: image/jpeg"))
    #expect(text.hasSuffix("--BOUND--\r\n"))
    #expect(text.components(separatedBy: "name=\"attachment\"").count == 3)
  }

  @Test("201 → Quittung")
  func returnsReceipt() async throws {
    let server = StubURLProtocol.Server { _ in (201, receiptBody) }
    let receipt = try await upload(server)
    #expect(receipt.id == receiptID)
    #expect(receipt.reference == "AB12CD34")
  }

  @Test("Review 3: 503, 503, 503 → unavailable nach drei Versuchen")
  func retriesServerErrorsThenFails() async {
    let server = StubURLProtocol.Server { _ in (503, "") }
    let sleeps = Recorder<Double>()
    do {
      _ = try await upload(server, sleeps: sleeps)
      Issue.record("Erwartet: unavailable")
    } catch {
      #expect(error == .unavailable)
    }
    #expect(server.requests.count == 3)
    #expect(sleeps.all == [1, 4])
  }

  @Test("503 dann 201 → Erfolg")
  func retrySucceeds() async throws {
    let calls = Recorder<Int>()
    let body = receiptBody
    let server = StubURLProtocol.Server { _ in calls.add(0) == 1 ? (503, "") : (201, body) }
    let receipt = try await upload(server)
    #expect(receipt.id == receiptID)
    #expect(server.requests.count == 2)
  }

  @Test("Review 3: 401/413/422 sofort endgültig, ein Versuch")
  func doesNotRetryClientErrors() async {
    for code in [401, 413, 415, 422] {
      let server = StubURLProtocol.Server { _ in (code, "") }
      do {
        _ = try await upload(server)
        Issue.record("Erwartet: rejected \(code)")
      } catch {
        #expect(error == .rejected(statusCode: code))
      }
      #expect(server.requests.count == 1)
    }
  }

  @Test("429 → rateLimited")
  func rateLimited() async {
    let server = StubURLProtocol.Server { _ in (429, "") }
    do {
      _ = try await upload(server)
      Issue.record("Erwartet: rateLimited")
    } catch {
      #expect(error == .rateLimited)
    }
    #expect(server.requests.count == 1)
  }

  @Test("Fortschritt endet bei 1")
  func reportsProgress() async throws {
    let server = StubURLProtocol.Server { _ in (201, receiptBody) }
    let values = Recorder<Double>()
    _ = try await upload(server, progress: { _ = values.add($0) })
    #expect(values.all.last == 1)
  }
}

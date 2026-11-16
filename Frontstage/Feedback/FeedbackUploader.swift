import Foundation
import FrontstageCore

enum FeedbackUploadError: Error, Equatable {
  /// 401, 413, 415, 422 und alle übrigen 4xx – endgültig.
  case rejected(statusCode: Int)
  /// 429.
  case rateLimited
  /// Netz oder 5xx nach allen Versuchen.
  case unavailable
  case invalidResponse
}

/// Lädt eine Rückmeldung als Multipart hoch (Entscheidungen 16 und 17) und meldet den Fortschritt 0...1.
///
/// Swift-Hinweis: `Sendable` ohne Zusatz genügt, weil beide Eigenschaften unveränderlich und selbst `Sendable`
/// sind. `async throws(FeedbackUploadError)` ist ein getypter Fehlerwurf: der Aufrufer fängt den Fehler
/// ohne Umweg über `any Error`.
final class FeedbackUploader: Sendable {
  private let session: URLSession
  private let sleep: @Sendable (Double) async -> Void

  init(
    session: URLSession = .shared,
    sleep: @escaping @Sendable (Double) async -> Void = { seconds in
      _ = try? await Task.sleep(for: .seconds(seconds))
    }
  ) {
    self.session = session
    self.sleep = sleep
  }

  private enum Outcome {
    case receipt(FeedbackUploadReceipt)
    case status(Int)
    case network
    case invalid
  }

  func upload(
    payload: FeedbackUploadPayload, attachments: [(fileName: String, data: Data)], to endpoint: FeedbackServiceEndpoint,
    appKey: String, progress: @escaping @Sendable (Double) -> Void
  ) async throws(FeedbackUploadError) -> FeedbackUploadReceipt {
    guard let json = try? payload.jsonData() else { throw .invalidResponse }
    let boundary = "Frontstage-\(UUID().uuidString)"
    let body = Self.multipartBody(boundary: boundary, json: json, attachments: attachments)

    var request = URLRequest(url: endpoint.feedbackURL)
    request.httpMethod = "POST"
    request.timeoutInterval = 60
    request.setValue(appKey, forHTTPHeaderField: "X-Frontstage-App-Key")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

    for attempt in 0..<FeedbackRetryPolicy.maxAttempts {
      switch await send(request, body: body, progress: progress) {
      case .receipt(let receipt):
        progress(1)
        return receipt
      case .invalid:
        throw .invalidResponse
      case .status(let code):
        if code == 429 { throw .rateLimited }
        guard FeedbackRetryPolicy.shouldRetry(statusCode: code) else { throw .rejected(statusCode: code) }
      case .network:
        // Ein abgebrochener Auftrag wird nicht wiederholt.
        if Task.isCancelled { throw .unavailable }
      }
      if attempt + 1 < FeedbackRetryPolicy.maxAttempts {
        await sleep(FeedbackRetryPolicy.delays[min(attempt, FeedbackRetryPolicy.delays.count - 1)])
      }
    }
    throw .unavailable
  }

  private func send(_ request: URLRequest, body: Data, progress: @escaping @Sendable (Double) -> Void) async -> Outcome {
    do {
      let (data, response) = try await session.upload(
        for: request, from: body, delegate: ProgressDelegate(progress: progress))
      guard let http = response as? HTTPURLResponse else { return .invalid }
      guard http.statusCode == 200 || http.statusCode == 201 else { return .status(http.statusCode) }
      guard let receipt = try? JSONDecoder().decode(FeedbackUploadReceipt.self, from: data) else { return .invalid }
      return .receipt(receipt)
    } catch {
      return .network
    }
  }

  /// Rumpf nach Vertrag: Teil `feedback` (JSON), dann je Bild ein Teil `attachment` (JPEG).
  static func multipartBody(boundary: String, json: Data, attachments: [(fileName: String, data: Data)]) -> Data {
    var body = Data()
    func append(_ text: String) { body.append(Data(text.utf8)) }

    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"feedback\"\r\n")
    append("Content-Type: application/json\r\n\r\n")
    body.append(json)
    append("\r\n")
    for attachment in attachments {
      append("--\(boundary)\r\n")
      append("Content-Disposition: form-data; name=\"attachment\"; filename=\"\(attachment.fileName)\"\r\n")
      append("Content-Type: image/jpeg\r\n\r\n")
      body.append(attachment.data)
      append("\r\n")
    }
    append("--\(boundary)--\r\n")
    return body
  }
}

/// Übersetzt „gesendete Bytes“ in einen Anteil. `@unchecked Sendable`, weil `NSObject` nicht als `Sendable`
/// gekennzeichnet ist; die einzige Eigenschaft ist unveränderlich.
private final class ProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let progress: @Sendable (Double) -> Void

  init(progress: @escaping @Sendable (Double) -> Void) { self.progress = progress }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    guard totalBytesExpectedToSend > 0 else { return }
    progress(min(1, Double(totalBytesSent) / Double(totalBytesExpectedToSend)))
  }
}

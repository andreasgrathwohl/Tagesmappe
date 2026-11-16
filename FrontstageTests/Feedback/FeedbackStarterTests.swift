import CoreGraphics
import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct FeedbackStarterTests {
  private typealias Support = FeedbackTestSupport

  /// Protokoll der Aufrufe der Aufnahme.
  private final class CallLog {
    var captures = 0
  }

  @Test("Review 1: Aufnahme vor der Sitzung")
  func captureRunsBeforeSessionExists() {
    let log = CallLog()
    let context = Support.makeContext(capture: {
      log.captures += 1
      return Support.makeImage()
    })
    let session = FeedbackStarter.start(kind: .issue, topic: .dayView, context: context)
    #expect(log.captures == 1)
    #expect(session.model.draft.attachments.map(\.origin) == [.windowCapture])
    #expect(session.model.draft.topic == .dayView)
  }

  @Test("Bestehender Entwurf: neue Aufnahme hinten, Art bleibt")
  func existingDraftKeepsKindAndAppends() throws {
    let context = Support.makeContext()
    let first = FeedbackStarter.start(kind: .idea, topic: nil, context: context)
    first.model.setText("Angefangen")
    first.model.persist()
    let firstID = try #require(first.model.draft.attachments.first?.id)

    let second = FeedbackStarter.start(kind: .issue, topic: nil, context: context)
    #expect(second.model.draft.kind == .idea)
    #expect(second.model.draft.text == "Angefangen")
    #expect(second.model.draft.attachments.count == 2)
    #expect(second.model.draft.attachments.first?.id == firstID)
    #expect(second.model.draft.attachments.last?.origin == .windowCapture)
  }

  @Test("AK-58: persist() direkt nach setText ist für den nächsten Start lesbar")
  func persistRightAfterSetTextSurvivesRestart() {
    let context = Support.makeContext()
    let first = FeedbackStarter.start(kind: .idea, topic: nil, context: context)
    first.model.setText("Letzte 400 ms")
    first.model.persist()  // Wie onDisappear beim Schließen
    let second = FeedbackStarter.start(kind: .idea, topic: nil, context: context)
    #expect(second.model.draft.text == "Letzte 400 ms")
  }

  @Test("Aufnahme scheitert → Rückmeldung ohne Bild")
  func nilCaptureStartsWithoutImage() {
    let context = Support.makeContext(capture: { nil })
    let session = FeedbackStarter.start(kind: .issue, topic: nil, context: context)
    #expect(session.model.draft.attachments.isEmpty)
  }
}

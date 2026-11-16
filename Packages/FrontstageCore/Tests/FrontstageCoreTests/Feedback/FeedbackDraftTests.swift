import Foundation
import Testing
@testable import FrontstageCore

@Suite("Feedback Draft") struct FeedbackDraftTests {
  @Test("Neu: Text leer, Geräteangaben aus, keine Bilder (FR-17.3)")
  func newDraftDefaults() {
    let d = FeedbackDraft(kind: .idea, topic: .board)
    #expect(d.text == "")
    #expect(d.includesDeviceInfo == false)
    #expect(d.attachments.isEmpty)
    #expect(d.topic == .board)
    #expect(FeedbackDraft(kind: .idea, topic: nil).id != d.id)
  }

  @Test("Review 5: nur Leerraum lässt sich nicht senden (FR-17.3)")
  func whitespaceOnlyCannotSend() {
    var d = FeedbackDraft(kind: .issue, topic: nil)
    d.text = " \n\t"
    #expect(d.canSend == false)
    d.text = "x"
    #expect(d.canSend == true)
  }

  @Test("Entwurf übersteht JSON (FR-17.3)")
  func draftRoundTripsJSON() throws {
    var d = FeedbackDraft(kind: .issue, topic: .penNotes)
    d.text = "Text"
    d.includesDeviceInfo = true
    d.attachments = [FeedbackAttachment(id: UUID(), origin: .windowCapture, pixelWidth: 100, pixelHeight: 50,
                                        redactions: [NormalizedRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2)], hasMarkup: true)]
    let data = try JSONEncoder().encode(d)
    #expect(try JSONDecoder().decode(FeedbackDraft.self, from: data) == d)
  }
}

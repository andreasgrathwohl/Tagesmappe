import Foundation
import Testing
@testable import FrontstageCore

@Suite("Feedback Composer") struct FeedbackComposerTests {
  private let info = FeedbackFixtures.info

  @Test("AK-58: Betreff und Text")
  func composesIssue() {
    var d = FeedbackDraft(kind: .issue, topic: .board)
    d.text = "Tafel speichert nicht"
    let m = FeedbackComposer.compose(d, deviceInfo: info)
    #expect(m.subject == "Frontstage – Hinweis: Tafel speichert nicht")
    #expect(m.body == "Tafel speichert nicht\n\n—\nArt: Hinweis\nHilfethema: board")
    #expect(m.attachmentFileNames.isEmpty)
  }

  @Test("Ohne Text: Betreff ohne Kurzfassung")
  func subjectWithoutText() {
    let d = FeedbackDraft(kind: .idea, topic: nil)
    #expect(FeedbackComposer.compose(d, deviceInfo: nil).subject == "Frontstage – Idee")
  }

  @Test("Geräteangaben nur, wenn eingeschaltet")
  func deviceInfoOnlyWhenIncluded() {
    var d = FeedbackDraft(kind: .idea, topic: nil)
    d.text = "Idee"
    #expect(!FeedbackComposer.compose(d, deviceInfo: info).body.contains("Geräteangaben"))
    d.includesDeviceInfo = true
    #expect(!FeedbackComposer.compose(d, deviceInfo: nil).body.contains("Geräteangaben"))
    let body = FeedbackComposer.compose(d, deviceInfo: info).body
    #expect(body == "Idee\n\n—\nArt: Idee\n\nGeräteangaben:\n" + info.reportLines.joined(separator: "\n"))
  }

  @Test("Review 5: erste nicht leere Zeile")
  func subjectUsesFirstNonEmptyLine() {
    var d = FeedbackDraft(kind: .idea, topic: nil)
    d.text = "\n\n  Idee   mit  Lücken \nmehr"
    #expect(FeedbackComposer.compose(d, deviceInfo: nil).subject == "Frontstage – Idee: Idee mit Lücken")
  }

  @Test("Review 5: nach 60 Zeichen gekürzt mit …")
  func subjectIsCutAt60WithEllipsis() {
    var d = FeedbackDraft(kind: .idea, topic: nil)
    d.text = String(repeating: "a", count: 59) + " " + String(repeating: "b", count: 20)
    let subject = FeedbackComposer.compose(d, deviceInfo: nil).subject
    #expect(subject == "Frontstage – Idee: " + String(repeating: "a", count: 59) + "…")
    d.text = String(repeating: "a", count: 60)
    #expect(FeedbackComposer.compose(d, deviceInfo: nil).subject == "Frontstage – Idee: " + String(repeating: "a", count: 60))
  }

  @Test("Anhänge: Namen und Zahl")
  func attachmentNames() {
    var d = FeedbackDraft(kind: .issue, topic: nil)
    d.text = "x"
    d.attachments = (0..<2).map { _ in FeedbackAttachment(id: UUID(), origin: .photoLibrary, pixelWidth: 10, pixelHeight: 10) }
    let m = FeedbackComposer.compose(d, deviceInfo: nil)
    #expect(m.attachmentFileNames == ["Bildschirmfoto-1.jpg", "Bildschirmfoto-2.jpg"])
    #expect(m.body.contains("Bildschirmfotos: 2"))
  }
}

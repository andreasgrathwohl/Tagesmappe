import Testing
@testable import FrontstageCore

@Suite("Feedback Attachment Policy") struct FeedbackAttachmentPolicyTests {
  @Test("Höchstens fünf (FR-17.4)")
  func remaining() {
    #expect(FeedbackAttachmentPolicy.remaining(currentCount: 3) == 2)
    #expect(FeedbackAttachmentPolicy.remaining(currentCount: 7) == 0)
  }

  @Test("Längste Kante 2048, nie vergrößern (FR-17.4)")
  func scales() {
    #expect(FeedbackAttachmentPolicy.scaledSize(width: 2732, height: 2048) == (2048, 1535))
    #expect(FeedbackAttachmentPolicy.scaledSize(width: 800, height: 600) == (800, 600))
    #expect(FeedbackAttachmentPolicy.scaledSize(width: 1, height: 10000).width == 1)
  }

  @Test("Dateinamen (FR-17.4)")
  func fileNames() {
    #expect(FeedbackAttachmentPolicy.fileName(index: 0) == "Bildschirmfoto-1.jpg")
    #expect(FeedbackAttachmentPolicy.fileName(index: 4) == "Bildschirmfoto-5.jpg")
    #expect(FeedbackAttachmentPolicy.jpegQuality == 0.85)
  }
}

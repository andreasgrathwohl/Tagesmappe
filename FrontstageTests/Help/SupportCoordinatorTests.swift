import CoreGraphics
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct SupportCoordinatorTests {
  /// Zählt Aufnahmen; eine Klasse, weil der `@MainActor`-Closure als Sendable keine lokale `var` mutieren darf.
  private final class CallLog {
    var captures = 0
  }


  private func makeCoordinator(
    capture: @escaping @MainActor () -> CGImage? = { FeedbackTestSupport.makeImage() }
  ) -> SupportCoordinator {
    let coordinator = SupportCoordinator()
    coordinator.context = FeedbackTestSupport.makeContext(capture: capture)
    return coordinator
  }

  @Test("Hilfecenter aus dem Menü")
  func showHelpCenterSetsFlag() {
    let coordinator = makeCoordinator()
    coordinator.showHelpCenter()
    #expect(coordinator.showsHelpCenter)
  }

  @Test("Review 1: Rückmeldung aus dem Menü nimmt zuerst auf")
  func menuFeedbackCapturesFirst() {
    let log = CallLog()
    let coordinator = makeCoordinator(capture: {
      log.captures += 1
      return FeedbackTestSupport.makeImage()
    })
    coordinator.startFeedback()
    #expect(log.captures == 1)
    let session = coordinator.feedbackSession
    #expect(session?.model.draft.attachments.map(\.origin) == [.windowCapture])
    #expect(session?.model.draft.kind == .issue)
  }

  @Test("Hilfecenter nicht über offener Rückmeldung")
  func helpCenterWaitsForFeedback() {
    let coordinator = makeCoordinator()
    coordinator.startFeedback()
    coordinator.showHelpCenter()
    #expect(!coordinator.showsHelpCenter)
  }

  @Test("Rückmeldung aus dem Hilfecenter beginnt erst nach dem Schließen")
  func feedbackFromHelpCenterStartsAfterDismiss() {
    let coordinator = makeCoordinator()
    coordinator.showHelpCenter()
    coordinator.requestFeedbackFromHelpCenter(kind: .idea)
    #expect(!coordinator.showsHelpCenter)
    #expect(coordinator.feedbackSession == nil)
    coordinator.helpCenterDidDismiss()
    #expect(coordinator.feedbackSession?.model.draft.kind == .idea)
  }
}

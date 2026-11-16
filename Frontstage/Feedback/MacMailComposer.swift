#if os(macOS)
  import AppKit
  import Foundation

  /// Öffnet auf dem Mac den Mail-Entwurf des Systems (`NSSharingService .composeEmail`).
  ///
  /// Swift-Hinweis: `NSSharingService` hat keine Ansicht, die in SwiftUI eingebettet wird; der Dienst wird
  /// angestoßen und meldet sich über den Delegate. Das Objekt muss bis dahin am Leben bleiben, daher hält
  /// der Aufrufer die Instanz (`@State`).
  @MainActor
  final class MacMailComposer: NSObject, NSSharingServiceDelegate {
    private var onFinish: (@MainActor (Bool) -> Void)?
    private var service: NSSharingService?

    /// `false`, wenn der Dienst nicht verfügbar ist oder nichts zum Senden vorliegt; dann wurde nichts geöffnet.
    @discardableResult
    func compose(
      recipient: String, message: FeedbackMessage, fileURLs: [URL], onFinish: @escaping @MainActor (_ handedOver: Bool) -> Void
    ) -> Bool {
      guard let service = NSSharingService(named: .composeEmail) else { return false }
      let items: [Any] = [message.body] + fileURLs
      guard service.canPerform(withItems: items) else { return false }
      service.delegate = self
      service.recipients = [recipient]
      service.subject = message.subject
      self.service = service
      self.onFinish = onFinish
      service.perform(withItems: items)
      return true
    }

    nonisolated func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
      Task { @MainActor in self.finish(true) }
    }

    nonisolated func sharingService(
      _ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error
    ) {
      Task { @MainActor in self.finish(false) }
    }

    private func finish(_ handedOver: Bool) {
      let callback = onFinish
      onFinish = nil
      service = nil
      callback?(handedOver)
    }
  }
#endif

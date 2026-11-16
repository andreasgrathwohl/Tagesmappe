#if os(iOS)
  import MessageUI
  import SwiftUI

  /// Mail-Entwurf des Systems für die Rückmeldung (iPad).
  ///
  /// Swift-Hinweis: `UIViewControllerRepresentable` bettet einen UIKit-Controller in SwiftUI ein. Der
  /// `Coordinator` ist der Delegate des Controllers und meldet das Ergebnis zurück; SwiftUI erzeugt ihn über
  /// `makeCoordinator()` und hält ihn für die Lebensdauer der Ansicht.
  struct MailComposeView: UIViewControllerRepresentable {
    let recipient: String
    let message: FeedbackMessage
    let attachments: [(fileName: String, data: Data)]
    /// `true`, wenn die Mail gesendet oder als Entwurf gesichert wurde – dann ist die Rückmeldung abgegeben.
    let onFinish: @MainActor (_ handedOver: Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
      let controller = MFMailComposeViewController()
      controller.mailComposeDelegate = context.coordinator
      controller.setToRecipients([recipient])
      controller.setSubject(message.subject)
      controller.setMessageBody(message.body, isHTML: false)
      for attachment in attachments {
        controller.addAttachmentData(attachment.data, mimeType: "image/jpeg", fileName: attachment.fileName)
      }
      return controller
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    @MainActor final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
      private let onFinish: @MainActor (Bool) -> Void

      init(onFinish: @escaping @MainActor (Bool) -> Void) { self.onFinish = onFinish }

      func mailComposeController(
        _ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?
      ) {
        onFinish(result == .sent || result == .saved)
      }
    }
  }
#endif

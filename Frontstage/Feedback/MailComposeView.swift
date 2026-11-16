#if os(iOS)
  import FrontstageCore
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
    /// Ergebnis des Mail-Entwurfs. Nur `.sent` gilt als abgegeben; `.saved` und `.cancelled` behalten den
    /// Entwurf, `.failed` zeigt einen Hinweis (Entscheidung 12).
    let onFinish: @MainActor (_ result: MFMailComposeResult) -> Void

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

    /// Swift-Hinweis: `@preconcurrency` vor dem Protokoll, weil MessageUI den Delegate nicht als `@MainActor`
    /// kennzeichnet; UIKit ruft ihn trotzdem auf dem Hauptthread, die Prüfung erfolgt dann zur Laufzeit.
    @MainActor final class Coordinator: NSObject, @preconcurrency MFMailComposeViewControllerDelegate {
      private let onFinish: @MainActor (MFMailComposeResult) -> Void

      init(onFinish: @escaping @MainActor (MFMailComposeResult) -> Void) { self.onFinish = onFinish }

      func mailComposeController(
        _ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?
      ) {
        onFinish(result)
      }
    }
  }
#endif

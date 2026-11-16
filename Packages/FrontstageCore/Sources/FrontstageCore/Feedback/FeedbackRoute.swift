import Foundation

/// Warum nur geteilt statt gemailt wird.
public enum FeedbackShareReason: Hashable, Sendable { case noRecipient, noMailAccount }

/// Weg einer Rückmeldung: Hochladen, Mail oder Teilen.
public enum FeedbackRoute: Hashable, Sendable {
  case upload(endpoint: FeedbackServiceEndpoint)
  case mail(recipient: String)
  case share(FeedbackShareReason)

  /// Dienst zuerst (Entscheidung 16), sonst `fallback`.
  public static func choose(service: FeedbackServiceEndpoint?, recipient: String?, canSendMail: Bool) -> FeedbackRoute {
    if let service { return .upload(endpoint: service) }
    return fallback(recipient: recipient, canSendMail: canSendMail)
  }

  /// Ohne Dienst: fehlende Adresse vor fehlendem Konto.
  public static func fallback(recipient: String?, canSendMail: Bool) -> FeedbackRoute {
    guard let recipient else { return .share(.noRecipient) }
    return canSendMail ? .mail(recipient: recipient) : .share(.noMailAccount)
  }
}

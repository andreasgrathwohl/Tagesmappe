import Foundation

/// Fertige Mail: Betreff, Text und die Namen der Anhänge.
public struct FeedbackMessage: Hashable, Sendable {
  public let subject: String
  public let body: String
  public let attachmentFileNames: [String]
}

/// Baut Betreff und Text der Rückmeldung (Entscheidung 6, wörtlich).
public enum FeedbackComposer {
  public static let subjectLimit = 60

  public static func compose(_ draft: FeedbackDraft, deviceInfo: DeviceInfo?) -> FeedbackMessage {
    let kindWord = draft.kind == .idea ? "Idee" : "Hinweis"
    let trimmed = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)

    var subject = "Frontstage – \(kindWord)"
    if let short = shortText(trimmed) { subject += ": \(short)" }

    var lines = [trimmed, "", "—", "Art: \(kindWord)"]
    if let topic = draft.topic { lines.append("Hilfethema: \(topic.rawValue)") }
    if !draft.attachments.isEmpty { lines.append("Bildschirmfotos: \(draft.attachments.count)") }
    if draft.includesDeviceInfo, let deviceInfo {
      lines.append("")
      lines.append("Geräteangaben:")
      lines.append(contentsOf: deviceInfo.reportLines)
    }

    let names = draft.attachments.indices.map { FeedbackAttachmentPolicy.fileName(index: $0) }
    return FeedbackMessage(subject: subject, body: lines.joined(separator: "\n"), attachmentFileNames: names)
  }

  /// Erste nicht leere Zeile, Leerraum zu einem Leerzeichen; über dem Limit gekürzt mit „…“.
  private static func shortText(_ text: String) -> String? {
    guard let line = text.split(whereSeparator: \.isNewline)
      .map({ $0.split(whereSeparator: \.isWhitespace).joined(separator: " ") })
      .first(where: { !$0.isEmpty }) else { return nil }
    guard line.count > subjectLimit else { return line }
    return String(line.prefix(subjectLimit)).trimmingCharacters(in: .whitespaces) + "…"
  }
}

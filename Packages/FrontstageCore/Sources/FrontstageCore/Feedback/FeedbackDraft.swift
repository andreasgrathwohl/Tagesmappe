import Foundation

/// Woher ein Bildschirmfoto stammt.
public enum FeedbackAttachmentOrigin: String, Codable, Sendable { case windowCapture, photoLibrary }

/// Metadaten eines Bildschirmfotos im Entwurf; die Bilddatei selbst hält die App.
public struct FeedbackAttachment: Hashable, Codable, Sendable, Identifiable {
  public let id: UUID
  public let origin: FeedbackAttachmentOrigin
  public let pixelWidth: Int
  public let pixelHeight: Int
  /// Deckend geschwärzte Bereiche.
  public var redactions: [NormalizedRect]
  public var hasMarkup: Bool

  public init(id: UUID, origin: FeedbackAttachmentOrigin, pixelWidth: Int, pixelHeight: Int,
              redactions: [NormalizedRect] = [], hasMarkup: Bool = false) {
    self.id = id
    self.origin = origin
    self.pixelWidth = pixelWidth
    self.pixelHeight = pixelHeight
    self.redactions = redactions
    self.hasMarkup = hasMarkup
  }
}

/// Entwurf einer Rückmeldung (FR-17.3).
public struct FeedbackDraft: Hashable, Codable, Sendable {
  /// Beim Anlegen neu; wird als `clientDraftId` hochgeladen (Entscheidung 16).
  public let id: UUID
  public var kind: FeedbackKind
  public var text: String
  public var topic: HelpTopic?
  public var includesDeviceInfo: Bool
  public var attachments: [FeedbackAttachment]

  public init(kind: FeedbackKind, topic: HelpTopic?) {
    self.id = UUID()
    self.kind = kind
    self.text = ""
    self.topic = topic
    self.includesDeviceInfo = false
    self.attachments = []
  }

  /// Höchstlänge des Texts, wie der Rückmeldedienst sie prüft (FR-18; sonst antwortet er mit 422).
  public static let maxTextLength = 10_000

  /// Gezählt in Unicode-Skalaren wie der Dienst (Python `len`), nicht in sichtbaren Zeichen: ein Emoji mit
  /// Hautton zählt dort doppelt.
  public var isTextTooLong: Bool { text.unicodeScalars.count > Self.maxTextLength }

  /// Text mit mindestens einem Nicht-Leerraum-Zeichen und höchstens `maxTextLength` Zeichen.
  public var canSend: Bool {
    !isTextTooLong && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

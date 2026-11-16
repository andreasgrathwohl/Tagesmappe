import CoreGraphics
import Foundation
import FrontstageCore
import ImageIO
import Observation
import PencilKit

/// Stand des Hochladens einer Rückmeldung.
enum FeedbackUploadState: Equatable {
  case idle
  case uploading(progress: Double)
  case sent(reference: String)
  case failed(FeedbackUploadError)
}

/// Zustand der Rückmeldung (FR-17.3, FR-17.4): Entwurf, Bilder, Weg und Hochladen. Die Ansicht liest nur
/// von hier und ruft Methoden auf; Speichern, Bildaufbereitung und Versandweg sind Sache dieses Modells.
///
/// Swift-Hinweis: `@MainActor @Observable` – alles läuft auf dem Hauptthread, SwiftUI beobachtet jede
/// gelesene Eigenschaft einzeln. `private(set)` erlaubt Lesen von außen, Schreiben nur über die Methoden.
@MainActor @Observable final class FeedbackModel {
  private let context: FeedbackContext
  private(set) var draft: FeedbackDraft
  private(set) var uploadState: FeedbackUploadState = .idle
  private(set) var saveFailed = false
  /// Gemerkt im Modell, weil `UserDefaults` nicht beobachtbar ist; sonst bliebe die Ansicht nach
  /// `giveConsent()` stehen.
  private var consentGiven: Bool
  /// Ordner der zuletzt erzeugten Teilen-Dateien; wird beim Senden und Verwerfen entfernt.
  private var shareDirectory: URL?

  init(draft: FeedbackDraft, context: FeedbackContext) {
    self.draft = draft
    self.context = context
    self.consentGiven = FeedbackConsent.isGiven(defaults: context.consentDefaults)
  }

  // MARK: Weg

  var route: FeedbackRoute {
    FeedbackRoute.choose(service: context.service, recipient: context.recipient, canSendMail: context.canSendMail())
  }

  var fallbackRoute: FeedbackRoute {
    FeedbackRoute.fallback(recipient: context.recipient, canSendMail: context.canSendMail())
  }

  var needsConsent: Bool {
    guard case .upload = route else { return false }
    return !consentGiven
  }

  func giveConsent() {
    FeedbackConsent.give(defaults: context.consentDefaults)
    consentGiven = true
  }

  // MARK: Inhalt

  var message: FeedbackMessage {
    FeedbackComposer.compose(draft, deviceInfo: draft.includesDeviceInfo ? context.deviceInfo() : nil)
  }

  /// Zum Zeigen auch bei ausgeschaltetem Schalter.
  var deviceInfoPreview: [String] { context.deviceInfo().reportLines }

  var remainingSlots: Int { FeedbackAttachmentPolicy.remaining(currentCount: draft.attachments.count) }

  func setKind(_ kind: FeedbackKind) { draft.kind = kind }
  func setText(_ text: String) { draft.text = text }
  func setIncludesDeviceInfo(_ on: Bool) { draft.includesDeviceInfo = on }

  // MARK: Bilder

  /// Vorn, wenn der Entwurf noch kein Bild hat, sonst hinten; über der Grenze verworfen.
  func addCapturedWindow(_ image: CGImage) {
    guard remainingSlots > 0, let jpeg = FeedbackImageEncoder.preparedJPEG(from: image) else { return }
    let size = FeedbackAttachmentPolicy.scaledSize(width: image.width, height: image.height)
    guard
      let attachment = store(
        jpeg, origin: .windowCapture, width: size.width, height: size.height)
    else { return }
    if draft.attachments.isEmpty {
      draft.attachments.insert(attachment, at: 0)
    } else {
      draft.attachments.append(attachment)
    }
    persist()
  }

  /// Bis `remainingSlots` Bilder; was sich nicht lesen lässt, zählt nicht und belegt keinen Platz.
  func addPhotos(_ datas: [Data]) {
    for data in datas {
      guard remainingSlots > 0 else { break }
      guard let jpeg = FeedbackImageEncoder.preparedJPEG(fromImageData: data),
        let size = Self.pixelSize(ofImageData: jpeg),
        let attachment = store(jpeg, origin: .photoLibrary, width: size.width, height: size.height)
      else { continue }
      draft.attachments.append(attachment)
    }
    persist()
  }

  func removeAttachment(_ id: UUID) {
    guard draft.attachments.contains(where: { $0.id == id }) else { return }
    draft.attachments.removeAll { $0.id == id }
    try? context.store.removeAttachment(id)
    persist()
  }

  func imageData(for id: UUID) -> Data? { context.store.imageData(for: id) }

  func markup(for id: UUID) -> PKDrawing? {
    guard let data = context.store.markupData(for: id) else { return nil }
    return try? PKDrawing(data: data)
  }

  /// Übernimmt das Ergebnis des Bildeditors. Eine leere Zeichnung löscht die Zeichnungsdatei.
  func updateMarkup(for id: UUID, drawing: PKDrawing, redactions: [NormalizedRect]) {
    guard let index = draft.attachments.firstIndex(where: { $0.id == id }) else { return }
    let hasStrokes = !drawing.strokes.isEmpty
    do {
      try context.store.storeMarkup(hasStrokes ? drawing.dataRepresentation() : nil, for: id)
    } catch {
      saveFailed = true
    }
    draft.attachments[index].redactions = redactions
    draft.attachments[index].hasMarkup = hasStrokes
    persist()
  }

  /// Bilder mit eingerechneter Zeichnung und Schwärzung, in der Reihenfolge des Entwurfs. Fehlt die Datei,
  /// entfällt das Bild. Lässt sich ein Bild nicht zusammensetzen, geht es nur dann ohne Bearbeitung mit, wenn
  /// es keine Schwärzung trägt; ein geschwärztes Bild entfällt dann ganz – nie ungeschwärzt (RISK-11,
  /// Entscheidung 7).
  func flattenedAttachments() -> [(fileName: String, data: Data)] {
    var result: [(fileName: String, data: Data)] = []
    for attachment in draft.attachments {
      guard let original = imageData(for: attachment.id) else { continue }
      let data: Data
      if attachment.hasMarkup || !attachment.redactions.isEmpty {
        let flattened = FeedbackImageEncoder.flattened(
          imageData: original, markup: markup(for: attachment.id), redactions: attachment.redactions)
        if let flattened {
          data = flattened
        } else if attachment.redactions.isEmpty {
          data = original
        } else {
          continue
        }
      } else {
        data = original
      }
      result.append((FeedbackAttachmentPolicy.fileName(index: result.count), data))
    }
    return result
  }

  // MARK: Ausgabe

  func copyText() -> String {
    let message = message
    return "Betreff: \(message.subject)\n\n\(message.body)"
  }

  /// Schreibt die zusammengesetzten Bilder nach `tmp/Feedback-<uuid>/Bildschirmfoto-n.jpg`.
  func shareFiles() throws -> [URL] {
    removeShareFiles()
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "Feedback-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    shareDirectory = directory
    return try flattenedAttachments().map { item in
      let url = directory.appending(path: item.fileName, directoryHint: .notDirectory)
      try item.data.write(to: url, options: .atomic)
      return url
    }
  }

  // MARK: Hochladen

  /// Nur mit Zustimmung. Bei Erfolg ist der Entwurf geleert und `uploadState` trägt die Kennung; bei einem
  /// Fehler bleibt der Entwurf erhalten.
  func upload() async {
    guard case .upload(let endpoint) = route, let appKey = context.appKey, consentGiven else { return }
    if case .uploading = uploadState { return }
    uploadState = .uploading(progress: 0)

    let info = context.deviceInfo()
    let payload = FeedbackUploadPayload(
      draftID: draft.id, draft: draft, deviceInfo: info, appVersion: "\(info.appVersion) (\(info.build))")
    let attachments = flattenedAttachments()
    do throws(FeedbackUploadError) {
      let receipt = try await context.uploader.upload(
        payload: payload, attachments: attachments, to: endpoint, appKey: appKey,
        progress: { [weak self] value in
          // Aus dem Netzwerkfaden zurück auf den Hauptthread.
          Task { @MainActor in self?.updateProgress(value) }
        })
      didSend()
      uploadState = .sent(reference: receipt.reference)
    } catch {
      uploadState = .failed(error)
    }
  }

  /// Setzt den Hochladezustand zurück, etwa nach „Erneut versuchen“ oder dem Schließen der Meldung.
  func resetUploadState() { uploadState = .idle }

  private func updateProgress(_ value: Double) {
    // Verspätete Meldungen nach Ende des Auftrags werden ignoriert.
    guard case .uploading(let current) = uploadState else { return }
    uploadState = .uploading(progress: max(current, value))
  }

  // MARK: Entwurf

  /// Nach erfolgreichem Senden: Dateien weg, Entwurf neu mit gleicher Art und gleichem Thema.
  func didSend() {
    resetDraft()
  }

  func discard() {
    resetDraft()
    uploadState = .idle
  }

  /// Ohne Text und ohne Bilder gibt es nichts zu sichern: eine alte Entwurfsdatei wird dann entfernt, statt
  /// einen leeren Entwurf zu schreiben (etwa nach dem Senden).
  func persist() {
    if draft.text.isEmpty && draft.attachments.isEmpty {
      try? context.store.discard()
      saveFailed = false
      return
    }
    do {
      try context.store.save(draft)
      saveFailed = false
    } catch {
      saveFailed = true
    }
  }

  private func resetDraft() {
    try? context.store.discard()
    removeShareFiles()
    draft = FeedbackDraft(kind: draft.kind, topic: draft.topic)
    saveFailed = false
  }

  private func removeShareFiles() {
    if let shareDirectory { try? FileManager.default.removeItem(at: shareDirectory) }
    shareDirectory = nil
  }

  // MARK: Hilfen

  private func store(_ jpeg: Data, origin: FeedbackAttachmentOrigin, width: Int, height: Int) -> FeedbackAttachment? {
    let id = UUID()
    do {
      try context.store.storeImage(jpeg, for: id)
    } catch {
      saveFailed = true
      return nil
    }
    return FeedbackAttachment(id: id, origin: origin, pixelWidth: width, pixelHeight: height)
  }

  private static func pixelSize(ofImageData data: Data) -> (width: Int, height: Int)? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    else { return nil }
    return (width, height)
  }
}

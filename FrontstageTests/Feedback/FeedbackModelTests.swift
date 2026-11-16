import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct FeedbackModelTests {
  private typealias Support = FeedbackTestSupport

  private func makeModel(
    context: FeedbackContext = Support.makeContext(), kind: FeedbackKind = .issue
  ) -> FeedbackModel {
    FeedbackModel(draft: FeedbackDraft(kind: kind, topic: nil), context: context)
  }

  private func makeUploadContext(_ server: StubURLProtocol.Server) -> FeedbackContext {
    Support.makeContext(
      service: Support.endpoint, appKey: "test-key",
      uploader: FeedbackUploader(session: server.session, sleep: { _ in }))
  }

  private var receiptBody: String { "{\"id\":\"\(UUID().uuidString)\",\"reference\":\"AB12CD34\"}" }

  @Test("AK-59: Aufnahme ist erstes Bild, entfernbar")
  func startsWithCapturedWindowFirst() throws {
    let model = makeModel()
    model.addPhotos([Support.makePhotoData()])
    model.addCapturedWindow(Support.makeImage())
    // Der Entwurf hatte schon ein Foto: die Aufnahme kommt hinten dazu.
    #expect(model.draft.attachments.map(\.origin) == [.photoLibrary, .windowCapture])

    let fresh = makeModel()
    fresh.addCapturedWindow(Support.makeImage())
    fresh.addPhotos([Support.makePhotoData()])
    #expect(fresh.draft.attachments.map(\.origin) == [.windowCapture, .photoLibrary])
    let first = try #require(fresh.draft.attachments.first)
    #expect(fresh.imageData(for: first.id) != nil)

    fresh.removeAttachment(first.id)
    #expect(fresh.draft.attachments.count == 1)
    #expect(fresh.imageData(for: first.id) == nil)
  }

  @Test("AK-59: höchstens fünf Bilder")
  func limitsToFiveAttachments() {
    let model = makeModel()
    model.addCapturedWindow(Support.makeImage())
    model.addPhotos(Array(repeating: Support.makePhotoData(), count: 6))
    #expect(model.draft.attachments.count == 5)
    #expect(model.remainingSlots == 0)
    model.addCapturedWindow(Support.makeImage())
    #expect(model.draft.attachments.count == 5)
  }

  @Test("AK-58: Entwurf übersteht neues Modell")
  func draftSurvivesReload() async throws {
    let directory = Support.makeDirectory()
    let model = makeModel(context: Support.makeContext(directory: directory))
    model.setText("Bitte mehr Platz für Notizen")
    model.addCapturedWindow(Support.makeImage())
    model.persist()

    let reloadedStore = FeedbackDraftStore(directory: directory)
    let loaded = try #require(reloadedStore.load())
    let reloaded = FeedbackModel(draft: loaded, context: Support.makeContext(directory: directory))
    #expect(reloaded.draft.text == "Bitte mehr Platz für Notizen")
    #expect(reloaded.draft.attachments.count == 1)
    let id = try #require(reloaded.draft.attachments.first?.id)
    #expect(reloaded.imageData(for: id) != nil)
  }

  @Test("Review 4: Senden leert Entwurf und Dateien")
  func didSendClearsDraftAndFiles() throws {
    let directory = Support.makeDirectory()
    let model = makeModel(context: Support.makeContext(directory: directory), kind: .idea)
    model.setText("Text")
    model.addCapturedWindow(Support.makeImage())
    model.persist()
    let id = try #require(model.draft.attachments.first?.id)

    model.didSend()
    #expect(model.draft.text.isEmpty)
    #expect(model.draft.attachments.isEmpty)
    #expect(model.draft.kind == .idea)
    #expect(FeedbackDraftStore(directory: directory).load() == nil)
    #expect(FeedbackDraftStore(directory: directory).imageData(for: id) == nil)
  }

  @Test("Review 3: ohne Adresse Teilen")
  func routeWithoutRecipientIsShare() {
    let model = makeModel(context: Support.makeContext(service: nil, recipient: nil))
    #expect(model.route == .share(.noRecipient))
  }

  @Test("Ohne Zustimmung kein Upload")
  func uploadRequiresConsent() async {
    let body = receiptBody
    let server = StubURLProtocol.Server { _ in (201, body) }
    let model = makeModel(context: makeUploadContext(server))
    model.setText("Text")
    #expect(model.needsConsent)
    await model.upload()
    #expect(server.requests.isEmpty)
    #expect(model.uploadState == .idle)

    model.giveConsent()
    #expect(!model.needsConsent)
  }

  @Test("AK-58: Upload leert Entwurf, zeigt Kennung")
  func uploadSuccessClearsDraft() async {
    let body = receiptBody
    let server = StubURLProtocol.Server { _ in (201, body) }
    let model = makeModel(context: makeUploadContext(server))
    model.setText("Text")
    model.addCapturedWindow(Support.makeImage())
    model.giveConsent()
    await model.upload()
    #expect(model.uploadState == .sent(reference: "AB12CD34"))
    #expect(model.draft.text.isEmpty)
    #expect(model.draft.attachments.isEmpty)
    #expect(server.requests.count == 1)
  }

  @Test("Review 3: Ausfall behält Entwurf, Rückfallweg angeboten")
  func uploadFailureKeepsDraftAndOffersFallback() async {
    let directory = Support.makeDirectory()
    let server = StubURLProtocol.Server { _ in (503, "") }
    let context = Support.makeContext(
      directory: directory, service: Support.endpoint, appKey: "test-key",
      uploader: FeedbackUploader(session: server.session, sleep: { _ in }))
    let model = makeModel(context: context)
    model.setText("Text")
    model.persist()
    model.giveConsent()
    await model.upload()
    #expect(model.uploadState == .failed(.unavailable))
    #expect(model.draft.text == "Text")
    #expect(FeedbackDraftStore(directory: directory).load() != nil)
    #expect(model.fallbackRoute == .mail(recipient: Support.recipient))
    #expect(server.requests.count == FeedbackRetryPolicy.maxAttempts)
  }

  @Test("Geräteangaben voreingestellt aus und nicht im Text")
  func deviceInfoOffByDefault() {
    let model = makeModel()
    model.setText("Text")
    #expect(!model.draft.includesDeviceInfo)
    #expect(!model.message.body.contains("Geräteangaben"))
    #expect(!model.deviceInfoPreview.isEmpty)

    model.setIncludesDeviceInfo(true)
    #expect(model.message.body.contains("Geräteangaben:"))
  }

  @Test("Text kopieren enthält Betreff und Text")
  func copyTextHasSubjectAndBody() {
    let model = makeModel(kind: .idea)
    model.setText("Mehr Farben")
    let copy = model.copyText()
    #expect(copy.hasPrefix("Betreff: Frontstage – Idee: Mehr Farben\n\n"))
    #expect(copy.contains("Mehr Farben"))
  }

  @Test("Zusammengesetzte Anhänge in Reihenfolge mit Dateinamen")
  func flattenedAttachmentsAreOrdered() throws {
    let model = makeModel()
    model.addCapturedWindow(Support.makeImage())
    model.addPhotos([Support.makePhotoData()])
    let items = model.flattenedAttachments()
    #expect(items.map(\.fileName) == ["Bildschirmfoto-1.jpg", "Bildschirmfoto-2.jpg"])
    #expect(items.allSatisfy { !$0.data.isEmpty })

    let urls = try model.shareFiles()
    #expect(urls.map(\.lastPathComponent) == ["Bildschirmfoto-1.jpg", "Bildschirmfoto-2.jpg"])
    #expect(urls.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    model.didSend()
    #expect(urls.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
  }
}

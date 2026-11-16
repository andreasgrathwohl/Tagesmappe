import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct FeedbackDraftStoreTests {
  private func makeDirectory() -> URL {
    FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
  }

  private func fileNames(in directory: URL) -> [String] {
    ((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []).sorted()
  }

  @Test("Review 4: Entwurf samt Bild und Zeichnung übersteht Neuladen")
  func roundTripsDraftWithAttachments() throws {
    let directory = makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    var draft = FeedbackDraft(kind: .issue, topic: nil)
    draft.text = "Beispieltext"
    let attachment = FeedbackAttachment(id: UUID(), origin: .windowCapture, pixelWidth: 10, pixelHeight: 20, hasMarkup: true)
    draft.attachments = [attachment]

    let first = FeedbackDraftStore(directory: directory)
    try first.save(draft)
    try first.storeImage(Data([1, 2, 3]), for: attachment.id)
    try first.storeMarkup(Data([4, 5]), for: attachment.id)

    let second = FeedbackDraftStore(directory: directory)
    #expect(second.load() == draft)
    #expect(second.imageData(for: attachment.id) == Data([1, 2, 3]))
    #expect(second.markupData(for: attachment.id) == Data([4, 5]))
  }

  @Test("Review 4: kaputte draft.json → kein Entwurf, kein Absturz")
  func corruptDraftLoadsAsNil() throws {
    let directory = makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FeedbackDraftStore(directory: directory)
    #expect(store.load() == nil)
    try Data("{ kaputt".utf8).write(to: directory.appending(path: "draft.json"))
    #expect(store.load() == nil)
  }

  @Test("Review 4: Verwerfen löscht alle Dateien")
  func discardRemovesAllFiles() throws {
    let directory = makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FeedbackDraftStore(directory: directory)
    let id = UUID()
    try store.save(FeedbackDraft(kind: .idea, topic: nil))
    try store.storeImage(Data([1]), for: id)
    try store.storeMarkup(Data([2]), for: id)
    try store.discard()
    let remaining = fileNames(in: directory).filter { ["json", "jpg", "drawing"].contains(($0 as NSString).pathExtension) }
    #expect(remaining.isEmpty)
    #expect(store.load() == nil)
  }

  @Test("Anhang entfernen löscht Bild und Zeichnung")
  func removeAttachmentDeletesFiles() throws {
    let directory = makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FeedbackDraftStore(directory: directory)
    let id = UUID()
    let other = UUID()
    try store.storeImage(Data([1]), for: id)
    try store.storeMarkup(Data([2]), for: id)
    try store.storeImage(Data([3]), for: other)
    try store.removeAttachment(id)
    #expect(store.imageData(for: id) == nil)
    #expect(store.markupData(for: id) == nil)
    #expect(store.imageData(for: other) == Data([3]))
    // nil löscht eine Zeichnung ohne Fehler, auch wenn keine da ist.
    try store.storeMarkup(nil, for: id)
  }

  @Test("Nicht gesichert")
  func directoryExcludedFromBackup() throws {
    let directory = makeDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    _ = FeedbackDraftStore(directory: directory)
    let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
    #expect(values.isExcludedFromBackup == true)
  }
}

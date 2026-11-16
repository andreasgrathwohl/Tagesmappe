import Foundation
import FrontstageCore

/// Hält den Entwurf einer Rückmeldung nur auf dem Gerät (FR-17.3): `draft.json` plus je Bildschirmfoto
/// `<id>.jpg` und, falls gezeichnet wurde, `<id>.drawing`. Der Ordner ist von Sicherungen ausgenommen.
///
/// Swift-Hinweis: `@MainActor` bindet die ganze Klasse an den Hauptthread; der Zugriff aus SwiftUI
/// braucht dadurch keine Sperren.
@MainActor
final class FeedbackDraftStore {
  private let directory: URL
  private let fileManager = FileManager.default

  /// Application Support/Feedback.
  static let shared = FeedbackDraftStore(
    directory: URL.applicationSupportDirectory.appending(path: "Feedback", directoryHint: .isDirectory))

  /// Legt den Ordner an und nimmt ihn von der Sicherung aus. Misslingt das, arbeitet der Speicher weiter;
  /// `save` meldet den Fehler dann beim Schreiben.
  init(directory: URL) {
    self.directory = directory
    try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    var url = directory
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try? url.setResourceValues(values)
  }

  private var draftURL: URL { directory.appending(path: "draft.json", directoryHint: .notDirectory) }
  private func imageURL(_ id: UUID) -> URL {
    directory.appending(path: "\(id.uuidString).jpg", directoryHint: .notDirectory)
  }
  private func markupURL(_ id: UUID) -> URL {
    directory.appending(path: "\(id.uuidString).drawing", directoryHint: .notDirectory)
  }

  /// Fehlt die Datei oder ist sie unlesbar, gibt es keinen Entwurf (Entscheidung 10).
  func load() -> FeedbackDraft? {
    guard let data = try? Data(contentsOf: draftURL) else { return nil }
    return try? JSONDecoder().decode(FeedbackDraft.self, from: data)
  }

  /// Schreibt atomar: ein Abbruch mitten im Schreiben lässt die alte Datei unversehrt.
  func save(_ draft: FeedbackDraft) throws {
    try ensureDirectory()
    try JSONEncoder().encode(draft).write(to: draftURL, options: .atomic)
  }

  func storeImage(_ jpeg: Data, for id: UUID) throws {
    try ensureDirectory()
    try jpeg.write(to: imageURL(id), options: .atomic)
  }

  func imageData(for id: UUID) -> Data? { try? Data(contentsOf: imageURL(id)) }

  /// `nil` löscht die Zeichnung.
  func storeMarkup(_ data: Data?, for id: UUID) throws {
    guard let data else {
      try removeIfPresent(markupURL(id))
      return
    }
    try ensureDirectory()
    try data.write(to: markupURL(id), options: .atomic)
  }

  func markupData(for id: UUID) -> Data? { try? Data(contentsOf: markupURL(id)) }

  /// Löscht Bild und Zeichnung; `draft.json` bleibt Sache des Aufrufers (`save`).
  func removeAttachment(_ id: UUID) throws {
    try removeIfPresent(imageURL(id))
    try removeIfPresent(markupURL(id))
  }

  /// Löscht `draft.json` und alle Bilder und Zeichnungen.
  func discard() throws {
    guard fileManager.fileExists(atPath: directory.path) else { return }
    let items = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    for item in items where ["json", "jpg", "drawing"].contains(item.pathExtension) {
      try fileManager.removeItem(at: item)
    }
  }

  private func ensureDirectory() throws {
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
  }

  private func removeIfPresent(_ url: URL) throws {
    if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
  }
}

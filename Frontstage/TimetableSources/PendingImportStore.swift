import Foundation
import FrontstageCore

/// Hält den Stand einer Abfrage, dessen Stundenplan-Teil noch auf die Vorschau wartet.
/// Eine Datei nur auf diesem Gerät (nicht gespiegelt); sie enthält Stunden, nie Zugangsdaten.
///
/// Daneben die Prüfsumme einer verworfenen Vorschau (`TimetablePartChecksum`), ebenfalls nur auf diesem Gerät:
/// Dieselbe Vorschau soll nach der nächsten Abfrage nicht wiederkommen (Nachtrag 2).
struct PendingImportStore {
  private let fileURL: URL
  private let dismissedURL: URL

  init(directory: URL) {
    fileURL = directory.appendingPathComponent("pending-import.json")
    dismissedURL = directory.appendingPathComponent("dismissed-preview-checksum.txt")
  }

  /// Standardort: `Application Support/TimetableSources`.
  static func defaultDirectory() -> URL {
    URL.applicationSupportDirectory.appendingPathComponent("TimetableSources", isDirectory: true)
  }

  /// Fehlt die Datei oder ist sie unlesbar → `nil`.
  func load() -> SourceSnapshot? {
    guard let data = try? Data(contentsOf: fileURL) else { return nil }
    return try? JSONDecoder().decode(SourceSnapshot.self, from: data)
  }

  /// `nil` löscht die Datei.
  func save(_ snapshot: SourceSnapshot?) throws {
    guard let snapshot else {
      if FileManager.default.fileExists(atPath: fileURL.path) {
        try FileManager.default.removeItem(at: fileURL)
      }
      return
    }
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
  }

  /// Fehlt die Datei oder ist sie unlesbar → `nil` (dann erscheint die Vorschau eben noch einmal).
  func loadDismissedChecksum() -> String? {
    guard let data = try? Data(contentsOf: dismissedURL) else { return nil }
    let text = String(decoding: data, as: UTF8.self)
    return text.isEmpty ? nil : text
  }

  /// `nil` löscht die Datei.
  func saveDismissedChecksum(_ checksum: String?) throws {
    guard let checksum else {
      if FileManager.default.fileExists(atPath: dismissedURL.path) {
        try FileManager.default.removeItem(at: dismissedURL)
      }
      return
    }
    try FileManager.default.createDirectory(
      at: dismissedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(checksum.utf8).write(to: dismissedURL, options: .atomic)
  }
}

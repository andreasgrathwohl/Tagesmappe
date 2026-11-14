import Foundation
import FrontstageCore

/// Hält den Stand einer Abfrage, dessen Stundenplan-Teil noch auf die Vorschau wartet.
/// Eine Datei nur auf diesem Gerät (nicht gespiegelt); sie enthält Stunden, nie Zugangsdaten.
struct PendingImportStore {
  private let fileURL: URL

  init(directory: URL) {
    fileURL = directory.appendingPathComponent("pending-import.json")
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
}

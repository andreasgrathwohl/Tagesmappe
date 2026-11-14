import Foundation
import FrontstageCore
import OSLog

/// Warteliste der Umbenennungen von Notiz-Dateien (ADR-0011): `Application Support/PenNotes/pending-moves.json`,
/// aus Sicherungen ausgenommen und nur auf diesem Gerät (wird nie abgeglichen).
///
/// Ein Eintrag steht dort, **bevor** die erste Datei angefasst wird; bricht die App oder die Verbindung ab,
/// holt der nächste Durchgang den Rest nach. Die Datei enthält nur Verweis und Schlüsseltexte – keine Inhalte.
@MainActor final class PendingPenNoteMoves {
  /// Ein ausstehender Umzug derselben Datei von Stunde `fromKeyText` nach `toKeyText`.
  struct Entry: Codable, Hashable, Sendable {
    var id: UUID
    var folderGrantName: String
    var relativePath: String
    var displayName: String
    var fileKindRaw: String
    var fromKeyText: String
    var toKeyText: String

    init(id: UUID = UUID(), move: PenNoteMove) {
      self.id = id
      folderGrantName = move.reference.folderGrantName
      relativePath = move.reference.relativePath
      displayName = move.reference.displayName
      fileKindRaw = move.reference.fileKind.rawValue
      fromKeyText = move.from.storageText
      toKeyText = move.to.storageText
    }

    /// Verweis auf die Datei; die OneDrive-Kennungen werden bewusst nicht gespeichert (Ort über Freigabe + Pfad).
    var reference: MaterialReference {
      let kind =
        MaterialFileKind(rawValue: fileKindRaw)
        ?? MaterialFileKind(fileExtension: (displayName as NSString).pathExtension)
      return MaterialReference(
        folderGrantName: folderGrantName, relativePath: relativePath, displayName: displayName, fileKind: kind)
    }
  }

  private let fileURL: URL
  private var entries: [Entry]

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "PenNotes")

  static var defaultFileURL: URL {
    let base =
      (try? FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
      ?? FileManager.default.temporaryDirectory
    return base.appending(path: "PenNotes", directoryHint: .isDirectory).appending(path: "pending-moves.json")
  }

  init(fileURL: URL = PendingPenNoteMoves.defaultFileURL) {
    self.fileURL = fileURL
    // Eine unlesbare Datei gilt als leere Warteliste.
    if let data = try? Data(contentsOf: fileURL) {
      entries = (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    } else {
      entries = []
    }
  }

  /// Ausstehende Umzüge in der Reihenfolge, in der sie entstanden sind.
  func load() -> [Entry] { entries }

  /// Hängt Umzüge an und speichert sofort (synchron), bevor eine Datei angefasst wird.
  func append(_ moves: [PenNoteMove]) {
    guard !moves.isEmpty else { return }
    entries += moves.map { Entry(move: $0) }
    save()
  }

  func remove(_ entry: Entry) {
    entries.removeAll { $0.id == entry.id }
    save()
  }

  private func save() {
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
      var url = fileURL
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try url.setResourceValues(values)
    } catch {
      // Der Stand im Speicher bleibt gültig; der nächste Durchgang läuft damit weiter.
      Self.logger.error("Warteliste der Notiz-Umzüge nicht gespeichert")
    }
  }
}

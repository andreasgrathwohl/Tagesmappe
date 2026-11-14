import Foundation
import FrontstageCore
import OSLog

/// Buch des Abgleichs je Gerät: `Application Support/DataFolderLedger.json`, aus Sicherungen ausgenommen
/// (das Buch gehört zu diesem Gerät und wird nie abgeglichen oder gesichert).
///
/// Der Stand wird beim Anlegen einmal gelesen und danach im Speicher gehalten; jedes Setzen schreibt atomar
/// (erst in eine Hilfsdatei, dann ersetzen – eine abgebrochene Schreibung hinterlässt nie ein halbes Buch).
@MainActor final class LedgerStore {
  private let fileURL: URL
  private var cached: SyncLedger?

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "DataFolderSync")

  static var defaultFileURL: URL {
    let base =
      (try? FileManager.default.url(
        for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
      ?? FileManager.default.temporaryDirectory
    return base.appending(path: "DataFolderLedger.json")
  }

  init(fileURL: URL = LedgerStore.defaultFileURL) {
    self.fileURL = fileURL
    // Eine unlesbare Datei gilt als „kein Buch“: der Abgleich beginnt dann neu (Dateien werden erneut gelesen).
    if let data = try? Data(contentsOf: fileURL) {
      cached = try? JSONDecoder().decode(SyncLedger.self, from: data)
    }
  }

  /// Das Buch; `nil` = noch keines angelegt. Setzen schreibt atomar, `nil` entfernt die Datei.
  var ledger: SyncLedger? {
    get { cached }
    set {
      cached = newValue
      guard let newValue else {
        remove()
        return
      }
      write(newValue)
    }
  }

  /// Entfernt Datei und Stand (z. B. beim Wechsel des Datenorts).
  func remove() {
    cached = nil
    try? FileManager.default.removeItem(at: fileURL)
  }

  private func write(_ ledger: SyncLedger) {
    do {
      try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      let data = try JSONEncoder().encode(ledger)
      try data.write(to: fileURL, options: .atomic)
      var url = fileURL
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try url.setResourceValues(values)
    } catch {
      // Der Stand im Speicher bleibt gültig; der nächste Durchgang schreibt erneut.
      Self.logger.error("Buch nicht gespeichert: \(String(describing: error), privacy: .public)")
    }
  }
}

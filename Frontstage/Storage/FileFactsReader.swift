import Foundation
import FrontstageCore

/// Liest die iCloud-Ressourcenwerte einer Datei und fasst sie als `FileFacts` zusammen.
/// Nur lesend: Ressourcenwerte und `fileExists`, kein Schreibaufruf.
enum FileFactsReader {
  private static let keys: Set<URLResourceKey> = [
    .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
    .ubiquitousItemIsDownloadingKey, .ubiquitousItemDownloadingErrorKey,
  ]

  /// Die Freigabe gilt als aufgelöst (`grantResolved`); fehlt die Datei, ist `exists` false.
  /// Den Zugriff auf die Freigabe (security-scoped) öffnet der Aufrufer.
  static func facts(at url: URL) -> FileFacts {
    guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
      return FileFacts(grantResolved: true, exists: false, isUbiquitous: false)
    }
    let values = try? url.resourceValues(forKeys: keys)
    let status: DownloadStatus?
    switch values?.ubiquitousItemDownloadingStatus {
    case .some(.current): status = .current
    case .some(.downloaded): status = .downloaded
    case .some(.notDownloaded): status = .notDownloaded
    default: status = nil
    }
    return FileFacts(
      grantResolved: true, exists: true,
      isUbiquitous: values?.isUbiquitousItem ?? false,
      downloadStatus: status,
      isDownloading: values?.ubiquitousItemIsDownloading ?? false,
      // Über Ressourcenwerte liefert das System keinen Fortschrittsbruchteil.
      downloadFraction: nil,
      hasDownloadError: values?.ubiquitousItemDownloadingError != nil)
  }
}

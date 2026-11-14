import Foundation
import FrontstageCore

/// Fehler beim Zugriff auf den Datenordner (ADR-0012). Meldungen enthalten nie ein Token.
enum RemoteDataFolderError: Error, Equatable {
  /// Kein Netz.
  case offline
  /// Zustimmung fehlt oder Anmeldung ist abgelaufen.
  case signInRequired
  /// `If-Match` passt nicht mehr (HTTP 412): Die Datei wurde zwischenzeitlich geändert.
  case preconditionFailed(path: String)
  /// Der Delta-Link ist abgelaufen (HTTP 410): Neu-Aufzählung nötig.
  case resyncRequired
  /// Zu viele Anfragen (429/503); `retryAfter` in Sekunden, wenn der Server ihn nennt.
  case throttled(retryAfter: Int?)
  /// Pfad ist kein gültiger Pfad des Datenordners (`RemoteLayout.isValidPath`); es wurde nichts gesendet.
  case invalidPath(String)
  /// Anderer, unerwarteter HTTP-Status.
  case server(Int)
}

/// Kennungen des App-Ordners auf OneDrive.
struct AppFolderInfo: Equatable, Sendable {
  let driveID: String
  let folderItemID: String
}

/// Eine Seite der Delta-Aufzählung. `nextLink` = es folgt eine weitere Seite, `deltaLink` = Ende, Stand merken.
struct DeltaPage: Sendable {
  let items: [RemoteItem]
  let nextLink: String?
  let deltaLink: String?
}

/// Schmale Sicht auf den Datenordner; `OneDriveDataClient` spricht Graph, Tests nutzen `InMemoryRemoteDataFolder`.
protocol RemoteDataFolder: Sendable {
  func appFolder() async throws -> AppFolderInfo
  /// `link == nil` = erste Aufzählung; sonst `nextLink` oder `deltaLink`. 410 → `resyncRequired`.
  func delta(link: String?) async throws -> DeltaPage
  /// Rückfall ohne Delta (Q-33): alle Elemente der Modellordner und `library.json`.
  func listAll() async throws -> [RemoteItem]
  func download(itemID: String) async throws -> Data
  /// Nur gültige Pfade (`RemoteLayout.isValidPath` / `libraryPath`). `ifMatch` gesetzt → Kopf `If-Match`;
  /// 412 → `preconditionFailed`.
  func upload(_ data: Data, to path: String, ifMatch: String?) async throws -> RemoteFile
  /// `If-Match: file.eTag`; 404 gilt als erledigt.
  func delete(_ file: RemoteFile) async throws
  /// Je `SyncModel` ein Ordner; 409 (existiert schon) gilt als vorhanden.
  func ensureModelFolders() async throws
}

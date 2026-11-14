import Foundation
import FrontstageCore

/// Findet zu Ordnerfreigaben den passenden OneDrive-Ordner und löst Materialverweise zu Graph-Elementen auf.
@MainActor final class OneDriveService {
  private let account: MicrosoftAccount
  private let graph: GraphClient
  private let grants: FolderGrantStore
  /// Die lokalen Namen kommen direkt aus dem Ordnerinhalt der Freigabe; der Auflöser bleibt
  /// für spätere Aufrufer (Task 11) in der Abhängigkeitsliste.
  private let resolver: MaterialResolver
  /// Sitzungsspeicher: Ort des Verweises (`locationKey`) → Element. Gilt nur für das Konto `cacheOwner`;
  /// beim Abmelden oder Kontowechsel wird er geleert, nach einem gescheiterten Öffnen je Ort (`forgetItem`).
  private var cache: [String: OneDriveItem] = [:]
  private var cacheOwner: String?

  init(account: MicrosoftAccount, graph: GraphClient, grants: FolderGrantStore, resolver: MaterialResolver) {
    self.account = account
    self.graph = graph
    self.grants = grants
    self.resolver = resolver
  }

  /// Für jede Freigabe ohne `oneDrivePath`: Kandidaten (längster zuerst) abfragen; der erste, dessen
  /// Kinder alle lokalen Namen enthalten, wird gespeichert. Ein Netz- oder Anmeldefehler bricht still ab –
  /// der nächste Anstoß (Anmeldung, Netz zurück) versucht es erneut.
  func detectOneDriveFolders() async {
    guard account.isSignedIn else { return }
    for grant in grants.grants where grant.oneDrivePath == nil {
      guard let folderURL = grants.resolvedURL(for: grant) else { continue }
      let localNames = Self.localNames(in: folderURL)
      let components = StoragePath.normalizedComponents(folderURL.path(percentEncoded: false))
      for candidate in OneDriveFolderMatching.candidatePaths(localFolderComponents: components) {
        do {
          guard let remote = try await graph.childNames(atRootPath: candidate) else { continue }
          if OneDriveFolderMatching.childrenMatch(local: localNames, remote: remote) {
            grants.setOneDrivePath(id: grant.id, candidate)
            break
          }
        } catch {
          return
        }
      }
    }
  }

  /// Element zum Verweis: über gespeicherte Kennung, sonst über `oneDrivePath` der Freigabe + `relativePath`.
  /// Neue Kennungen liest der Aufrufer aus dem Ergebnis und schreibt sie zurück (Task 11).
  func item(for reference: MaterialReference) async throws -> OneDriveItem? {
    if cacheOwner != account.signedInUsername {
      cache = [:]
      cacheOwner = account.signedInUsername
    }
    guard account.isSignedIn else { return nil }
    if let cached = cache[reference.locationKey] { return cached }

    if let itemID = reference.oneDriveItemID, !itemID.isEmpty,
      let driveID = reference.oneDriveDriveID, !driveID.isEmpty,
      let found = try await graph.item(driveID: driveID, itemID: itemID)
    {
      cache[reference.locationKey] = found
      return found
    }
    // Kennung unbekannt oder veraltet (404): über den Pfad suchen.
    guard let grant = grants.grant(named: reference.folderGrantName), let base = grant.oneDrivePath else { return nil }
    guard let found = try await graph.item(atRootPath: base + "/" + reference.relativePath) else { return nil }
    cache[reference.locationKey] = found
    return found
  }

  /// Vergisst das gespeicherte Element des Ortes, z. B. nachdem das Öffnen damit gescheitert ist.
  func forgetItem(for reference: MaterialReference) {
    cache[reference.locationKey] = nil
  }

  /// Namen im Ordner (nur eine Ebene), im Zugriffsfenster der Freigabe.
  private static func localNames(in folderURL: URL) -> [String] {
    let accessing = folderURL.startAccessingSecurityScopedResource()
    defer { if accessing { folderURL.stopAccessingSecurityScopedResource() } }
    return (try? FileManager.default.contentsOfDirectory(atPath: folderURL.path(percentEncoded: false))) ?? []
  }
}

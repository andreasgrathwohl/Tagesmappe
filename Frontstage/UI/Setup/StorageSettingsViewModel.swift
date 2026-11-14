import FrontstageCore
import Foundation
import Observation

/// Folge des Abmeldens von Microsoft (ADR-0012): bei Datenort OneDrive hält der Abgleich an.
enum MicrosoftSignOutImpact: Equatable {
  case noImpact
  case stopsDataFolderSync
}

/// Logik von „Einrichten › Ablage“ (FR-3): Ordnerfreigaben dieses Geräts, Freigaben, die nur auf
/// anderen Geräten bestehen, und das Microsoft-Konto.
///
/// Swift-Hinweis: Die Freigaben liegen in `StorageService` (`@Observable`). `grants` liest sie als
/// berechnete Eigenschaft durch, damit SwiftUI Änderungen (etwa den nachträglich erkannten
/// OneDrive-Pfad) ohne eigene Kopie mitbekommt.
@MainActor @Observable final class StorageSettingsViewModel {
  private let environment: AppEnvironment
  private let account: MicrosoftAccount

  /// Freigaben auf diesem Gerät.
  var grants: [FolderGrant] { environment.storage.grants }
  /// Gespiegelte Namen aus Zuordnungen; wird mit `reload()` aktualisiert.
  private var mirroredNames: Set<String>

  init(environment: AppEnvironment, account: MicrosoftAccount) {
    self.environment = environment
    self.account = account
    self.mirroredNames = (try? environment.store.folderGrantNames()) ?? []
  }

  /// Liest die gespiegelten Namen neu (auch nach Änderungen vom anderen Gerät).
  func reload() {
    mirroredNames = (try? environment.store.folderGrantNames()) ?? []
  }

  /// Gespiegelte Namen aus Zuordnungen ohne lokale Freigabe, sortiert.
  var missingOnThisDevice: [String] {
    let local = Set(grants.map { Self.key($0.name) })
    return mirroredNames.filter { !local.contains(Self.key($0)) }
      .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
  }

  func suggestion(for folderURL: URL) -> GrantNameSuggestion {
    environment.storage.suggestedGrantName(for: folderURL)
  }

  /// Legt eine Freigabe an. Fehler: `FolderGrantError` (Name belegt, Zugriff verweigert, kein Bookmark).
  func add(folderURL: URL, name: String) async throws {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    _ = try await environment.storage.addGrant(folderURL: folderURL, name: trimmed)
    reload()
  }

  /// Entfernt nur die Freigabe dieses Geräts; Zuordnungen und ihre gespiegelten Namen bleiben.
  func remove(id: UUID) {
    environment.storage.removeGrant(id: id)
    reload()
  }

  // MARK: Microsoft

  var isSignedIn: Bool { account.isSignedIn }
  var isConfigured: Bool { account.isConfigured }
  var signedInUsername: String? { account.signedInUsername }

  /// Interaktive Anmeldung (Knopf „Bei Microsoft anmelden“). Stille Tokens holt der Datenordner-Abgleich selbst.
  func signIn(anchor: AuthPresentationAnchor) async throws {
    try await account.signIn(anchor: anchor)
  }

  /// `.stopsDataFolderSync`, wenn der Datenort OneDrive ist und ein Konto angemeldet ist.
  func signOutImpact() -> MicrosoftSignOutImpact {
    environment.dataLocation() == .oneDrive && account.isSignedIn ? .stopsDataFolderSync : .noImpact
  }

  /// Ohne Bestätigung bei `.stopsDataFolderSync`: nichts tun, `false`. Sonst abmelden, `true`.
  func signOut(confirmed: Bool) async -> Bool {
    if signOutImpact() == .stopsDataFolderSync && !confirmed { return false }
    await account.signOut()
    return true
  }

  /// Namen gelten ohne Groß-/Kleinschreibung und in NFC als gleich (wie in `FolderGrantStore`).
  private static func key(_ name: String) -> String {
    name.precomposedStringWithCanonicalMapping.lowercased()
  }
}

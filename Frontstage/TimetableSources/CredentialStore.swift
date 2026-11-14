import Foundation

/// Zugangsdaten zu Schulmanager Online. Nur im Schlüsselbund, nie in Dateien, `UserDefaults` oder SwiftData.
struct SchulmanagerCredentials: Codable, Equatable, Sendable {
  var username: String
  var password: String
}

/// Fehler beim Zugriff auf den Schlüsselbund. Trägt nur den `OSStatus`, nie Zugangsdaten.
enum CredentialStoreError: Error, Equatable {
  case keychain(status: Int32)
  case corruptEntry
}

/// Ablage der Zugangsdaten (NFR-4, AK-20).
protocol CredentialStore: Sendable {
  func load() throws -> SchulmanagerCredentials?
  /// Ersetzt vorhandene Zugangsdaten.
  func save(_ credentials: SchulmanagerCredentials) throws
  func delete() throws
}

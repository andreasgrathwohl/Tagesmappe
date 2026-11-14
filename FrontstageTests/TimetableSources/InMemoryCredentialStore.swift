import Foundation

@testable import Frontstage

/// Zugangsdaten im Arbeitsspeicher statt im Schlüsselbund; zählt das Löschen.
///
/// Swift-Hinweis: `@unchecked Sendable` verspricht dem Compiler Thread-Sicherheit, die hier das `NSLock`
/// herstellt (die Quelle liest im abgekoppelten Task, der Koordinator auf dem Haupt-Thread).
final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
  static let sample = SchulmanagerCredentials(
    username: "lehrkraft@example.com", password: "Beispiel-Passwort-1")

  private let lock = NSLock()
  private var stored: SchulmanagerCredentials?
  private var _deletions = 0

  init(_ stored: SchulmanagerCredentials? = InMemoryCredentialStore.sample) {
    self.stored = stored
  }

  var deletions: Int { lock.withLock { _deletions } }

  func load() throws -> SchulmanagerCredentials? { lock.withLock { stored } }

  func save(_ credentials: SchulmanagerCredentials) throws { lock.withLock { stored = credentials } }

  func delete() throws {
    lock.withLock {
      stored = nil
      _deletions += 1
    }
  }
}

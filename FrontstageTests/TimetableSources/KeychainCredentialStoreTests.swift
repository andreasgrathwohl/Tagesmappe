import Foundation
import Security
import Testing

@testable import Frontstage

/// Einmalige Sondierung, ob der Testlauf Schlüsselbundzugriff hat. Ein unsignierter Testhost
/// (CI, `CODE_SIGNING_ALLOWED=NO`) bekommt `errSecMissingEntitlement` (-34018); nur dann gilt
/// „nicht verfügbar“. Jeder andere Status zählt als verfügbar, damit echte Fehler nicht
/// stillschweigend übersprungen werden.
enum KeychainAvailability {
  static let isAvailable: Bool = {
    let attributes: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "frontstage.tests.keychain-probe",
      kSecAttrAccount as String: "probe",
      kSecValueData as String: Data([0]),
      kSecUseDataProtectionKeychain as String: true,
    ]
    let status = SecItemAdd(attributes as CFDictionary, nil)
    if status == errSecSuccess || status == errSecDuplicateItem {
      let remove: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "frontstage.tests.keychain-probe",
        kSecAttrAccount as String: "probe",
        kSecUseDataProtectionKeychain as String: true,
      ]
      SecItemDelete(remove as CFDictionary)
    }
    return status != errSecMissingEntitlement
  }()
}

@Suite struct KeychainCredentialStoreTests {
  private let credentials = SchulmanagerCredentials(username: "max@example.com", password: "Beispiel-Passwort-1")

  private func makeStore() -> (KeychainCredentialStore, String) {
    let service = "frontstage.tests.\(UUID())"
    return (KeychainCredentialStore(service: service), service)
  }

  @Test("Zugangsdaten nur im Schlüsselbund, gerätegebunden (NFR-4, AK-20)",
    .enabled(if: KeychainAvailability.isAvailable, "Kein Schlüsselbund ohne Signatur (CI); AK-20 wird am Gerät geprüft"))
  func credentialsAreDeviceOnlyAndNotSynchronizable() throws {
    let (store, service) = makeStore()
    defer { try? store.delete() }
    try store.save(credentials)

    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
      kSecUseDataProtectionKeychain as String: true,
      kSecReturnAttributes as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    #expect(SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess)
    let attributes = try #require(item as? [String: Any])
    #expect(
      attributes[kSecAttrAccessible as String] as? String
        == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    // Nicht synchronisiert: Das Attribut steht auf false (0).
    #expect((attributes[kSecAttrSynchronizable as String] as? Bool ?? false) == false)

    // Das Passwort erscheint in keinem Eintrag der Benutzer-Voreinstellungen.
    let defaultsText = String(describing: UserDefaults.standard.dictionaryRepresentation())
    #expect(!defaultsText.contains("Beispiel-Passwort-1"))
  }

  @Test("Speichern, Laden, Ersetzen und Löschen",
    .enabled(if: KeychainAvailability.isAvailable, "Kein Schlüsselbund ohne Signatur (CI); AK-20 wird am Gerät geprüft"))
  func saveLoadDeleteRoundTrip() throws {
    let (store, _) = makeStore()
    defer { try? store.delete() }
    #expect(try store.load() == nil)
    try store.save(credentials)
    #expect(try store.load() == credentials)
    let replaced = SchulmanagerCredentials(username: "erika@example.com", password: "Beispiel-Passwort-2")
    try store.save(replaced)
    #expect(try store.load() == replaced)
    try store.delete()
    #expect(try store.load() == nil)
  }
}

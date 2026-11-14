import Foundation
import Security

/// Ein Eintrag `kSecClassGenericPassword`, Dienst `service`, Konto „schulmanager-online“,
/// Wert = JSON der Zugangsdaten. Gerätegebunden und nicht synchronisiert (NFR-4).
struct KeychainCredentialStore: CredentialStore {
  private let service: String
  private static let account = "schulmanager-online"

  init(service: String = "frontstage.timetable-source") {
    self.service = service
  }

  /// Gemeinsame Schlüssel jeder Abfrage. `kSecUseDataProtectionKeychain` sorgt dafür, dass der Mac
  /// denselben (gerätegebundenen) Schlüsselbund wie iOS nutzt statt des Anmelde-Schlüsselbunds.
  private var baseQuery: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: Self.account,
      kSecAttrSynchronizable as String: false,
      kSecUseDataProtectionKeychain as String: true,
    ]
  }

  func load() throws -> SchulmanagerCredentials? {
    var query = baseQuery
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess else { throw CredentialStoreError.keychain(status: status) }
    guard let data = item as? Data,
      let credentials = try? JSONDecoder().decode(SchulmanagerCredentials.self, from: data)
    else { throw CredentialStoreError.corruptEntry }
    return credentials
  }

  func save(_ credentials: SchulmanagerCredentials) throws {
    let data = try JSONEncoder().encode(credentials)
    try delete()
    var query = baseQuery
    query[kSecValueData as String] = data
    // Nach dem ersten Entsperren lesbar (Hintergrund-Aktualisierung), wandert nicht auf ein neues Gerät.
    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else { throw CredentialStoreError.keychain(status: status) }
  }

  func delete() throws {
    let status = SecItemDelete(baseQuery as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw CredentialStoreError.keychain(status: status)
    }
  }
}

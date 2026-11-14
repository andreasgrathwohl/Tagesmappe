import CommonCrypto
import Foundation

/// Passwort-Hash für die Anmeldung bei Schulmanager Online (inoffizielle Schnittstelle, siehe
/// `rwunsch/schulmanager-online-hass`, `api.py`). CryptoKit kennt kein PBKDF2, daher CommonCrypto.
enum SchulmanagerPasswordHash {
  private static let rounds: UInt32 = 99_999
  private static let outputLength = 512

  /// PBKDF2-HMAC-SHA512, 99 999 Runden, 512 Byte, Salz als UTF-8, Ausgabe Kleinbuchstaben-Hex (1024 Zeichen).
  static func make(password: String, salt: String) -> String {
    let passwordBytes = Array(password.utf8)
    let saltBytes = Array(salt.utf8)
    var derived = [UInt8](repeating: 0, count: outputLength)
    // `CCKeyDerivationPBKDF` ist eine C-Funktion: Swift-Arrays werden als Zeiger übergeben,
    // die Zeiger gelten nur innerhalb des jeweiligen Closures. Die C-Signatur erwartet
    // `UnsafePointer<Int8>?` für Passwort und `UnsafePointer<UInt8>?` für das Salz.
    let status: Int32 = passwordBytes.withUnsafeBufferPointer { pw in
      saltBytes.withUnsafeBufferPointer { sl in
        derived.withUnsafeMutableBufferPointer { out in
          pw.withMemoryRebound(to: Int8.self) { pwChars in
            CCKeyDerivationPBKDF(
              CCPBKDFAlgorithm(kCCPBKDF2),
              pwChars.baseAddress, pwChars.count,
              sl.baseAddress, sl.count,
              CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
              rounds,
              out.baseAddress, out.count)
          }
        }
      }
    }
    // Nur bei ungültigen Parametern ungleich 0; hier sind sie fest.
    precondition(status == Int32(kCCSuccess), "PBKDF2 mit festen Parametern fehlgeschlagen")
    return derived.map { String(format: "%02x", $0) }.joined()
  }
}

import Foundation
import FrontstageCore

/// Hält den security-scoped Zugriff auf eine Freigabe und beendet ihn genau einmal.
/// Eigene Klasse ohne Actor-Isolation: In Swift 6 darf `deinit` einer `@MainActor`-Klasse
/// keinen isolierten Zustand anfassen, dieses Token darf den Zugriff dagegen auch dort beenden.
final class AccessToken: @unchecked Sendable {
  private let lock = NSLock()
  private var scopeURL: URL?
  private var isOpen = true

  private static let counterLock = NSLock()
  nonisolated(unsafe) private static var openTokens = 0

  /// Zahl der Tokens, die noch nicht beendet wurden (Testhilfe).
  static var openCount: Int {
    counterLock.lock()
    defer { counterLock.unlock() }
    return openTokens
  }

  /// Ruft `startAccessing…`; nur ein `true` wird später durch `stop…` beantwortet.
  init(scopeURL: URL) {
    if scopeURL.startAccessingSecurityScopedResource() { self.scopeURL = scopeURL }
    Self.counterLock.lock()
    Self.openTokens += 1
    Self.counterLock.unlock()
  }

  /// Beendet den Zugriff; jeder weitere Aufruf tut nichts.
  func stop() {
    lock.lock()
    let wasOpen = isOpen
    isOpen = false
    let scoped = scopeURL
    scopeURL = nil
    lock.unlock()
    guard wasOpen else { return }
    scoped?.stopAccessingSecurityScopedResource()
    Self.counterLock.lock()
    Self.openTokens -= 1
    Self.counterLock.unlock()
  }

  deinit { stop() }
}

/// Lesender Zugriff auf eine Datei der Ablage für Anzeige (Teilplan 06) und Tafel-Vorlage (Teilplan 07).
/// Der Zugriff auf die Freigabe bleibt offen, bis `close()` kommt oder das Objekt verschwindet.
@MainActor final class ScopedFile {
  let url: URL
  let reference: MaterialReference
  private let token: AccessToken

  /// Zahl der offenen (nicht geschlossenen) Zugriffe – nur für Tests.
  static var openCount: Int { AccessToken.openCount }

  init(url: URL, reference: MaterialReference, grantURL: URL) {
    self.url = url
    self.reference = reference
    self.token = AccessToken(scopeURL: grantURL)
  }

  /// Beendet den Zugriff; ein zweiter Aufruf tut nichts.
  func close() { token.stop() }
}

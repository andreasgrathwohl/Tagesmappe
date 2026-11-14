import Foundation
import Observation

@preconcurrency import MSAL

#if os(iOS)
  import UIKit
  typealias AuthPresentationAnchor = UIViewController
#else
  import AppKit
  typealias AuthPresentationAnchor = NSViewController
#endif

enum MicrosoftAccountError: Error, Equatable {
  case notConfigured, interactionRequired, cancelled, failed(String)
}

/// Hülle um MSAL – die einzige Stelle der App, die MSAL anfasst.
///
/// Swift-Hinweis: `@preconcurrency import` stellt die MSAL-Typen (Objective-C, ohne `Sendable`-Angaben)
/// von Swift 6s strenger Nebenläufigkeitsprüfung frei. Die Rückrufe liefern deshalb nur `Sendable`-Werte
/// (Zeichenketten), keine MSAL-Objekte, über die Fortsetzung zurück.
///
/// Der Token-Cache liegt im privaten Schlüsselbund (Gruppe = Bundle-ID, NFR-4); gespeichert wird nur die
/// Konto-Kennung in `UserDefaults`, nie ein Token.
@MainActor @Observable final class MicrosoftAccount {
  static let scopes = ["Files.Read"]
  static let authority = "https://login.microsoftonline.com/common"
  private static let accountKey = "MicrosoftAccountIdentifier"

  private(set) var signedInUsername: String?
  /// Wird nach erfolgreicher Anmeldung gerufen (StorageService stößt die Ordnererkennung an).
  @ObservationIgnored var onSignedIn: (@MainActor () async -> Void)?

  @ObservationIgnored private let isStub: Bool
  @ObservationIgnored private var application: MSALPublicClientApplication?

  var isConfigured: Bool {
    if isStub { return true }
    return !Self.clientID.isEmpty
  }

  var isSignedIn: Bool { signedInUsername != nil }

  private static var clientID: String {
    (Bundle.main.object(forInfoDictionaryKey: "MSALClientID") as? String) ?? ""
  }

  init() {
    isStub = false
    guard !Self.clientID.isEmpty, let app = try? Self.makeApplication() else { return }
    application = app
    if let identifier = UserDefaults.standard.string(forKey: Self.accountKey),
      let account = try? app.account(forIdentifier: identifier)
    {
      signedInUsername = account.username
    }
  }

  /// Nur für Tests (kein MSAL): gilt als konfiguriert und, wenn `signedInUsername` gesetzt ist, als angemeldet.
  init(signedInUsernameForTesting username: String?) {
    isStub = true
    signedInUsername = username
  }

  private static func makeApplication() throws -> MSALPublicClientApplication {
    guard let bundleID = Bundle.main.bundleIdentifier, let authorityURL = URL(string: authority) else {
      throw MicrosoftAccountError.notConfigured
    }
    let config = MSALPublicClientApplicationConfig(
      clientId: clientID, redirectUri: "msauth.\(bundleID)://auth",
      authority: try MSALAADAuthority(url: authorityURL))
    config.cacheConfig.keychainSharingGroup = bundleID
    return try MSALPublicClientApplication(configuration: config)
  }

  private func requireApplication() throws -> MSALPublicClientApplication {
    guard !isStub, isConfigured else { throw MicrosoftAccountError.notConfigured }
    if let application { return application }
    do {
      let app = try Self.makeApplication()
      application = app
      return app
    } catch {
      throw MicrosoftAccountError.failed(error.localizedDescription)
    }
  }

  /// Übersetzt MSAL-Fehler in die eigenen; die Meldung enthält nie ein Token.
  nonisolated private static func map(_ error: Error?) -> MicrosoftAccountError {
    guard let nsError = error as NSError? else { return .failed("") }
    if nsError.domain == MSALErrorDomain {
      if nsError.code == MSALError.userCanceled.rawValue { return .cancelled }
      if nsError.code == MSALError.interactionRequired.rawValue { return .interactionRequired }
    }
    return .failed(nsError.localizedDescription)
  }

  /// Ergebnis der interaktiven Anmeldung, nur aus `Sendable`-Teilen.
  private struct SignInOutcome: Sendable {
    let identifier: String
    let username: String?
  }

  func signIn(anchor: AuthPresentationAnchor) async throws {
    let app = try requireApplication()
    let webParameters = MSALWebviewParameters(authPresentationViewController: anchor)
    let parameters = MSALInteractiveTokenParameters(scopes: Self.scopes, webviewParameters: webParameters)
    let outcome: SignInOutcome = try await withCheckedThrowingContinuation { continuation in
      app.acquireToken(with: parameters) { result, error in
        if let result {
          continuation.resume(
            returning: SignInOutcome(identifier: result.account.identifier ?? "", username: result.account.username))
        } else {
          continuation.resume(throwing: Self.map(error))
        }
      }
    }
    UserDefaults.standard.set(outcome.identifier, forKey: Self.accountKey)
    signedInUsername = outcome.username ?? outcome.identifier
    await onSignedIn?()
  }

  /// Entfernt das Konto aus dem MSAL-Cache und vergisst die Kennung.
  func signOut() async {
    if let app = application, let identifier = UserDefaults.standard.string(forKey: Self.accountKey),
      let account = try? app.account(forIdentifier: identifier)
    {
      try? app.remove(account)
    }
    UserDefaults.standard.removeObject(forKey: Self.accountKey)
    signedInUsername = nil
  }

  /// Still: wirft `.interactionRequired`, wenn eine Anmeldung nötig ist.
  func accessToken() async throws -> String {
    let app = try requireApplication()
    guard let identifier = UserDefaults.standard.string(forKey: Self.accountKey),
      let account = try? app.account(forIdentifier: identifier)
    else { throw MicrosoftAccountError.interactionRequired }
    let parameters = MSALSilentTokenParameters(scopes: Self.scopes, account: account)
    return try await withCheckedThrowingContinuation { continuation in
      app.acquireTokenSilent(with: parameters) { result, error in
        if let result {
          continuation.resume(returning: result.accessToken)
        } else {
          continuation.resume(throwing: Self.map(error))
        }
      }
    }
  }

  /// iOS: reicht die Rückkehr-Adresse der Anmeldung an MSAL (aus `.onOpenURL`). macOS: immer `false`.
  static func handleRedirect(_ url: URL) -> Bool {
    #if os(iOS)
      return MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
    #else
      return false
    #endif
  }

  /// `Sendable`-Hülle für `GraphClient`: springt für jedes Token auf den Hauptakteur.
  var tokenProvider: any AccessTokenProviding { Provider(account: self) }

  private struct Provider: AccessTokenProviding {
    // Eine `@MainActor`-Klasse ist implizit `Sendable`.
    let account: MicrosoftAccount
    func accessToken() async throws -> String { try await account.accessToken() }
  }
}

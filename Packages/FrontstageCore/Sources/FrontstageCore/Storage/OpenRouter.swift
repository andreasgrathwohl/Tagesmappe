import Foundation

/// Alle Fakten, die der Öffnen-Weg für eine Entscheidung braucht; die App sammelt sie.
public struct OpenContext: Sendable {
  public var fileKind: MaterialFileKind
  public var officeApp: OfficeApp?
  public var availability: MaterialAvailability
  public var isOnline: Bool
  public var isMicrosoftSignedIn: Bool
  public var isOfficeAppInstalled: Bool
  /// Aus `OfficeAddress.documentURL`; `nil` = nicht in OneDrive oder unbekannt.
  public var oneDriveDocumentURL: String?

  public init(
    fileKind: MaterialFileKind,
    officeApp: OfficeApp?,
    availability: MaterialAvailability,
    isOnline: Bool,
    isMicrosoftSignedIn: Bool,
    isOfficeAppInstalled: Bool,
    oneDriveDocumentURL: String?
  ) {
    self.fileKind = fileKind
    self.officeApp = officeApp
    self.availability = availability
    self.isOnline = isOnline
    self.isMicrosoftSignedIn = isMicrosoftSignedIn
    self.isOfficeAppInstalled = isOfficeAppInstalled
    self.oneDriveDocumentURL = oneDriveDocumentURL
  }
}

/// Wie ein Material geöffnet wird.
public indirect enum OpenRoute: Hashable, Sendable {
  /// Eigene Anzeige (Teilplan 06).
  case viewer
  /// Übergabe der Datei an die zuständige App.
  case handOff
  /// Cloud-Dokument in der Office-App (FR-5.1).
  case officeCloud(documentURL: String)
  case waitForDownload(then: OpenRoute)
  case unavailable(UnavailableReason)
}

public enum OpenRouter {
  /// Wählt den Weg; die erste passende Regel gewinnt.
  public static func route(_ context: OpenContext) -> OpenRoute {
    // Das Cloud-Dokument braucht keine lokale Kopie, der lokale Zustand zählt hier nicht.
    if let app = context.officeApp,
      context.isMicrosoftSignedIn, context.isOnline, context.isOfficeAppInstalled,
      let url = context.oneDriveDocumentURL, url.count <= app.addressLengthLimit
    {
      return .officeCloud(documentURL: url)
    }

    let target: OpenRoute = context.fileKind.opensInViewer ? .viewer : .handOff
    switch context.availability {
    case .onDevice: return target
    case .downloading: return .waitForDownload(then: target)
    case .unavailable(let reason): return .unavailable(reason)
    }
  }
}

public enum CloudOpenStep: Hashable, Sendable {
  case keepWaiting, done, fallBackToHandOff
}

/// Fristen und Rückfall beim Öffnen eines Cloud-Dokuments (FR-5.1).
public enum CloudOpenPolicy {
  public static let preparationLimit: Duration = .seconds(5)
  public static let handOverLimit: Duration = .seconds(10)
  public static let returnWindow: Duration = .seconds(60)

  /// Adresse bereit vor der Frist: fertig; Frist erreicht (`>=`): Rückfall.
  public static func afterPreparation(addressReady: Bool, elapsed: Duration) -> CloudOpenStep {
    if addressReady { return .done }
    return elapsed >= preparationLimit ? .fallBackToHandOff : .keepWaiting
  }

  /// `accepted == nil`: noch keine Antwort des Systems.
  public static func afterHandOver(accepted: Bool?, elapsed: Duration) -> CloudOpenStep {
    if let accepted { return accepted ? .done : .fallBackToHandOff }
    return elapsed >= handOverLimit ? .fallBackToHandOff : .keepWaiting
  }

  /// Das Fenster schließt die Grenze ein (60 s = angeboten).
  public static func offersOpenWithoutAutoSave(returnedAfter: Duration) -> Bool {
    returnedAfter <= returnWindow
  }
}

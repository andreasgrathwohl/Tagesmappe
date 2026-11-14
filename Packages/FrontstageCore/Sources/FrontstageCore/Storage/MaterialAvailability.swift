import Foundation

/// Abbild von `URLUbiquitousItemDownloadingStatus`, damit der Kern ohne Dateisystem testbar bleibt.
public enum DownloadStatus: Sendable {
  case current
  case downloaded
  case notDownloaded
}

/// Beobachtete Fakten über eine Datei; die App sammelt sie, der Kern bewertet sie.
public struct FileFacts: Hashable, Sendable {
  public var grantResolved: Bool
  public var exists: Bool
  public var isUbiquitous: Bool
  public var downloadStatus: DownloadStatus?
  public var isDownloading: Bool
  /// Nur wenn das System einen Fortschritt liefert, sonst `nil`.
  public var downloadFraction: Double?
  public var hasDownloadError: Bool

  public init(
    grantResolved: Bool,
    exists: Bool,
    isUbiquitous: Bool,
    downloadStatus: DownloadStatus? = nil,
    isDownloading: Bool = false,
    downloadFraction: Double? = nil,
    hasDownloadError: Bool = false
  ) {
    self.grantResolved = grantResolved
    self.exists = exists
    self.isUbiquitous = isUbiquitous
    self.downloadStatus = downloadStatus
    self.isDownloading = isDownloading
    self.downloadFraction = downloadFraction
    self.hasDownloadError = hasDownloadError
  }
}

public enum UnavailableReason: String, Hashable, Codable, Sendable {
  case grantMissing
  case fileMissing
  case notDownloadedOffline
  case downloadFailed
}

public enum MaterialAvailability: Hashable, Sendable {
  /// „auf dem Gerät“; `isCurrent == false` ist ein älterer Stand und wird nie still gezeigt.
  case onDevice(isCurrent: Bool)
  /// „wird geladen“; `progress` 0…1, nur wenn das System ihn liefert.
  case downloading(progress: Double?)
  /// „nicht verfügbar“
  case unavailable(UnavailableReason)
}

public enum AvailabilityClassifier {
  /// Bewertet die Dateifakten; die erste passende Regel gewinnt.
  public static func classify(_ facts: FileFacts, isOnline: Bool) -> MaterialAvailability {
    if !facts.grantResolved { return .unavailable(.grantMissing) }
    if !facts.exists { return .unavailable(.fileMissing) }
    if !facts.isUbiquitous { return .onDevice(isCurrent: true) }
    if facts.downloadStatus == .current { return .onDevice(isCurrent: true) }
    if facts.isDownloading { return .downloading(progress: facts.downloadFraction) }
    if facts.downloadStatus == .downloaded { return .onDevice(isCurrent: false) }
    if facts.hasDownloadError { return .unavailable(.downloadFailed) }
    if !isOnline { return .unavailable(.notDownloadedOffline) }
    // Online und noch nicht geladen: Das Bereithalten stößt den Download an.
    return .downloading(progress: nil)
  }
}

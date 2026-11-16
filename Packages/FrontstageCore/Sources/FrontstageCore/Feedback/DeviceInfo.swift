import Foundation

/// Geräteangaben für die Rückmeldung (FR-17.3): nur technische Werte, nie Namen oder Inhalte.
public struct DeviceInfo: Hashable, Codable, Sendable {
  public var appVersion: String
  public var build: String
  public var systemName: String
  public var systemVersion: String
  public var modelIdentifier: String
  public var dataLocation: DataLocation
  public var theme: Theme
  public var isUnlocked: Bool
  public var languageCode: String

  public init(appVersion: String, build: String, systemName: String, systemVersion: String, modelIdentifier: String,
              dataLocation: DataLocation, theme: Theme, isUnlocked: Bool, languageCode: String) {
    self.appVersion = appVersion
    self.build = build
    self.systemName = systemName
    self.systemVersion = systemVersion
    self.modelIdentifier = modelIdentifier
    self.dataLocation = dataLocation
    self.theme = theme
    self.isUnlocked = isUnlocked
    self.languageCode = languageCode
  }

  /// Zeilen für den Mailtext (Entscheidung 6, wörtlich).
  public var reportLines: [String] {
    let tone: String
    switch theme.baseTone {
    case .warm: tone = "warm"
    case .system: tone = "System"
    case .cool: tone = "kühl"
    case .petrol: tone = "Petrol"
    }
    let accent = theme.accent.map { "Akzent \($0.hex)" } ?? "Standardakzent"
    let mode: String
    switch theme.appearanceMode {
    case .system: mode = "wie das System"
    case .light: mode = "hell"
    case .dark: mode = "dunkel"
    }
    return [
      "App: Frontstage \(appVersion) (\(build))",
      "System: \(systemName) \(systemVersion)",
      "Gerät: \(modelIdentifier)",
      "Datenort: \(dataLocation == .iCloud ? "iCloud" : "OneDrive")",
      "Erscheinungsbild: \(tone), \(accent), \(mode)",
      "Kauf: \(isUnlocked ? "ja" : "nein")",
      "Sprache: \(languageCode)",
    ]
  }
}

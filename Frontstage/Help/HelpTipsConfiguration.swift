import Foundation
import TipKit

/// Start der Kurz-Tipps (FR-17.5). Das Zurücksetzen wirkt erst beim nächsten Start: TipKit verlangt
/// `resetDatastore()` vor `configure()`, und im laufenden Betrieb wäre der Speicher in Benutzung.
enum HelpTipsConfiguration {
  /// Schlüssel in `UserDefaults`: „beim nächsten Start Tipps zurücksetzen“.
  static let resetKey = "help.tips.resetOnNextLaunch"

  /// Merkt vor, dass die Tipps beim nächsten Start erneut erscheinen sollen.
  static func requestReset(defaults: UserDefaults = .standard) {
    defaults.set(true, forKey: resetKey)
  }

  /// Im Testlauf nichts; sonst ggf. `reset()` und Schlüssel löschen, dann `configure()`.
  /// Die Reihenfolge ist fest (Apple: reset vor configure). Schlägt eines von beiden fehl, läuft die App weiter.
  static func configureAtLaunch(
    defaults: UserDefaults = .standard,
    isUnderTest: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
    reset: () throws -> Void = { try Tips.resetDatastore() },
    configure: () throws -> Void = { try Tips.configure([.displayFrequency(.daily)]) }
  ) {
    guard !isUnderTest else { return }
    if defaults.bool(forKey: resetKey) {
      // Schlüssel zuerst löschen: scheitert das Zurücksetzen, soll es nicht bei jedem Start wiederholt werden.
      defaults.removeObject(forKey: resetKey)
      try? reset()
    }
    try? configure()
  }
}

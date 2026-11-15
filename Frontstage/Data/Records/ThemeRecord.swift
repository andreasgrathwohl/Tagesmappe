import Foundation
import FrontstageCore
import SwiftData

/// Erscheinungsbild (FR-16): ein Datensatz für alle Geräte. Zwei Geräte, die offline je einen anlegen,
/// ergeben nach dem Abgleich zwei; `DataStore.mergeDuplicates()` führt sie zusammen.
@Model
final class ThemeRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  var baseToneRaw: String = "warm"
  /// sRGB-Hex („#RRGGBB“); `nil` = Standard-Akzent.
  var accentHex: String?
  var appearanceModeRaw: String = "system"
  var updatedAt: Date = Date.now

  init() {}
}

extension ThemeRecord {
  /// Unbekannte Rohwerte ergeben den Standard des jeweiligen Felds; ungültiges Hex den Standard-Akzent.
  func makeTheme() -> Theme {
    Theme(
      baseTone: BaseTone(rawValue: baseToneRaw) ?? Theme.standard.baseTone,
      accent: accentHex.flatMap { ThemeAccent(hex: $0) },
      appearanceMode: AppearanceMode(rawValue: appearanceModeRaw) ?? Theme.standard.appearanceMode)
  }

  /// Setzt die drei Felder; `updatedAt` bleibt Sache des Aufrufers.
  func apply(_ theme: Theme) {
    baseToneRaw = theme.baseTone.rawValue
    accentHex = theme.accent?.hex
    appearanceModeRaw = theme.appearanceMode.rawValue
  }
}

import Foundation

/// Hintergrund einer Tafelseite; wird als Rohwert in `BoardPageRecord.backgroundRaw` gespeichert.
public enum BoardBackground: String, CaseIterable, Codable, Sendable {
  case blank, lined, grid, image
}

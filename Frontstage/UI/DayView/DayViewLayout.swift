import Foundation

/// Maße der Tagesansicht.
enum DayViewLayout {
  // MARK: Maße der Tagesansicht (UI-4, UI-10)

  /// Zeilenhöhe der Liste (Mindesthöhe, skaliert mit Dynamic Type).
  static let rowHeight: CGFloat = 44
  static let rowSpacing: CGFloat = 4
  static let detailPadding: CGFloat = 16
  static let sectionSpacing: CGFloat = 16
  static let tileSpacing: CGFloat = 8
  static let tileHeight: CGFloat = 120
  /// Mindestbreite einer Kachel im adaptiven Raster.
  static let tileMinWidth: CGFloat = 200
  static let tileRadius: CGFloat = 16
  static let selectionRadius: CGFloat = 10
}

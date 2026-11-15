import Foundation

/// Zeilenhöhe der Tagesansicht: so hoch wie der Platz erlaubt, damit alle Stunden ohne Scrollen passen.
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

  // MARK: Alt (entfällt mit Task 10, wenn das alte `DayView` verschwindet)

  /// Platzhalter der offenen Gestaltungskategorie „Dichte“.
  static let minRowHeight: CGFloat = 44
  static let maxRowHeight: CGFloat = 96

  /// `nil`: Selbst die Mindesthöhe passt nicht – die Ansicht fällt auf Scrollen zurück.
  static func rowHeight(availableHeight: CGFloat, rowCount: Int, spacing: CGFloat = 8) -> CGFloat? {
    guard rowCount > 0 else { return maxRowHeight }
    let count = CGFloat(rowCount)
    let height = min(maxRowHeight, (availableHeight - spacing * (count - 1)) / count)
    return height >= minRowHeight ? height : nil
  }

  /// Höhe für „Material ohne Stunde“ unter den festen Zeilen: Trenner und Überschrift (~70 pt) plus
  /// je Eintrag ~52 pt, gedeckelt; darüber scrollt der Bereich in sich.
  static func orphanReserve(count: Int) -> CGFloat {
    guard count > 0 else { return 0 }
    return min(190, 70 + 52 * CGFloat(count))
  }
}

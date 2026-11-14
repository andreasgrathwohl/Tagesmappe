import Foundation

/// Zeilenhöhe der Tagesansicht: so hoch wie der Platz erlaubt, damit alle Stunden ohne Scrollen passen.
enum DayViewLayout {
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
}

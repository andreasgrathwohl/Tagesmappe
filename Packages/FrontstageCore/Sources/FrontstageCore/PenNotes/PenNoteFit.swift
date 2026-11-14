import Foundation

/// Seitengröße in PDF-Punkten.
public struct PageSize: Hashable, Codable, Sendable {
  public var width: Double
  public var height: Double

  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }
}

/// Passt eine gespeicherte Stiftnotiz noch zur Seite des Dokuments? (ADR-0011, Entscheidung 4)
/// Die Größe der Seite beim ersten Zeichnen steht in der Notiz-Datei; ändert sich das Dokument,
/// wird die Notiz nicht verzerrt, sondern als frühere Fassung gemeldet.
public enum PenNoteFit: Hashable, Sendable {
  /// Seite vorhanden, Größe gleich (oder unbekannt).
  case fits
  /// Seite vorhanden, aber andere Größe als beim Zeichnen.
  case sizeChanged
  /// Das Dokument hat diese Seite nicht mehr.
  case pageMissing

  /// Abweichung bis zu dieser Größe (PDF-Punkte) je Achse gilt als gleich.
  public static let tolerance: Double = 1.0

  /// - Parameters:
  ///   - savedSize: Größe beim ersten Zeichnen; `nil` oder 0 × 0 = unbekannt, gilt als passend.
  ///   - pageIndex: Seitenindex ab 0.
  ///   - pageCount: Seitenzahl des Dokuments.
  ///   - currentSize: aktuelle Größe der Seite, wenn bekannt.
  public static func evaluate(
    savedSize: PageSize?, pageIndex: Int, pageCount: Int, currentSize: PageSize?
  ) -> PenNoteFit {
    if pageIndex >= pageCount { return .pageMissing }
    guard let saved = savedSize, saved.width > 0, saved.height > 0, let current = currentSize
    else { return .fits }
    let same =
      abs(saved.width - current.width) <= tolerance && abs(saved.height - current.height) <= tolerance
    return same ? .fits : .sizeChanged
  }
}

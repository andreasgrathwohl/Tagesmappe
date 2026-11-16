import Foundation

/// Rechteck in Bildanteilen, Ursprung oben links; Werte auf 0...1 begrenzt.
public struct NormalizedRect: Hashable, Codable, Sendable {
  public let x: Double
  public let y: Double
  public let width: Double
  public let height: Double

  /// Begrenzt alle Werte auf 0...1; Breite und Höhe sind nie negativ.
  public init(x: Double, y: Double, width: Double, height: Double) {
    func clamp(_ v: Double) -> Double { min(1, max(0, v)) }
    self.x = clamp(x)
    self.y = clamp(y)
    self.width = clamp(width)
    self.height = clamp(height)
  }

  /// Aus zwei Punkten in einer Ansicht der Größe `size`; `nil`, wenn schmaler oder niedriger als 1 % der Ansicht.
  public static func spanning(from a: (x: Double, y: Double), to b: (x: Double, y: Double),
                              in size: (width: Double, height: Double)) -> NormalizedRect? {
    guard size.width > 0, size.height > 0 else { return nil }
    // Erst in Punkten an den Rand der Ansicht begrenzen, dann teilen: so bleiben die Anteile exakt.
    func clamp(_ v: Double, _ upper: Double) -> Double { min(upper, max(0, v)) }
    let x0 = clamp(min(a.x, b.x), size.width), x1 = clamp(max(a.x, b.x), size.width)
    let y0 = clamp(min(a.y, b.y), size.height), y1 = clamp(max(a.y, b.y), size.height)
    let w = (x1 - x0) / size.width
    let h = (y1 - y0) / size.height
    guard w >= 0.01, h >= 0.01 else { return nil }
    return NormalizedRect(x: x0 / size.width, y: y0 / size.height, width: w, height: h)
  }
}

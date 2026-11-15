import Foundation

/// Richtung der Kontrastverschiebung: zu Schwarz (`darken`) oder zu Weiß (`lighten`).
public enum ContrastDirection: Sendable { case darken, lighten }

/// Verschiebt eine Farbe nur so weit, wie der Mindestkontrast es verlangt.
public enum ContrastAdjuster {
  private static let steps = 30

  /// Unverändert, wenn `color` schon reicht; sonst die kleinste Verschiebung in `direction`.
  /// Erreicht selbst Schwarz bzw. Weiß das Ziel nicht, kommt Schwarz bzw. Weiß zurück.
  public static func adjusted(_ color: SRGBColor, against surfaces: [SRGBColor], minimum: Double,
                              direction: ContrastDirection) -> SRGBColor {
    if color.minimumContrast(against: surfaces) >= minimum { return color }

    func scaled(_ k: Double) -> SRGBColor {   // darken: Kanäle · k
      SRGBColor(red: Int((Double(color.red) * k).rounded()),
                green: Int((Double(color.green) * k).rounded()),
                blue: Int((Double(color.blue) * k).rounded()))
    }
    func lifted(_ t: Double) -> SRGBColor {   // lighten: Richtung Weiß
      func channel(_ c: Int) -> Int { Int((Double(c) + (255 - Double(c)) * t).rounded()) }
      return SRGBColor(red: channel(color.red), green: channel(color.green), blue: channel(color.blue))
    }
    func ok(_ candidate: SRGBColor) -> Bool { candidate.minimumContrast(against: surfaces) >= minimum }

    switch direction {
    case .darken:
      // Größtes k mit ausreichendem Kontrast; lo erfüllt das Ziel, hi nicht.
      guard ok(scaled(0)) else { return scaled(0) }
      var lo = 0.0, hi = 1.0
      for _ in 0..<steps {
        let mid = (lo + hi) / 2
        if ok(scaled(mid)) { lo = mid } else { hi = mid }
      }
      return scaled(lo)
    case .lighten:
      // Kleinstes t mit ausreichendem Kontrast; hi erfüllt das Ziel, lo nicht.
      guard ok(lifted(1)) else { return lifted(1) }
      var lo = 0.0, hi = 1.0
      for _ in 0..<steps {
        let mid = (lo + hi) / 2
        if ok(lifted(mid)) { hi = mid } else { lo = mid }
      }
      return lifted(hi)
    }
  }
}

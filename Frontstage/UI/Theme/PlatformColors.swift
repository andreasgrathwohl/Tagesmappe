import CoreGraphics
import FrontstageCore
import SwiftUI

extension SRGBColor {
  /// Konvertiert nach sRGB, begrenzt die Kanäle auf 0...1 (Display-P3 kann darüber hinaus liegen),
  /// rechnet auf 0...255 und rundet. Deckkraft ist immer 1.
  ///
  /// Swift-Hinweis: `CGColor.converted(to:intent:options:)` liefert `nil`, wenn die Umrechnung scheitert;
  /// dann gilt Schwarz als Rückfall statt eines Absturzes.
  init(cgColor: CGColor) {
    func channel(_ value: CGFloat) -> Int {
      Int((min(max(value, 0), 1) * 255).rounded())
    }
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let converted = cgColor.converted(to: space, intent: .defaultIntent, options: nil),
      let components = converted.components, components.count >= 3
    else {
      self.init(red: 0, green: 0, blue: 0)
      return
    }
    self.init(red: channel(components[0]), green: channel(components[1]), blue: channel(components[2]))
  }
}

extension Color {
  /// Feste sRGB-Farbe aus einem Kernwert; die Deckkraft bleibt erhalten (Haarlinien).
  init(_ color: SRGBColor) {
    self.init(
      .sRGB, red: Double(color.red) / 255, green: Double(color.green) / 255,
      blue: Double(color.blue) / 255, opacity: color.alpha)
  }
}

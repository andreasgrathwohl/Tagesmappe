import Foundation

/// sRGB-Farbe mit 8-Bit-Kanälen; Deckkraft nur für Haarlinien (Kontrast rechnet ohne Deckkraft).
public struct SRGBColor: Hashable, Codable, Sendable {
  public let red: Int
  public let green: Int
  public let blue: Int
  public let alpha: Double

  /// Kanäle 0...255 (Vorbedingung), Deckkraft 0...1.
  public init(red: Int, green: Int, blue: Int, alpha: Double = 1) {
    precondition((0...255).contains(red) && (0...255).contains(green) && (0...255).contains(blue),
                 "Farbkanäle müssen in 0...255 liegen")
    precondition((0...1).contains(alpha), "Deckkraft muss in 0...1 liegen")
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }

  /// Liest „#0E6B7A“ oder „0e6b7a“; alles andere ergibt `nil`.
  public init?(hex: String) {
    var digits = Substring(hex)
    if digits.first == "#" { digits = digits.dropFirst() }
    guard digits.count == 6, digits.allSatisfy({ $0.isASCII && $0.isHexDigit }),
          let value = Int(digits, radix: 16) else { return nil }
    self.init(red: (value >> 16) & 0xFF, green: (value >> 8) & 0xFF, blue: value & 0xFF)
  }

  /// „#0E6B7A“ in Großbuchstaben, ohne Deckkraft.
  public var hex: String {
    func part(_ v: Int) -> String {
      let s = String(v, radix: 16, uppercase: true)
      return s.count == 1 ? "0" + s : s
    }
    return "#" + part(red) + part(green) + part(blue)
  }

  /// Relative Leuchtdichte nach WCAG 2.x (Grenzwert 0.04045).
  public var relativeLuminance: Double {
    func linear(_ channel: Int) -> Double {
      let s = Double(channel) / 255
      return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }

  /// Kontrastverhältnis (hell + 0,05) / (dunkel + 0,05); symmetrisch, ohne Deckkraft.
  public static func contrastRatio(_ a: SRGBColor, _ b: SRGBColor) -> Double {
    let la = a.relativeLuminance, lb = b.relativeLuminance
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
  }

  /// Kontrast gegen die ungünstigste Fläche; ohne Flächen unendlich.
  public func minimumContrast(against surfaces: [SRGBColor]) -> Double {
    surfaces.map { SRGBColor.contrastRatio(self, $0) }.min() ?? .infinity
  }

  /// Deckend: `percent` Prozent dieser Farbe über `background`. Reine Ganzzahlrechnung,
  /// halb aufrunden; das Ergebnis hat Deckkraft 1.
  public func mixed(over background: SRGBColor, percent: Int) -> SRGBColor {
    precondition((0...100).contains(percent), "Prozent muss in 0...100 liegen")
    func blend(_ fg: Int, _ bg: Int) -> Int { (fg * percent + bg * (100 - percent) + 50) / 100 }
    return SRGBColor(red: blend(red, background.red), green: blend(green, background.green),
                     blue: blend(blue, background.blue))
  }

  public func withAlpha(_ alpha: Double) -> SRGBColor {
    SRGBColor(red: red, green: green, blue: blue, alpha: alpha)
  }
}

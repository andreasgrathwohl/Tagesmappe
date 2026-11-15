import Foundation

/// Neutrale Rollenfarben eines Grundtons in einem Modus.
public struct NeutralColors: Hashable, Sendable {
  public var background: SRGBColor
  public var selection: SRGBColor
  public var text: SRGBColor
  public var hairline: SRGBColor

  public init(background: SRGBColor, selection: SRGBColor, text: SRGBColor, hairline: SRGBColor) {
    self.background = background
    self.selection = selection
    self.text = text
    self.hairline = hairline
  }
}

extension BaseTone {
  /// Werte wörtlich aus DESIGN.md (UI-8). Für `.system` sind es Bezugswerte der Kontrastrechnung;
  /// die App nutzt dort die Systemfarben (`usesSystemColors`).
  public func neutrals(isDark: Bool) -> NeutralColors {
    func c(_ hex: String) -> SRGBColor {
      guard let color = SRGBColor(hex: hex) else { preconditionFailure("Ungültiger Hex-Wert \(hex)") }
      return color
    }
    func n(_ background: String, _ selection: String, _ text: String,
           _ hairline: (Int, Int, Int, Double)) -> NeutralColors {
      NeutralColors(background: c(background), selection: c(selection), text: c(text),
                    hairline: SRGBColor(red: hairline.0, green: hairline.1, blue: hairline.2, alpha: hairline.3))
    }
    switch (self, isDark) {
    case (.warm, false): return n("#FBF8F2", "#ECE5D8", "#1F1A14", (92, 72, 48, 0.22))
    case (.warm, true): return n("#17130E", "#2F2921", "#F5EFE5", (125, 108, 86, 0.55))
    case (.system, false): return n("#FFFFFF", "#E5E5EA", "#000000", (60, 60, 67, 0.29))
    case (.system, true): return n("#000000", "#2C2C2E", "#FFFFFF", (84, 84, 88, 0.60))
    case (.cool, false): return n("#F7F9FC", "#E2E8F0", "#0F172A", (51, 65, 85, 0.20))
    case (.cool, true): return n("#0B1120", "#1E293B", "#EEF2F7", (71, 85, 105, 0.60))
    case (.petrol, false): return n("#F6F9F9", "#DFE9EA", "#0C1F23", (14, 75, 87, 0.18))
    case (.petrol, true): return n("#061416", "#15292C", "#ECF4F4", (60, 100, 106, 0.55))
    }
  }

  /// Nur „System“ nutzt in der App die Systemfarben.
  public var usesSystemColors: Bool { self == .system }
}

import Foundation

/// Grundton der neutralen Flächen (FR-16, UI-8).
public enum BaseTone: String, CaseIterable, Codable, Sendable { case warm, system, cool, petrol }

/// Hell, dunkel oder wie das System (FR-16).
public enum AppearanceMode: String, CaseIterable, Codable, Sendable { case system, light, dark }

/// Vom Nutzer gewählte Akzentfarbe (Rohwert, vor der Kontrastkorrektur).
public struct ThemeAccent: Hashable, Codable, Sendable {
  public let color: SRGBColor

  public init(color: SRGBColor) { self.color = color }

  /// Liest „#RRGGBB“; ungültig ergibt `nil`.
  public init?(hex: String) {
    guard let color = SRGBColor(hex: hex) else { return nil }
    self.color = color
  }

  public var hex: String { color.hex }
}

/// Erscheinungsbild: Grundton, Akzent (`nil` = Standard-Akzent) und Hell/Dunkel.
public struct Theme: Hashable, Codable, Sendable {
  public var baseTone: BaseTone
  public var accent: ThemeAccent?
  public var appearanceMode: AppearanceMode

  public init(baseTone: BaseTone, accent: ThemeAccent?, appearanceMode: AppearanceMode) {
    self.baseTone = baseTone
    self.accent = accent
    self.appearanceMode = appearanceMode
  }

  /// Warm, Standard-Akzent, wie das System.
  public static let standard = Theme(baseTone: .warm, accent: nil, appearanceMode: .system)

  public var isStandard: Bool { self == .standard }

  /// FR-13: ohne Kauf gilt der Standard; die gespeicherte Wahl bleibt unberührt.
  public func effective(isUnlocked: Bool) -> Theme { isUnlocked ? self : .standard }
}

import Foundation

/// Eine der vier Darstellungsvarianten: hell/dunkel, jeweils mit und ohne „Kontrast erhöhen“.
public struct ThemeVariant: Hashable, Sendable, CaseIterable {
  public var isDark: Bool
  public var isHighContrast: Bool

  public init(isDark: Bool, isHighContrast: Bool) {
    self.isDark = isDark
    self.isHighContrast = isHighContrast
  }

  public static let light = ThemeVariant(isDark: false, isHighContrast: false)
  public static let dark = ThemeVariant(isDark: true, isHighContrast: false)
  public static let lightHighContrast = ThemeVariant(isDark: false, isHighContrast: true)
  public static let darkHighContrast = ThemeVariant(isDark: true, isHighContrast: true)

  public static var allCases: [ThemeVariant] { [light, dark, lightHighContrast, darkHighContrast] }
}

/// Alle Rollenfarben einer Variante, fertig berechnet.
public struct ThemeColors: Hashable, Sendable {
  public var background: SRGBColor
  public var selection: SRGBColor
  public var text: SRGBColor
  public var hairline: SRGBColor
  /// Korrigierter Ton für Text und Symbole in Akzentfarbe.
  public var accent: SRGBColor
  /// Deckende Tönung der Kacheln und Aktionen.
  public var accentTint: SRGBColor
  public var cancellationSymbol: SRGBColor
  public var unavailableSymbol: SRGBColor
  public var nowFill: SRGBColor
  public var nowText: SRGBColor
}

/// Berechnetes Erscheinungsbild; `colors(_:)` liefert die Farben je Variante.
public struct ResolvedTheme: Hashable, Sendable {
  public let usesSystemNeutrals: Bool
  private let table: [ThemeVariant: ThemeColors]
  private let rawAccents: [ThemeVariant: SRGBColor]

  fileprivate init(usesSystemNeutrals: Bool, table: [ThemeVariant: ThemeColors],
                   rawAccents: [ThemeVariant: SRGBColor]) {
    self.usesSystemNeutrals = usesSystemNeutrals
    self.table = table
    self.rawAccents = rawAccents
  }

  public func colors(_ variant: ThemeVariant) -> ThemeColors {
    guard let colors = table[variant] else { preconditionFailure("Variante fehlt") }
    return colors
  }

  /// Wahr, wenn der Akzentton vom gewählten Rohwert abweicht (Hinweis in den Einstellungen).
  public func isAccentAdjusted(_ variant: ThemeVariant) -> Bool {
    colors(variant).accent != rawAccents[variant]
  }
}

public enum ThemeResolver {
  public static let standardAccentLight = SRGBColor(red: 0x0E, green: 0x6B, blue: 0x7A)
  public static let standardAccentDark = SRGBColor(red: 0x5F, green: 0xC2, blue: 0xCF)
  public static let tintPercentLight = 14
  public static let tintPercentDark = 22

  private static let cancellationLight = SRGBColor(red: 0xED, green: 0x37, blue: 0x2D)
  private static let cancellationDark = SRGBColor(red: 0xFF, green: 0x45, blue: 0x3A)
  private static let unavailableLight = SRGBColor(red: 0xB8, green: 0x6B, blue: 0x00)
  private static let unavailableDark = SRGBColor(red: 0xFF, green: 0x9F, blue: 0x0A)
  private static let nowFill = SRGBColor(red: 0xFF, green: 0xC9, blue: 0x4A)
  private static let nowText = SRGBColor(red: 0x1F, green: 0x1A, blue: 0x14)

  public static func resolve(_ theme: Theme) -> ResolvedTheme {
    var table: [ThemeVariant: ThemeColors] = [:]
    var raws: [ThemeVariant: SRGBColor] = [:]
    for variant in ThemeVariant.allCases {
      let dark = variant.isDark, highContrast = variant.isHighContrast
      let n = theme.baseTone.neutrals(isDark: dark)
      let hairline = highContrast ? n.hairline.withAlpha(min(1, 2 * n.hairline.alpha)) : n.hairline
      let percent = dark ? tintPercentDark : tintPercentLight
      let direction: ContrastDirection = dark ? .lighten : .darken

      let standardAccent = dark ? standardAccentDark : standardAccentLight
      let raw = theme.accent?.color ?? standardAccent
      let tint = raw.mixed(over: n.background, percent: percent)
      let accent = ContrastAdjuster.adjusted(
        raw, against: [n.background, n.selection, tint],
        minimum: highContrast ? 7 : 4.5, direction: direction)

      // Entscheidung 1: Signale hängen nur am Grundton, nie am gewählten Akzent.
      let signalSurfaces = [n.background, n.selection,
                            standardAccent.mixed(over: n.background, percent: percent)]
      let signalMinimum = highContrast ? 4.5 : 3.0
      func signal(_ base: SRGBColor) -> SRGBColor {
        ContrastAdjuster.adjusted(base, against: signalSurfaces, minimum: signalMinimum, direction: direction)
      }

      table[variant] = ThemeColors(
        background: n.background, selection: n.selection, text: n.text, hairline: hairline,
        accent: accent, accentTint: tint,
        cancellationSymbol: signal(dark ? cancellationDark : cancellationLight),
        unavailableSymbol: signal(dark ? unavailableDark : unavailableLight),
        nowFill: nowFill, nowText: nowText)
      raws[variant] = raw
    }
    return ResolvedTheme(usesSystemNeutrals: theme.baseTone.usesSystemColors, table: table, rawAccents: raws)
  }
}

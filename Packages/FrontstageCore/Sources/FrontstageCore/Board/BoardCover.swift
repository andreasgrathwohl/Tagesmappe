import Foundation

/// Abdeckung der Tafel (FR-12.7): wird von oben nach unten aufgezogen, damit die Lehrkraft
/// Inhalt schrittweise freigibt.
public struct BoardCover: Hashable, Sendable {
  /// Für wen die Abdeckung gezeichnet wird.
  public enum Audience: Sendable { case tablet, secondScreen }

  /// Deckkraft am Tablet. Platzhalter, Design-Runde offen.
  public static let tabletOpacity = 0.4

  /// 0 = ganz verdeckt, 1 = ganz frei.
  public private(set) var revealedFraction: Double

  public init(revealedFraction: Double = 0) {
    self.revealedFraction = min(max(revealedFraction, 0), 1)
  }

  /// Zieht die Abdeckung bis zum Anteil auf; auf 0…1 begrenzt.
  public mutating func reveal(to fraction: Double) {
    revealedFraction = min(max(fraction, 0), 1)
  }

  /// Am Zweitbildschirm deckend (die Klasse sieht nichts), am Tablet durchscheinend (die Lehrkraft
  /// sieht, was darunter liegt).
  public static func opacity(for audience: Audience) -> Double {
    switch audience {
    case .secondScreen: 1.0
    case .tablet: tabletOpacity
    }
  }
}

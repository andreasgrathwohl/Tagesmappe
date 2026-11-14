import Foundation

/// Inhalt, den der Zweitbildschirm zeigen kann. Nie die Tagesansicht (FR-6.2).
public enum SecondScreenContent: String, Sendable, Hashable, CaseIterable {
  /// Klassenbildschirm (FR-11), Startzustand.
  case classScreen
  /// Das geöffnete Material (PDF oder Bild).
  case material
  /// Die Tafel (Teilplan 07).
  case board
  /// Dunkel (FR-11.4): der Bildschirm bleibt verbunden, zeigt aber nichts.
  case dark
}

/// Reiner Zustand des Zweitbildschirms: welcher Inhalt gezeigt wird und welche
/// Inhalte gerade wählbar sind (FR-11.4, FR-11.5, FR-6.2).
///
/// Der Zustand ist flüchtig und hält weder Dateien noch Daten. „Dunkel“ merkt sich
/// den davor sichtbaren Inhalt, damit der Rückweg dasselbe zeigt (AK-28).
public struct SecondScreenSelection: Sendable, Hashable {
  /// Aktuell gezeigter Inhalt.
  public private(set) var mode: SecondScreenContent = .classScreen
  /// Inhalt, zu dem „Dunkel“ zurückführt. Nie `.dark`; solange nicht dunkel, gleich `mode`.
  private var modeBeforeDark: SecondScreenContent = .classScreen
  private var materialAvailable = false
  private var boardAvailable = false

  public init() {}

  /// Ein Material ist geöffnet und damit wählbar.
  public var isMaterialOpen: Bool { materialAvailable }
  /// Die Tafel ist verfügbar und damit wählbar.
  public var isBoardAvailable: Bool { boardAvailable }

  /// Wählbare Inhalte in fester Reihenfolge: Klassenbildschirm, Material, Tafel, Dunkel.
  public var availableModes: [SecondScreenContent] {
    var modes: [SecondScreenContent] = [.classScreen]
    if materialAvailable { modes.append(.material) }
    if boardAvailable { modes.append(.board) }
    modes.append(.dark)
    return modes
  }

  /// Ein Material wurde geöffnet: es erscheint, außer der Bildschirm ist dunkel –
  /// dann zeigt der Rückweg aus „Dunkel“ das Material.
  public mutating func materialOpened() {
    materialAvailable = true
    if mode == .dark { modeBeforeDark = .material } else { mode = .material }
  }

  /// Das Material wurde geschlossen: zurück zum Klassenbildschirm, nie zur Tagesansicht (AK-23).
  /// Ist der Bildschirm dunkel, bleibt er es; nur der Rückweg ändert sich.
  public mutating func materialClosed() {
    materialAvailable = false
    fallBack(from: .material)
  }

  /// Die Tafel ist verfügbar oder nicht mehr; fällt sie weg, zeigt der Bildschirm den Klassenbildschirm.
  public mutating func setBoardAvailable(_ available: Bool) {
    boardAvailable = available
    if !available { fallBack(from: .board) }
  }

  /// „Dunkel“ ein- oder ausschalten (FR-11.4); aus führt zum zuvor sichtbaren Inhalt.
  public mutating func toggleDark() {
    if mode == .dark {
      mode = modeBeforeDark
    } else {
      modeBeforeDark = mode
      mode = .dark
    }
  }

  /// Wählt einen Inhalt. `false` und unveränderter Zustand, wenn er nicht verfügbar ist.
  /// `.dark` verhält sich wie ein Einschalten; ein heller Inhalt hebt „Dunkel“ auf.
  @discardableResult
  public mutating func select(_ content: SecondScreenContent) -> Bool {
    guard availableModes.contains(content) else { return false }
    if content == .dark {
      if mode != .dark { toggleDark() }
    } else {
      mode = content
      modeBeforeDark = content
    }
    return true
  }

  /// Ein Bildschirm wurde verbunden: „Dunkel“ wird aufgehoben, damit der Inhalt
  /// ohne Handgriff erscheint (AK-35). Ein sichtbarer Inhalt bleibt.
  public mutating func displayConnected() {
    if mode == .dark { mode = modeBeforeDark }
  }

  /// Ersetzt einen weggefallenen Inhalt in `mode` und `modeBeforeDark` durch den Klassenbildschirm.
  private mutating func fallBack(from lost: SecondScreenContent) {
    if mode == lost { mode = .classScreen }
    if modeBeforeDark == lost { modeBeforeDark = .classScreen }
  }
}

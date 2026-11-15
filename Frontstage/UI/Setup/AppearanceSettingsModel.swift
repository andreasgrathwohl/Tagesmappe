import Foundation
import FrontstageCore
import Observation

/// Lese- und Schreibzugang zum gespeicherten Erscheinungsbild; `DataStore` erfüllt ihn, Tests dürfen
/// ihn ersetzen.
@MainActor protocol ThemeStore: AnyObject {
  var revision: Int { get }
  func theme() throws -> Theme
  func setTheme(_ theme: Theme) throws
}

extension DataStore: ThemeStore {}

/// Logik von „Einrichten › Erscheinungsbild“ (FR-16, FR-16.1, AK-52 bis AK-54).
///
/// Das Öffnen schreibt nie: Ohne Datensatz gilt `.standard`, geschrieben wird erst bei einer Wahl.
/// Der Akzent wird beim Ziehen im Farbwähler nur als Vorschau gehalten (`previewAccent`) und mit
/// `commitAccent()` gespeichert.
///
/// Swift-Hinweis: `@Observable` ersetzt `ObservableObject`; die Ansicht zeichnet nur neu, was sie gelesen hat.
@MainActor @Observable final class AppearanceSettingsModel {
  private let store: any ThemeStore

  /// Gespeicherte Wahl, beim Akzent ergänzt um die laufende Vorschau.
  private(set) var theme: Theme = .standard
  /// Das letzte Speichern ist gescheitert; die bisherige Einstellung gilt weiter.
  private(set) var saveFailed = false

  init(store: any ThemeStore) {
    self.store = store
    reload()
  }

  var resolved: ResolvedTheme { ThemeResolver.resolve(theme) }

  var isStandard: Bool { theme.isStandard }

  /// Liest den gespeicherten Stand neu (auch nach Änderungen vom anderen Gerät); verwirft eine Vorschau.
  func reload() {
    theme = (try? store.theme()) ?? .standard
  }

  func setBaseTone(_ tone: BaseTone) {
    var next = theme
    next.baseTone = tone
    save(next)
  }

  func setAppearanceMode(_ mode: AppearanceMode) {
    var next = theme
    next.appearanceMode = mode
    save(next)
  }

  /// Nur Vorschau: der Farbwähler meldet laufend Werte, gespeichert wird erst mit `commitAccent()`.
  func previewAccent(_ color: SRGBColor) {
    let accent = ThemeAccent(color: color)
    if theme.accent != accent { theme.accent = accent }
  }

  /// Speichert, wenn die Wahl vom Gespeicherten abweicht.
  func commitAccent() {
    guard let stored = try? store.theme(), stored != theme else { return }
    save(theme)
  }

  func useStandardAccent() {
    var next = theme
    next.accent = nil
    save(next)
  }

  func resetToStandard() {
    save(.standard)
  }

  /// Bei einem Fehler bleibt der gespeicherte Stand sichtbar, damit die Anzeige nicht lügt.
  private func save(_ next: Theme) {
    do {
      try store.setTheme(next)
      theme = next
      saveFailed = false
    } catch {
      saveFailed = true
      reload()
    }
  }
}

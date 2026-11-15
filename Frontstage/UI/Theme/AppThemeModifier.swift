import FrontstageCore
import SwiftUI

extension AppearanceMode {
  /// `system` → `nil`: das Gerät entscheidet.
  var colorScheme: ColorScheme? {
    switch self {
    case .system: nil
    case .light: .light
    case .dark: .dark
    }
  }
}

/// Wendet das wirksame Erscheinungsbild an (FR-16, FR-13): Farben über die Umgebung, Akzent über `.tint`,
/// Hell/Dunkel über `.preferredColorScheme`. Glas-Leisten werden nicht eingefärbt (UI-8).
///
/// Swift-Hinweis: Das Lesen von `store.revision` im `body` macht die Ansicht beobachtend (`@Observable`);
/// ein Abgleich, der das Erscheinungsbild ändert, zeichnet sie damit neu.
private struct AppThemeModifier: ViewModifier {
  let store: DataStore
  let unlock: Unlock

  /// Zwischenspeicher für den Akzent: Eine dynamische `Color` ist an einen UIColor/NSColor gebunden und wird
  /// nur neu gebaut, wenn sich das aufgelöste Erscheinungsbild ändert, nicht bei jeder `store.revision`.
  @State private var cachedTint: (resolved: ResolvedTheme, color: Color)?

  func body(content: Content) -> some View {
    _ = store.revision
    let effective = ((try? store.theme()) ?? .standard).effective(isUnlocked: unlock.isUnlocked)
    let resolved = ThemeResolver.resolve(effective)
    let style = ThemeStyle(resolved)
    let tint: Color
    if let cachedTint, cachedTint.resolved == resolved {
      tint = cachedTint.color
    } else {
      tint = style.accent
    }
    return
      content
      .environment(\.themeStyle, style)
      .tint(tint)
      .onChange(of: resolved, initial: true) { _, newValue in
        cachedTint = (newValue, ThemeStyle(newValue).accent)
      }
      .preferredColorScheme(effective.appearanceMode.colorScheme)
  }
}

extension View {
  func appTheme(store: DataStore, unlock: Unlock) -> some View {
    modifier(AppThemeModifier(store: store, unlock: unlock))
  }
}

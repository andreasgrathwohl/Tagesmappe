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

  func body(content: Content) -> some View {
    _ = store.revision
    let effective = ((try? store.theme()) ?? .standard).effective(isUnlocked: unlock.isUnlocked)
    let style = ThemeStyle(ThemeResolver.resolve(effective))
    return
      content
      .environment(\.themeStyle, style)
      .tint(style.accent)
      .preferredColorScheme(effective.appearanceMode.colorScheme)
  }
}

extension View {
  func appTheme(store: DataStore, unlock: Unlock) -> some View {
    modifier(AppThemeModifier(store: store, unlock: unlock))
  }
}

import SwiftUI

/// Färbt den Grund eines `List`/`Form` im gewählten Grundton (UI-8).
///
/// Swift-Hinweis: `.scrollContentBackground(.hidden)` blendet den Systemgrund von `List`/`Form` aus,
/// erst dann sieht man das `.background` dahinter. Beim Grundton „System“ bleibt alles unverändert,
/// damit gruppierte Listen ihre Systemfarben behalten (HIG color, dark mode). Zeilenhintergründe
/// bleiben Systemzellen.
private struct ThemedBackgroundModifier: ViewModifier {
  @Environment(\.themeStyle) private var style

  @ViewBuilder
  func body(content: Content) -> some View {
    if style.usesSystemNeutrals {
      content
    } else {
      content
        .scrollContentBackground(.hidden)
        .background(style.background)
    }
  }
}

extension View {
  /// Ohne Systemneutrale: `.scrollContentBackground(.hidden)` und `.background(themeStyle.background)`; mit: unverändert.
  func themedBackground() -> some View {
    modifier(ThemedBackgroundModifier())
  }
}

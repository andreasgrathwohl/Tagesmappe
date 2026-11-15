import FrontstageCore
import SwiftUI

#if canImport(UIKit)
  import UIKit
#elseif canImport(AppKit)
  import AppKit
#endif

/// Alle Rollenfarben des wirksamen Erscheinungsbilds als SwiftUI-Farben (UI-8, UI-9).
///
/// Swift-Hinweis: Jede Farbe hier ist **eine** dynamische `Color`: das System ruft die Closure bei jedem
/// Wechsel von hell/dunkel und „Kontrast erhöhen“ neu auf. Deshalb greift `.preferredColorScheme` ohne
/// weiteren Code, auch in Sheets. Die Closures sind `@Sendable` und fangen nur `ResolvedTheme` (Sendable) ein.
struct ThemeStyle: Equatable {
  let resolved: ResolvedTheme

  init(_ resolved: ResolvedTheme) { self.resolved = resolved }

  /// Grundton „System“: neutrale Flächen kommen von den Systemfarben statt aus der Tabelle (UI-8).
  var usesSystemNeutrals: Bool { resolved.usesSystemNeutrals }

  var background: Color { neutral(.background) { $0.background } }
  var selection: Color { neutral(.selection) { $0.selection } }
  var text: Color { neutral(.text) { $0.text } }
  var hairline: Color { neutral(.hairline) { $0.hairline } }

  var accent: Color { dynamic { $0.accent } }
  var accentTint: Color { dynamic { $0.accentTint } }
  var cancellationSymbol: Color { dynamic { $0.cancellationSymbol } }
  var unavailableSymbol: Color { dynamic { $0.unavailableSymbol } }
  var nowFill: Color { dynamic { $0.nowFill } }
  var nowText: Color { dynamic { $0.nowText } }

  // MARK: - Bausteine

  private enum NeutralRole { case background, selection, text, hairline }

  private func neutral(
    _ role: NeutralRole, _ pick: @escaping @Sendable (ThemeColors) -> SRGBColor
  ) -> Color {
    guard usesSystemNeutrals else { return dynamic(pick) }
    #if canImport(UIKit)
      switch role {
      case .background: return Color(uiColor: .systemBackground)
      case .selection: return Color(uiColor: .systemGray5)
      case .text: return Color(uiColor: .label)
      case .hairline: return Color(uiColor: .separator)
      }
    #else
      switch role {
      case .background: return Color(nsColor: .windowBackgroundColor)
      case .selection: return Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
      case .text: return Color(nsColor: .labelColor)
      case .hairline: return Color(nsColor: .separatorColor)
      }
    #endif
  }

  private func dynamic(_ pick: @escaping @Sendable (ThemeColors) -> SRGBColor) -> Color {
    let resolved = self.resolved
    #if canImport(UIKit)
      return Color(
        uiColor: UIColor { traits in
          let variant = ThemeVariant(
            isDark: traits.userInterfaceStyle == .dark,
            isHighContrast: traits.accessibilityContrast == .high)
          let c = pick(resolved.colors(variant))
          return UIColor(
            red: CGFloat(c.red) / 255, green: CGFloat(c.green) / 255, blue: CGFloat(c.blue) / 255,
            alpha: CGFloat(c.alpha))
        })
    #else
      return Color(
        nsColor: NSColor(name: nil) { appearance in
          let match = appearance.bestMatch(from: [
            .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
          ])
          let variant = ThemeVariant(
            isDark: match == .darkAqua || match == .accessibilityHighContrastDarkAqua,
            isHighContrast: match == .accessibilityHighContrastAqua
              || match == .accessibilityHighContrastDarkAqua)
          let c = pick(resolved.colors(variant))
          return NSColor(
            srgbRed: CGFloat(c.red) / 255, green: CGFloat(c.green) / 255, blue: CGFloat(c.blue) / 255,
            alpha: CGFloat(c.alpha))
        })
    #endif
  }
}

extension EnvironmentValues {
  /// Swift-Hinweis: `@Entry` (iOS 18/macOS 15) ersetzt den früheren `EnvironmentKey`-Boilerplate.
  @Entry var themeStyle = ThemeStyle(ThemeResolver.resolve(.standard))
}

import SwiftUI

/// Kachel (UI-9, UI-10): deckend getönte, kontinuierlich gerundete Fläche; kein Rahmen, kein Schatten (UI-5).
struct TileButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    TileBody(configuration: configuration)
  }

  /// Swift-Hinweis: `@Environment` funktioniert in einer `View`, nicht direkt im Style – daher der Umweg.
  private struct TileBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.themeStyle) private var style

    var body: some View {
      configuration.label
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous).fill(style.accentTint)
        )
        .opacity(configuration.isPressed ? 0.7 : 1)
    }
  }
}

/// Kapsel-Aktion (UI-9, UI-14): getönte Kapsel, Beschriftung in Akzent, mindestens 44 pt hoch.
struct CapsuleActionButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    CapsuleBody(configuration: configuration)
  }

  private struct CapsuleBody: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.themeStyle) private var style

    var body: some View {
      configuration.label
        .scaledFont(.action)
        .foregroundStyle(style.accent)
        .padding(.horizontal, 16)
        .frame(minHeight: 44)
        .background(Capsule().fill(style.accentTint))
        .opacity(configuration.isPressed ? 0.7 : 1)
    }
  }
}

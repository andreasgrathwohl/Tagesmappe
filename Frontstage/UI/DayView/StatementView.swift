import SwiftUI

/// Eine Aussage an einer Stunde oder einem Material (UI-11): Symbol in Signalfarbe (Ausfall, nicht verfügbar)
/// oder Textfarbe, das Wort immer in Textfarbe. Symbol und Wort sind getrennte Elemente, kein gemeinsames
/// `Label` mit einer Farbe; nie Fettdruck (UI-6).
struct StatementView: View {
  let statement: LessonStatement
  let scale: TypeScale

  @Environment(\.themeStyle) private var style

  init(_ statement: LessonStatement, scale: TypeScale) {
    self.statement = statement
    self.scale = scale
  }

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: statement.symbolName)
        .foregroundStyle(symbolColor)
        // Das Wort trägt die Bedeutung; das Symbol bleibt für VoiceOver stumm.
        .accessibilityHidden(true)
      Text(LocalizedStringKey(statement.labelKey))
        .foregroundStyle(style.text)
    }
    .scaledFont(scale)
    .accessibilityElement(children: .combine)
  }

  private var symbolColor: Color {
    switch statement.signal {
    case .cancellation: style.cancellationSymbol
    case .unavailable: style.unavailableSymbol
    case nil: style.text
    }
  }
}

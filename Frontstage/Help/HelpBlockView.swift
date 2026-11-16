import FrontstageCore
import SwiftUI

/// Ein Baustein eines Hilfetexts (UI-6: Hierarchie nur über die Größe, nie über Fettdruck).
struct HelpBlockView: View {
  let block: HelpBlock
  @Environment(\.themeStyle) private var style

  var body: some View {
    switch block {
    case .heading(let text):
      Text(Self.inline(text))
        .scaledFont(.topic)
        .accessibilityAddTraits(.isHeader)
    case .paragraph(let text):
      Text(Self.inline(text))
    case .bullets(let items):
      VStack(alignment: .leading, spacing: 6) {
        ForEach(items.indices, id: \.self) { index in
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "•").accessibilityHidden(true)
            Text(Self.inline(items[index]))
          }
        }
      }
    case .steps(let items):
      VStack(alignment: .leading, spacing: 6) {
        ForEach(items.indices, id: \.self) { index in
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "\(index + 1).").monospacedDigit()
            Text(Self.inline(items[index]))
          }
        }
      }
    case .note(let text):
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Image(systemName: "info.circle").accessibilityHidden(true)
        Text(Self.inline(text))
      }
      .foregroundStyle(style.text)
    }
  }

  /// Inline-Markdown (`**fett**`, `` `Code` `` …); schlägt das Parsen fehl, gilt der Rohtext.
  static func inline(_ text: String) -> AttributedString {
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace)
    return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
  }
}

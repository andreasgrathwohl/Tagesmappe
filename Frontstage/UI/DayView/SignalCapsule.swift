import SwiftUI

/// Gelbe Kapsel „Jetzt“ / „Am Smartboard“ (UI-12): Fläche `#FFC94A`, Wort `#1F1A14` in beiden Modi
/// (etwa 11:1), Gelb nie als große Fläche. Kapselwechsel überblendet kurz (UI-14), kein Pulsieren.
struct SignalCapsule: View {
  enum Kind {
    /// Die Stunde läuft jetzt.
    case now
    /// Das Material steht auf dem Zweitbildschirm.
    case onSmartboard

    fileprivate var labelKey: LocalizedStringKey {
      switch self {
      case .now: "dayView.now"
      case .onSmartboard: "dayView.onSmartboard"
      }
    }

    fileprivate var accessibilityKey: LocalizedStringKey {
      switch self {
      case .now: "dayView.now.accessibility"
      case .onSmartboard: "dayView.onSmartboard.accessibility"
      }
    }
  }

  /// Feste Farben, unabhängig von Modus und Akzent (UI-12).
  static let fill = Color(.sRGB, red: 255.0 / 255, green: 201.0 / 255, blue: 74.0 / 255, opacity: 1)
  static let word = Color(.sRGB, red: 31.0 / 255, green: 26.0 / 255, blue: 20.0 / 255, opacity: 1)

  let kind: Kind

  init(_ kind: Kind) { self.kind = kind }

  var body: some View {
    Text(kind.labelKey)
      .scaledFont(.listMeta)
      .foregroundStyle(Self.word)
      .padding(.horizontal, 8)
      .padding(.vertical, 2)
      .background(Capsule().fill(Self.fill))
      .accessibilityLabel(Text(kind.accessibilityKey))
  }
}

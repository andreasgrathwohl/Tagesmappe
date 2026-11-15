import SwiftUI

/// Schriftskala (UI-6): Größe in Punkt und der Systemstil, an dem Dynamic Type die Größe skaliert.
enum TypeScale {
  case detailTitle
  case materialName
  case topic
  case listTitle
  case action
  case detailMeta
  case listMeta
  case fileType

  var size: CGFloat {
    switch self {
    case .detailTitle: 34
    case .materialName, .topic: 20
    case .listTitle: 18
    case .action: 15
    case .detailMeta: 13
    case .listMeta, .fileType: 11
    }
  }

  var textStyle: Font.TextStyle {
    switch self {
    case .detailTitle: .largeTitle
    case .materialName, .topic: .title3
    case .listTitle: .body
    case .action: .subheadline
    case .detailMeta: .footnote
    case .listMeta, .fileType: .caption2
    }
  }
}

/// Setzt die Schrift in der Skalagröße, skaliert mit Dynamic Type. Das Schriftdesign bleibt offen und kommt
/// aus dem Kontext (UI-7: `.fontDesign(.rounded)` an der Wurzel). Kein Fettdruck (UI-6).
///
/// Swift-Hinweis: `@ScaledMetric(relativeTo:)` skaliert einen Zahlenwert wie den genannten Textstil; der
/// Stil steht erst im `init` fest, daher wird der Wrapper dort mit `_size = ScaledMetric(...)` gesetzt.
/// `.system(size:)` ohne `design:` lässt das Design offen, sodass `.fontDesign(...)` aus dem Kontext greift.
private struct ScaledFontModifier: ViewModifier {
  @ScaledMetric private var size: CGFloat

  init(scale: TypeScale) {
    _size = ScaledMetric(wrappedValue: scale.size, relativeTo: scale.textStyle)
  }

  func body(content: Content) -> some View {
    content.font(.system(size: size))
  }
}

extension View {
  func scaledFont(_ scale: TypeScale) -> some View { modifier(ScaledFontModifier(scale: scale)) }
}

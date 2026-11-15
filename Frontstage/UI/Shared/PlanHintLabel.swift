import FrontstageCore
import SwiftUI

/// Leistungsnachweise aus dem Jahresplan unter einer Stunde (FR-15.6): „Klassenarbeit: KA 1“ am Tag
/// der Stunde, „diese Woche: Test Vokabeltest Unit 2“ ohne festen Tag. Symbol **und** Text, nie nur
/// Farbe; Systemstandard ohne eigene Gestaltung (offene Kategorie, DESIGN.md).
struct PlanHintLabel: View {
  let markers: [AssessmentMarker]

  var body: some View {
    ForEach(Array(markers.enumerated()), id: \.offset) { _, marker in
      Label {
        text(for: marker)
      } icon: {
        Image(systemName: "checkmark.rectangle.stack")
      }
      .scaledFont(.detailMeta)
      .lineLimit(1)
    }
  }

  private func text(for marker: AssessmentMarker) -> Text {
    let kind = Self.kindName(marker.assessment.kind)
    let title = marker.assessment.title
    switch marker.timing {
    case .onDay: return Text("planHint.onDay \(kind) \(title)")
    case .thisWeek: return Text("planHint.thisWeek \(kind) \(title)")
    }
  }

  /// Gesprochener Name der Art („Klassenarbeit“, „Test“).
  static func kindName(_ kind: AssessmentKind) -> String {
    switch kind {
    case .test: String(localized: "assessment.kind.test")
    case .classTest: String(localized: "assessment.kind.classTest")
    }
  }
}

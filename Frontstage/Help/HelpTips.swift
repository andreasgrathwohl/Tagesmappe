import SwiftUI
import TipKit

/// Gemeinsamer Schalter aller Kurz-Tipps (Entscheidung 13). Jeder Tip hängt mit einer Regel daran;
/// steht er auf `false`, zeigt keiner mehr einen Hinweis.
///
/// Swift-Hinweis: `@Parameter` ist ein TipKit-Makro. Es macht aus der statischen Variable einen Wert, den
/// TipKit beobachtet und speichert; `HelpTips.$isEnabled` liefert den Parameter für `#Rule`.
struct HelpTips {
  @Parameter static var isEnabled: Bool = true
}

/// Hinweis auf die vorgewählte laufende Stunde (Tagesansicht).
struct DaySelectionTip: Tip {
  var title: Text { Text("tips.daySelection.title") }
  var message: Text? { Text("tips.daySelection.message") }
  var image: Image? { Image(systemName: "list.bullet.rectangle") }
  var rules: [Rule] { [#Rule(HelpTips.$isEnabled) { $0 == true }] }
}

/// Hinweis auf das Gedrückthalten einer Material-Kachel.
struct MaterialTileTip: Tip {
  var title: Text { Text("tips.materialTile.title") }
  var message: Text? { Text("tips.materialTile.message") }
  var image: Image? { Image(systemName: "hand.tap") }
  var rules: [Rule] { [#Rule(HelpTips.$isEnabled) { $0 == true }] }
}

/// Hinweis auf die Smartboard-Leiste (nur iPad).
struct SmartboardBarTip: Tip {
  var title: Text { Text("tips.smartboardBar.title") }
  var message: Text? { Text("tips.smartboardBar.message") }
  var image: Image? { Image(systemName: "tv") }
  var rules: [Rule] { [#Rule(HelpTips.$isEnabled) { $0 == true }] }
}

/// Hinweis auf den Hilfeknopf.
struct HelpButtonTip: Tip {
  var title: Text { Text("tips.helpButton.title") }
  var message: Text? { Text("tips.helpButton.message") }
  var image: Image? { Image(systemName: "questionmark.circle") }
  var rules: [Rule] { [#Rule(HelpTips.$isEnabled) { $0 == true }] }
}

import FrontstageCore
import Foundation

/// Was ein Tipp auf eine Material-Zeile auslöst. Die Naht zu Teilplan 06: `.viewer` zeigt die Datei
/// im eigenen Betrachter, solange `AppEnvironment.viewerAvailable` gesetzt ist.
enum MaterialOpenAction: Equatable {
  case viewer(MaterialLinkItem)
  case open(MaterialReference)
  case unavailable(MaterialReference)
}

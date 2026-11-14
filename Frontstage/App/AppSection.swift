import SwiftUI

/// Die vier Bereiche der App (Tab- bzw. Seitenleiste).
enum AppSection: String, CaseIterable, Hashable {
  case dayView
  case preparation
  case coursePlan
  case setup

  /// Startbereich: ohne Stundenplan gibt es nichts anzuzeigen – dann Einrichten; sonst am iPad die
  /// Tagesansicht (Unterricht), am Mac das Vorbereiten (Schreibtisch).
  static func initial(isMac: Bool, hasTimetable: Bool) -> AppSection {
    guard hasTimetable else { return .setup }
    return isMac ? .preparation : .dayView
  }

  /// Schlüssel in `Localizable.xcstrings`.
  var titleKey: LocalizedStringKey {
    switch self {
    case .dayView: "app.section.dayView"
    case .preparation: "app.section.preparation"
    case .coursePlan: "app.section.coursePlan"
    case .setup: "app.section.setup"
    }
  }

  /// SF-Symbol als Systemstandard; die Wahl der Symbole ist eine offene Gestaltungskategorie.
  var systemImage: String {
    switch self {
    case .dayView: "calendar.day.timeline.left"
    case .preparation: "tray.full"
    case .coursePlan: "calendar"
    case .setup: "gearshape"
    }
  }
}

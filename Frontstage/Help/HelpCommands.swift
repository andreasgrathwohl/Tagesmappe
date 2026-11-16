import SwiftUI

/// Menü „Hilfe“ der Menüleiste (macOS) und Tastaturkürzel auf dem iPad mit Tastatur.
///
/// Swift-Hinweis: `CommandGroup(replacing: .help)` ersetzt den vom System angelegten Hilfe-Eintrag
/// (der sonst ein nicht vorhandenes Hilfebuch sucht).
struct HelpCommands: Commands {
  let support: SupportCoordinator

  var body: some Commands {
    CommandGroup(replacing: .help) {
      Button("help.menu.helpCenter") { support.showHelpCenter() }
        .keyboardShortcut("?", modifiers: .command)
      Button("help.menu.feedback") { support.startFeedback() }
    }
  }
}

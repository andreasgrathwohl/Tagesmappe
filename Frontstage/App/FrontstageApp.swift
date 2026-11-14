import SwiftData
import SwiftUI

// Platzhalter – Teilplan 04 ersetzt den Inhalt durch RootView und übernimmt die Verdrahtung in AppEnvironment.
// Container, DataStore und Zusammenführen gehören seit Teilplan 08 dem `DataLocationController` (Datenort
// zur Laufzeit wählbar); alles, was einen `DataStore` braucht, entsteht in der Closure von `DataScopedRoot`.
@main
struct FrontstageApp: App {
  // Swift-Hinweis: `@State` hält die Objekte über Neuberechnungen des `body` hinweg am Leben; der
  // Anfangswert wird in `init` gesetzt, damit die Objekte einander kennen können.
  @State private var account: MicrosoftAccount
  @State private var network: NetworkMonitor
  @State private var dataLocation: DataLocationController
  // Swift-Hinweis: `@Environment(\.scenePhase)` liefert den Lebenszyklus der Szene (aktiv, inaktiv, Hintergrund).
  @Environment(\.scenePhase) private var scenePhase

  /// `App.init` läuft auf dem Hauptakteur (`App` ist `@MainActor`), daher darf hier `mainContext` gelesen werden.
  init() {
    // Die Anmeldung hängt nicht am Datenort und entsteht deshalb einmal, vor dem Controller.
    let account = MicrosoftAccount()
    let network = NetworkMonitor()
    let controller = DataLocationController(
      account: account,
      makeRemote: { OneDriveDataClient(tokens: DataLocationTokenProvider(account: account)) })

    // `onBecameOnline` ist eine einzelne Closure: einen schon gesetzten Wert verketten, nicht überschreiben.
    let previous = network.onBecameOnline
    network.onBecameOnline = { [weak controller] in
      previous?()
      MainActor.assumeIsolated { controller?.networkDidBecomeAvailable() }
    }

    _account = State(initialValue: account)
    _network = State(initialValue: network)
    _dataLocation = State(initialValue: controller)
    network.start()
    controller.start()
  }

  var body: some Scene {
    WindowGroup {
      DataScopedRoot(controller: dataLocation) { store, container in
        // Ein Zeichenketten-Literal ist hier ein LocalizedStringKey und wird in Localizable.xcstrings nachgeschlagen.
        Text("app.placeholder.title")
          .environment(store)
          .modelContainer(container)
      }
      // Ohne die Rückkehr-Adresse kehrt die MSAL-Anmeldung am iPad nicht in die App zurück.
      .onOpenURL { _ = MicrosoftAccount.handleRedirect($0) }
    }
    .onChange(of: scenePhase) { _, newPhase in
      switch newPhase {
      case .active: dataLocation.sceneDidBecomeActive()
      case .background: dataLocation.sceneDidEnterBackground()
      default: break
      }
    }
  }
}

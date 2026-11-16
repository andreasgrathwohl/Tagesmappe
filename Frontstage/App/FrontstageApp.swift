import OSLog
import SwiftData
import SwiftUI

// Container, DataStore und Zusammenführen gehören seit Teilplan 08 dem `DataLocationController` (Datenort
// zur Laufzeit wählbar); alles, was einen `DataStore` braucht, entsteht in `ScopedAppContent` (Teilplan 04).
@main
struct FrontstageApp: App {
  // Swift-Hinweis: `@State` hält die Objekte über Neuberechnungen des `body` hinweg am Leben; der
  // Anfangswert wird in `init` gesetzt, damit die Objekte einander kennen können.
  @State private var account: MicrosoftAccount
  @State private var network: NetworkMonitor
  /// `nil`, wenn der Datenspeicher beim Start nicht geöffnet werden konnte (Fehleransicht statt Absturz).
  @State private var dataLocation: DataLocationController?
  // Der Halter legt den Koordinator der Stundenplan-Quelle je `DataStore` an (Teilplan 05, Aufgabe 10).
  // Kein Koordinator als `@State` hier: er hielte sonst einen veralteten `DataStore` nach einem Datenort-Wechsel.
  @State private var sourceCoordinators = SourceCoordinatorHolder()
  // Swift-Hinweis: `@Environment(\.scenePhase)` liefert den Lebenszyklus der Szene (aktiv, inaktiv, Hintergrund).
  @Environment(\.scenePhase) private var scenePhase
  #if os(iOS)
    // Swift-Hinweis: verbindet einen UIKit-App-Delegate mit dem SwiftUI-Lebenszyklus (Szene des Zweitbildschirms).
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  #endif

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "App")

  /// `App.init` läuft auf dem Hauptakteur (`App` ist `@MainActor`), daher darf hier `mainContext` gelesen werden.
  init() {
    // Als Erstes: TipKit muss vor der ersten Tip-Ansicht konfiguriert sein (Zurücksetzen davor).
    HelpTipsConfiguration.configureAtLaunch()
    // Die Anmeldung hängt nicht am Datenort und entsteht deshalb einmal, vor dem Controller.
    let account = MicrosoftAccount()
    let network = NetworkMonitor()
    _account = State(initialValue: account)
    _network = State(initialValue: network)

    // Der Container des gespeicherten Datenorts wird vorab geöffnet: scheitert das, zeigt die App eine
    // Fehleransicht. Der Controller (Teilplan 08) bekommt genau diesen Container und behält sein `fatalError`
    // als Rückfall, das dadurch im Normalfall nie erreicht wird.
    let settings = DataLocationSettings()
    let initialLocation = settings.location
    let opened: ModelContainer
    do {
      opened = try ModelContainerFactory.makeContainer(for: initialLocation)
    } catch {
      // Für die Fehlersuche am Gerät (Konsole bzw. `log collect`); die Oberfläche zeigt nur die Fehleransicht.
      Self.logger.fault(
        "Datenspeicher beim Start nicht geöffnet (\(String(describing: initialLocation), privacy: .public)): \(String(describing: error), privacy: .public)"
      )
      _dataLocation = State(initialValue: nil)
      return
    }
    let preopened = PreopenedContainer(opened)
    let controller = DataLocationController(
      settings: settings, account: account,
      makeContainer: { location in
        if location == initialLocation, let container = preopened.take() { return container }
        return try ModelContainerFactory.makeContainer(for: location)
      },
      makeRemote: { OneDriveDataClient(tokens: DataLocationTokenProvider(account: account)) })

    // `onBecameOnline` ist eine einzelne Closure: einen schon gesetzten Wert verketten, nicht überschreiben.
    let previous = network.onBecameOnline
    network.onBecameOnline = { [weak controller] in
      previous?()
      MainActor.assumeIsolated { controller?.networkDidBecomeAvailable() }
    }

    _dataLocation = State(initialValue: controller)
    network.start()
    controller.start()
  }

  var body: some Scene {
    WindowGroup {
      if let dataLocation {
        RootView(
          dataLocation: dataLocation, account: account, network: network,
          sourceCoordinators: sourceCoordinators
        )
        // Außen, nicht in `ScopedAppContent`: Zubehör und Umgebung überstehen einen Wechsel des Datenorts.
        .secondScreenEnvironment()
        #if os(iOS)
          .registersSecondScreenAccessory()
        #endif
        // Ohne die Rückkehr-Adresse kehrt die MSAL-Anmeldung am iPad nicht in die App zurück.
        .onOpenURL { _ = MicrosoftAccount.handleRedirect($0) }
      } else {
        // Wortlaut ist ein Platzhalter (Gestaltungskategorie „Wortlaut“ offen).
        ContentUnavailableView("app.dataUnavailable", systemImage: "exclamationmark.triangle")
      }
    }
    .onChange(of: scenePhase) { _, newPhase in
      switch newPhase {
      case .active: dataLocation?.sceneDidBecomeActive()
      case .background: dataLocation?.sceneDidEnterBackground()
      default: break
      }
    }
    // Menü „Hilfe“ (Mac) und Tastaturkürzel ⌘? (iPad mit Tastatur).
    .commands { HelpCommands(support: .shared) }
    #if os(iOS)
      // Swift-Hinweis: SwiftUI ruft den Block auf, wenn das System die Aufgabe startet; die nächste Aufgabe muss
      // man selbst wieder anmelden. Die Closure läuft nicht auf dem Haupt-Actor – der Zugriff auf Halter und
      // Controller steckt deshalb in einer `@MainActor`-Methode.
      .backgroundTask(.appRefresh(MorningRefresh.taskIdentifier)) {
        await runMorningRefresh()
      }
    #endif
  }

  #if os(iOS)
    /// Hintergrund-Aktualisierung: Koordinator des aktuellen Datenorts abfragen, danach die nächste anmelden.
    @MainActor private func runMorningRefresh() async {
      if let dataLocation {
        let coordinator = sourceCoordinators.coordinator(for: dataLocation.store)
        await coordinator.refresh(.backgroundRefresh)
      }
      MorningRefresh.schedule()
    }
  #endif
}

/// Gibt den vorab geöffneten Container genau einmal her; spätere Wechsel öffnen frisch.
@MainActor final class PreopenedContainer {
  private var container: ModelContainer?
  init(_ container: ModelContainer) { self.container = container }
  func take() -> ModelContainer? {
    defer { container = nil }
    return container
  }
}

import FrontstageCore
import SwiftUI

/// Wurzel der Oberfläche: Tab- bzw. Seitenleiste mit den drei Bereichen.
///
/// Die Leiste selbst steht **außerhalb** von `DataScopedRoot`: Nur der datenabhängige Inhalt eines Bereichs
/// hängt über `ScopedAppContent` am Datenort und wird beim Wechsel neu aufgebaut. Einrichten › Datenort und
/// die Kopplung (QR-Sheet) liegen deshalb im äußeren Teil – ein Wechsel des Datenorts mitten im Koppeln
/// reißt das Sheet nicht ab (Entscheidung Bündel A, Teilplan 08).
struct RootView: View {
  private let dataLocation: DataLocationController
  private let account: MicrosoftAccount
  private let network: NetworkMonitor
  @State private var services: ScopedServicesHolder
  @State private var selection: AppSection
  // Swift-Hinweis: `@Environment(\.scenePhase)` liefert den Lebenszyklus der Szene (aktiv, inaktiv, Hintergrund).
  @Environment(\.scenePhase) private var scenePhase

  init(
    dataLocation: DataLocationController, account: MicrosoftAccount, network: NetworkMonitor,
    sourceCoordinators: SourceCoordinatorHolder
  ) {
    self.dataLocation = dataLocation
    self.account = account
    self.network = network
    _services = State(
      initialValue: ScopedServicesHolder(
        account: account, network: network, dataLocation: dataLocation,
        sourceCoordinators: sourceCoordinators))
    #if os(macOS)
      let isMac = true
    #else
      let isMac = false
    #endif
    // `try?` auf eine Funktion mit optionalem Ergebnis liefert hier ein einfaches Optional (Swift 5+).
    let hasTimetable = (try? dataLocation.store.timetable()) != nil
    _selection = State(initialValue: .initial(isMac: isMac, hasTimetable: hasTimetable))
  }

  var body: some View {
    TabView(selection: $selection) {
      Tab(AppSection.dayView.titleKey, systemImage: AppSection.dayView.systemImage, value: AppSection.dayView) {
        scoped { DayScreen() }
      }
      Tab(
        AppSection.preparation.titleKey, systemImage: AppSection.preparation.systemImage,
        value: AppSection.preparation
      ) {
        scoped { PreparationScreen() }
      }
      Tab(AppSection.setup.titleKey, systemImage: AppSection.setup.systemImage, value: AppSection.setup) {
        setup
      }
    }
    // iPad: Leiste oder Seitenleiste nach Wahl der Lehrkraft; Mac: Seitenleiste.
    .tabViewStyle(.sidebarAdaptable)
    .environment(account)
    .environment(dataLocation)
    // „Ordner freigeben“ aus der Tagesansicht führt hierher.
    .environment(\.showSetup, { selection = .setup })
    // `initial: true` ruft den Block auch beim ersten Erscheinen auf – sonst fehlt der Abruf, wenn die Szene
    // beim Kaltstart schon aktiv ist, bevor diese Ansicht steht. „Erstes Öffnen am Tag“ ist der Wechsel nach
    // `.active`, nicht der App-Start (AK-21); die Abfrage-Regeln entscheiden, ob gefragt wird.
    .onChange(of: scenePhase, initial: true) { _, newPhase in
      switch newPhase {
      case .active:
        activate(currentServices())
      case .background:
        #if os(iOS)
          MorningRefresh.schedule()
        #endif
      default:
        break
      }
    }
    // Nicht `network.onBecameOnline`: die Closure ist einzeln und gehört dem `DataLocationController`.
    .onChange(of: network.isOnline) { _, isOnline in
      if isOnline { prepareForTeaching(currentServices()) }
    }
    // Neuer Datenort: neue Dienste, neu bereithalten.
    // Der Szenen-Haken sitzt außerhalb des Teilbaums und feuert dabei nicht neu: der Abruf des neuen
    // Stundenplan-Koordinators läuft deshalb hier mit.
    .onChange(of: dataLocation.generation) { _, _ in
      activate(currentServices())
    }
    // Szenen-Zubehör für den Zweitbildschirm meldet Teilplan 06 an dieser Stelle an.
  }

  /// Datenabhängiger Inhalt eines Bereichs.
  private func scoped<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
    ScopedAppContent(controller: dataLocation, services: services, content: content)
  }

  /// Einrichten: der Rahmen samt Datenort und Kopplung steht außerhalb des datengebundenen Teilbaums,
  /// Datenabhängiges öffnet sich darin über `ScopedAppContent` (siehe `SetupView`).
  private var setup: some View {
    SetupView(dataLocation: dataLocation, account: account, services: services)
  }

  private func currentServices() -> ScopedServices {
    services.services(for: dataLocation.store)
  }

  /// Abruf beim Aktivwerden und Material bereithalten; gemeinsam für Szenenwechsel und neuen Datenort.
  private func activate(_ current: ScopedServices) {
    Task { await current.coordinator.refresh(.appBecameActive) }
    prepareForTeaching(current)
  }

  /// Hält Material für heute und die nächsten Tage bereit; ohne Stundenplan gibt es nichts zu tun.
  private func prepareForTeaching(_ current: ScopedServices) {
    guard let timetable = try? current.store.timetable() else { return }
    let periods = (try? current.store.nonTeachingPeriods()) ?? []
    let changes = (try? current.store.scheduleChanges()) ?? []
    let today = current.environment.today()
    Task {
      await current.storage.prepareForTeaching(
        today: today, timetable: timetable, nonTeachingPeriods: periods, changes: changes)
    }
  }
}

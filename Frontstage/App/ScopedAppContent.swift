import FrontstageCore
import SwiftData
import SwiftUI

/// Alle Dienste, die an einem `DataStore` hängen und deshalb mit dem Datenort wechseln.
@MainActor final class ScopedServices {
  let store: DataStore
  let storage: StorageService
  let environment: AppEnvironment
  let coordinator: TimetableSourceCoordinator

  init(
    store: DataStore, storage: StorageService, environment: AppEnvironment,
    coordinator: TimetableSourceCoordinator
  ) {
    self.store = store
    self.storage = storage
    self.environment = environment
    self.coordinator = coordinator
  }
}

/// Legt die Dienste je `DataStore` genau einmal an (Muster wie `SourceCoordinatorHolder`).
///
/// Warum ein Halter statt `@State` in jeder Ansicht: Die Bereiche (Tabs) und die Szenen-Zubehöre brauchen
/// dieselben Dienste – ein `StorageService` je Tab hielte Freigaben und Bereithalten mehrfach. Nach einem
/// Wechsel des Datenorts (neuer `DataStore`) entstehen die Dienste neu, der alte Satz wird verworfen.
@MainActor final class ScopedServicesHolder {
  private let account: MicrosoftAccount
  private let network: NetworkMonitor
  private let dataLocation: DataLocationController
  private let sourceCoordinators: SourceCoordinatorHolder
  private var current: ScopedServices?

  init(
    account: MicrosoftAccount, network: NetworkMonitor, dataLocation: DataLocationController,
    sourceCoordinators: SourceCoordinatorHolder
  ) {
    self.account = account
    self.network = network
    self.dataLocation = dataLocation
    self.sourceCoordinators = sourceCoordinators
  }

  /// Gleicher Store (nach Identität) → gleiche Dienste; anderer Store → neu anlegen.
  func services(for store: DataStore) -> ScopedServices {
    if let current, current.store === store { return current }
    let grants = FolderGrantStore()
    let resolver = MaterialResolver(grants: grants)
    let storage = StorageService(
      grants: grants, references: store, resolver: resolver,
      prefetcher: Prefetcher(resolver: resolver, store: store, downloader: SystemFileDownloader()),
      network: network, account: account,
      oneDrive: OneDriveService(
        account: account, graph: GraphClient(tokens: account.tokenProvider), grants: grants,
        resolver: resolver),
      handOff: SystemDocumentHandOff())
    let location = dataLocation
    let environment = AppEnvironment(
      store: store, storage: storage,
      today: { CalendarDay(Date(), calendar: .current) },
      dataLocation: { location.location })
    // Weitere Dienste je Store ergänzen hier: Teilplan 06 (`environment.viewerAvailable`, `environment.penNotes`),
    // Teilplan 07 (`ClassroomServices.shared.bind(store:)`). Haken beim Aktivwerden gehören in `RootView.activate(_:)`.
    let services = ScopedServices(
      store: store, storage: storage, environment: environment,
      coordinator: sourceCoordinators.coordinator(for: store))
    current = services
    return services
  }
}

/// Hängt Inhalt an den aktuellen Datenort: `DataStore`, Container und Dienste kommen aus `DataScopedRoot`
/// und werden beim Wechsel mit `.id(generation)` neu aufgebaut.
///
/// Bewusst nur für Inhalt, der an Daten hängt: Einrichten › Datenort und die Kopplung leben außerhalb
/// (siehe `RootView`), damit ein Wechsel ihr offenes Sheet nicht abreißt.
struct ScopedAppContent<Content: View>: View {
  let controller: DataLocationController
  let services: ScopedServicesHolder
  @ViewBuilder let content: () -> Content

  var body: some View {
    DataScopedRoot(controller: controller) { store, container in
      let scoped = services.services(for: store)
      content()
        .modelContainer(container)
        .environment(store)
        .environment(scoped.storage)
        .environment(scoped.environment)
        .environment(scoped.coordinator)
    }
  }
}

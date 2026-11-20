import Foundation
import FrontstageCore

/// Hält den Koordinator des aktuellen Datenorts (Übersicht, Abstimmung 15).
///
/// Warum ein App-weiter Halter: Der Koordinator hält über `repository:` einen `DataStore` und gehört deshalb
/// zum Datenort. `.backgroundTask` läuft aber auch, wenn das System die App nur im Hintergrund weckt und
/// keine Ansicht steht – dann kann der Koordinator nicht aus einer Ansicht kommen. Ansicht und
/// Hintergrundaufgabe fragen darum beide hier nach, mit dem aktuellen `DataStore`, und bekommen dasselbe
/// Objekt. Nach einem Wechsel des Datenorts (neuer `DataStore`) entsteht ein neuer Koordinator.
///
/// Swift-Hinweis: `ObjectIdentifier` vergleicht Klassen-Instanzen nach Identität (Adresse), nicht nach Wert.
/// Der Store wird mitgehalten, damit seine Adresse nicht für ein anderes Objekt wiederverwendet wird.
@MainActor final class SourceCoordinatorHolder {
  private let makeCoordinator: @MainActor (DataStore) -> TimetableSourceCoordinator
  private var current: (store: DataStore, coordinator: TimetableSourceCoordinator)?

  init(
    makeCoordinator: @escaping @MainActor (DataStore) -> TimetableSourceCoordinator =
      SourceCoordinatorHolder.live
  ) {
    self.makeCoordinator = makeCoordinator
  }

  /// Gleicher Store (nach Identität) → gleiches Objekt; anderer Store → neu anlegen, den alten verwerfen.
  func coordinator(for store: DataStore) -> TimetableSourceCoordinator {
    if let current, ObjectIdentifier(current.store) == ObjectIdentifier(store) {
      return current.coordinator
    }
    let coordinator = makeCoordinator(store)
    current = (store, coordinator)
    return coordinator
  }

  /// Der echte Koordinator: Zugangsdaten im Schlüsselbund, Stand in den UserDefaults, Vorschau als Datei.
  static func live(_ store: DataStore) -> TimetableSourceCoordinator {
    let credentials = KeychainCredentialStore()
    let coordinator = TimetableSourceCoordinator(
      repository: store,
      makeSource: { kind in
        switch kind {
        case .manual: ManualTimetableSource()
        case .schulmanager: SchulmanagerTimetableSource(credentials: credentials)
        }
      },
      credentials: credentials,
      statusStore: SourceStatusStore(),
      pendingStore: PendingImportStore(directory: PendingImportStore.defaultDirectory()))
    retireUnavailableSource(coordinator: coordinator, credentials: credentials)
    return coordinator
  }

  /// Abgeschaltete Quelle (ADR-0016): Steht im Datenort noch eine Quelle, die nicht mehr angeboten wird, gilt
  /// ab jetzt „von Hand“ – der zuletzt übernommene Stundenplan bleibt, Abweichungen der Quelle ab heute fallen
  /// weg (wie beim Wechsel von Hand). Zugangsdaten für Schulmanager werden aus dem Schlüsselbund dieses Geräts
  /// gelöscht, damit kein ungenutztes Passwort liegen bleibt. Beides ist ohne Wirkung, wenn nichts da ist.
  private static func retireUnavailableSource(
    coordinator: TimetableSourceCoordinator, credentials: any CredentialStore
  ) {
    if !TimetableSourceKind.schulmanager.isAvailable {
      try? credentials.delete()
    }
    if let kind = try? coordinator.repository.timetableSourceKind(), !kind.isAvailable {
      try? coordinator.switchSource(to: .manual)
    }
  }
}

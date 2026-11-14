import Network
import Observation

/// Beobachtet, ob das Gerät Netz hat (NFR-1: bei Netz wird bereitgehalten).
///
/// Swift-Hinweis: `NWPathMonitor` ruft seinen Handler auf der übergebenen `DispatchQueue` auf, nicht auf
/// dem Hauptthread; die Zustandsänderung wird deshalb per `Task { @MainActor in … }` übergeben.
/// `@ObservationIgnored` nimmt den Monitor aus der Beobachtung heraus – nur `isOnline` soll Ansichten auslösen.
@MainActor @Observable final class NetworkMonitor {
  private(set) var isOnline: Bool
  /// Wird beim Wechsel von offline zu online gerufen (nicht beim ersten Wert, wenn schon online).
  var onBecameOnline: (() -> Void)?

  @ObservationIgnored private let monitor = NWPathMonitor()
  @ObservationIgnored private let queue = DispatchQueue(label: "frontstage.network-monitor")
  @ObservationIgnored private var isStarted = false

  /// Startwert; Tests setzen ihn, ohne `start()` aufzurufen.
  init(isOnline: Bool = false) {
    self.isOnline = isOnline
  }

  /// Beginnt die Beobachtung; ein zweiter Aufruf tut nichts.
  func start() {
    guard !isStarted else { return }
    isStarted = true
    monitor.pathUpdateHandler = { [weak self] path in
      let online = path.status == .satisfied
      Task { @MainActor in self?.update(isOnline: online) }
    }
    monitor.start(queue: queue)
  }

  private func update(isOnline online: Bool) {
    let wasOnline = isOnline
    isOnline = online
    if online && !wasOnline { onBecameOnline?() }
  }

  deinit { monitor.cancel() }
}

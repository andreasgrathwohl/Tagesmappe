import Network
import Observation

/// Beobachtet, ob das Gerät Netz hat (NFR-1: bei Netz wird bereitgehalten).
///
/// Swift-Hinweis: `NWPathMonitor` ruft seinen Handler auf der übergebenen `DispatchQueue` auf, nicht auf
/// dem Hauptthread. Der Handler ist deshalb ausdrücklich `@Sendable`: Ohne diese Angabe erbte die Closure
/// unter Swift 6 die Hauptakteur-Isolation der Methode, in der sie entsteht, und die Laufzeitprüfung der
/// Isolation bräche beim ersten Aufruf auf der fremden Warteschlange ab. Die Zustandsänderung wird per
/// `Task { @MainActor in … }` übergeben.
/// `@ObservationIgnored` nimmt den Monitor aus der Beobachtung heraus – nur `isOnline` soll Ansichten auslösen.
@MainActor @Observable final class NetworkMonitor {
  private(set) var isOnline: Bool
  /// Wird beim Wechsel von offline zu online gerufen (nicht beim ersten Wert, wenn schon online).
  var onBecameOnline: (() -> Void)?

  @ObservationIgnored private let pathMonitor = PathMonitorBox()
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
    pathMonitor.monitor.pathUpdateHandler = { @Sendable [weak self] path in
      let online = path.status == .satisfied
      Task { @MainActor [weak self] in self?.update(isOnline: online) }
    }
    pathMonitor.monitor.start(queue: queue)
  }

  private func update(isOnline online: Bool) {
    let wasOnline = isOnline
    isOnline = online
    if online && !wasOnline { onBecameOnline?() }
  }
}

/// Hält den `NWPathMonitor` und beendet ihn beim Freigeben.
///
/// Swift-Hinweis: Das `deinit` einer `@MainActor`-Klasse ist nicht isoliert und darf unter Swift 6 keine
/// nicht-`Sendable`-Eigenschaft anfassen. Diese Hülle ohne Akteur übernimmt das Beenden; `@unchecked Sendable`
/// ist vertretbar, weil die Hülle nur eine Konstante hält und den Monitor außer beim Start nur noch beendet.
private final class PathMonitorBox: @unchecked Sendable {
  let monitor = NWPathMonitor()

  deinit { monitor.cancel() }
}

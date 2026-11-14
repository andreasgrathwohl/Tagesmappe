import Foundation
import Testing

@testable import Frontstage

/// Zählt die Aufrufe von `onBecameOnline`.
@MainActor private final class Counter {
  var count = 0
}

@MainActor @Suite struct NetworkMonitorTests {
  @Test("Der erste Netzzustand nach dem Start löst keinen Abgleich aus, erst ein echter Wechsel")
  func firstPathIsNotATransition() {
    let monitor = NetworkMonitor()
    let counter = Counter()
    monitor.onBecameOnline = { MainActor.assumeIsolated { counter.count += 1 } }

    monitor.update(isOnline: true)
    #expect(monitor.isOnline)
    #expect(counter.count == 0)

    monitor.update(isOnline: false)
    monitor.update(isOnline: true)
    #expect(counter.count == 1)

    monitor.update(isOnline: true)
    #expect(counter.count == 1)
  }
}

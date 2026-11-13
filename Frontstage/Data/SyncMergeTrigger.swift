import CoreData  // nur für den Namen der Mitteilung .NSPersistentStoreRemoteChange
import Foundation
import OSLog

/// Stößt das Zusammenführen an: beim Start, beim Wechsel in den Vordergrund und nach Fernänderungen (entprellt).
///
/// Swift-Hinweis: Der Beobachter-Block von `NotificationCenter` ist nicht als `@MainActor` markiert,
/// läuft mit `queue: .main` aber auf der Hauptwarteschlange. `MainActor.assumeIsolated` sagt dem
/// Compiler genau das zu (und bricht zur Laufzeit ab, falls es nicht stimmt).
@MainActor final class SyncMergeTrigger {
  private let store: DataStore
  private let debounce: Duration
  private var observer: NSObjectProtocol?
  private var pendingMerge: Task<Void, Never>?

  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "sync")

  init(store: DataStore, debounce: Duration = .seconds(2)) {
    self.store = store
    self.debounce = debounce
  }

  /// Einmal zusammenführen und den Beobachter für Fernänderungen anmelden (nur einmal).
  func start() {
    merge()
    guard observer == nil else { return }
    observer = NotificationCenter.default.addObserver(
      forName: .NSPersistentStoreRemoteChange, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.remoteChangeReceived() }
    }
  }

  /// Beim Wechsel in den Vordergrund sofort zusammenführen.
  func sceneDidBecomeActive() {
    merge()
  }

  /// Eine laufende Wartezeit wird abgebrochen; nach `debounce` wird zusammengeführt.
  func remoteChangeReceived() {
    pendingMerge?.cancel()
    pendingMerge = Task { [debounce] in
      do {
        try await Task.sleep(for: debounce)
      } catch {
        return  // abgebrochen: eine neuere Fernänderung hat die Wartezeit neu gestartet
      }
      Self.logger.info("Zusammenführen nach Fernänderung")
      merge()
    }
  }

  /// Meldet den Beobachter ab und bricht eine Wartezeit ab.
  func stop() {
    pendingMerge?.cancel()
    pendingMerge = nil
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil
  }

  /// Fehler werden protokolliert, nie angezeigt.
  private func merge() {
    do {
      try store.mergeDuplicates()
    } catch {
      Self.logger.error("Zusammenführen fehlgeschlagen: \(String(describing: error), privacy: .public)")
    }
  }
}

import Foundation
import FrontstageCore

/// Liest den Inhalt eines Materials über die Ablage, nur lesend.
///
/// Die Arbeit macht `StorageService.withFileURL(for:_:)` (Teilplan 03): Zugriff öffnen, Verfügbarkeit prüfen,
/// koordiniert (`.withoutChanges`) außerhalb des Hauptthreads lesen und den Zugriff in jedem Fall schließen.
/// Eine zweite Koordination gibt es hier bewusst nicht. Nicht auflösbar oder nicht verfügbar → wirft.
struct ScopedFileReader: MaterialFileReading {
  /// Swift-Hinweis: `StorageService` ist `@MainActor` und damit `Sendable`; der Aufruf springt bei Bedarf auf den
  /// Hauptakteur, das Lesen selbst läuft in `withFileURL` abseits davon.
  private let storage: StorageService

  init(storage: StorageService) {
    self.storage = storage
  }

  func readData(for reference: MaterialReference) async throws -> Data {
    try await storage.withFileURL(for: reference) { url in try Data(contentsOf: url) }
  }
}

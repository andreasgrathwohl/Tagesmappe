import Foundation
import FrontstageCore

/// Liest den Inhalt eines Materials, nur lesend. Die Umsetzung über die Ablage (`ScopedFileReader`, Teilplan 06
/// Task 10) öffnet den Zugriff, liest koordiniert außerhalb des Hauptthreads und schließt in jedem Fall wieder;
/// Tests nehmen einen Ersatz mit festen Daten.
protocol MaterialFileReading: Sendable {
  func readData(for reference: MaterialReference) async throws -> Data
}

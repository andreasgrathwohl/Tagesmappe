import Foundation
import FrontstageCore
import SwiftData

/// Container je Datenort (ADR-0012): iCloud spiegelt, OneDrive hält eine eigene lokale Datei ohne Spiegelung.
extension ModelContainerFactory {
  /// Application Support/Frontstage-onedrive.store
  static var oneDriveStoreURL: URL {
    URL.applicationSupportDirectory.appending(path: "Frontstage-onedrive.store", directoryHint: .notDirectory)
  }

  /// Eigene Datei, ausdrücklich ohne CloudKit-Spiegelung.
  static func makeOneDriveContainer(url: URL = oneDriveStoreURL) throws -> ModelContainer {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let schema = Schema(modelTypes)
    let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    return try ModelContainer(for: schema, configurations: [configuration])
  }

  /// Unter Tests: im Speicher wie `makeDefault`; sonst je nach Datenort.
  static func makeContainer(for location: DataLocation) throws -> ModelContainer {
    let underTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    if underTest { return try makeInMemoryContainer() }
    switch location {
    case .iCloud:
      guard let identifier = cloudKitContainerIdentifier() else { return try makeInMemoryContainer() }
      return try makeCloudContainer(identifier: identifier)
    case .oneDrive:
      return try makeOneDriveContainer()
    }
  }

  /// Löscht die OneDrive-Datei samt `-shm`/`-wal`; fehlende Dateien sind kein Fehler.
  static func removeOneDriveStore(url: URL = oneDriveStoreURL) throws {
    let manager = FileManager.default
    for suffix in ["", "-shm", "-wal"] {
      let file = URL(fileURLWithPath: url.path + suffix)
      if manager.fileExists(atPath: file.path) { try manager.removeItem(at: file) }
    }
  }
}

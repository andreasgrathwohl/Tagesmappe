import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

@MainActor @Suite struct DataLocationSettingsTests {
  private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "test-\(UUID().uuidString)")!
  }

  @Test("FR-14: Ohne Wahl iCloud; Datenort und Datenordner bleiben je Gerät gespeichert")
  func locationAndFolderPersist() {
    let defaults = makeDefaults()
    let settings = DataLocationSettings(defaults: defaults)
    #expect(settings.location == .iCloud)
    #expect(settings.dataFolder == nil)
    #expect(!settings.hasChosen)

    let folder = DataFolder(
      driveID: "drive-1", folderItemID: "item-1", libraryID: UUID(), accountUsername: "max@example.com")
    settings.location = .oneDrive
    settings.dataFolder = folder

    let reread = DataLocationSettings(defaults: defaults)
    #expect(reread.location == .oneDrive)
    #expect(reread.dataFolder == folder)
    #expect(reread.hasChosen)

    reread.dataFolder = nil
    #expect(DataLocationSettings(defaults: defaults).dataFolder == nil)
  }

  @Test("Geräte-Kennung bleibt gleich")
  func deviceIDIsStable() {
    let defaults = makeDefaults()
    let first = DeviceIdentity.current(defaults: defaults)
    #expect(!first.isEmpty)
    #expect(DeviceIdentity.current(defaults: defaults) == first)
    #expect(DeviceIdentity.current(defaults: makeDefaults()) != first)
  }

  @Test("OneDrive-Container spiegelt nicht und speichert in eigene Datei")
  func oneDriveContainerUsesOwnFile() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "Frontstage-onedrive.store")

    // Die Spiegelung (`cloudKitDatabase: .none`) steht wörtlich in der Fabrik; der Typ ist nicht vergleichbar.
    let container = try ModelContainerFactory.makeOneDriveContainer(url: url)
    let configuration = try #require(container.configurations.first)
    #expect(configuration.url == url)
    #expect(url != ModelContainerFactory.oneDriveStoreURL)

    let context = ModelContext(container)
    context.insert(TimetableRecord())
    try context.save()
    #expect(FileManager.default.fileExists(atPath: url.path))

    try ModelContainerFactory.removeOneDriveStore(url: url)
    #expect(!FileManager.default.fileExists(atPath: url.path))
  }

  @Test("Entfernen der OneDrive-Datei nimmt den Ordner für große Werte (externalStorage) mit")
  func removeOneDriveStoreRemovesExternalStorage() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "test-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "Frontstage-onedrive.store")
    let support = ModelContainerFactory.externalStorageFolder(for: url)
    #expect(support.lastPathComponent == ".Frontstage-onedrive_SUPPORT")
    #expect(support.deletingLastPathComponent().path == directory.path)

    let blobFolder = support.appending(path: "_EXTERNAL_DATA")
    try FileManager.default.createDirectory(at: blobFolder, withIntermediateDirectories: true)
    try Data([1, 2, 3]).write(to: blobFolder.appending(path: "blob"))
    try Data([4]).write(to: url)

    try ModelContainerFactory.removeOneDriveStore(url: url)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    #expect(!FileManager.default.fileExists(atPath: support.path))
  }
}

import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct FolderGrantStoreTests {
  let root: URL
  let storeFile: URL

  init() throws {
    root = FileManager.default.temporaryDirectory.appending(path: "grants-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    storeFile = root.appending(path: "FolderGrants.json", directoryHint: .notDirectory)
  }

  private func makeFolder(_ name: String) throws -> URL {
    let url = root.appending(path: name, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @Test("Freigabe wird gespeichert und nach Neustart geladen")
  func addPersistsAndReloads() throws {
    let folder = try makeFolder("Unterricht")
    let store = FolderGrantStore(fileURL: storeFile)
    _ = try store.add(folderURL: folder, name: "Unterricht")
    let reloaded = FolderGrantStore(fileURL: storeFile)
    #expect(reloaded.grants.count == 1)
    #expect(reloaded.grants.first?.name == "Unterricht")
    let grant = try #require(reloaded.grants.first)
    #expect(reloaded.resolvedURL(for: grant) != nil)
  }

  @Test("Gleicher Name zweimal: nameInUse")
  func duplicateNameThrows() throws {
    let store = FolderGrantStore(fileURL: storeFile)
    _ = try store.add(folderURL: try makeFolder("A"), name: "Unterricht")
    let second = try makeFolder("B")
    #expect(throws: FolderGrantError.nameInUse) {
      try store.add(folderURL: second, name: "unterricht")
    }
    #expect(store.grants.count == 1)
  }

  @Test("Datei ist von der Sicherung ausgeschlossen")
  func fileExcludedFromBackup() throws {
    let store = FolderGrantStore(fileURL: storeFile)
    _ = try store.add(folderURL: try makeFolder("Unterricht"), name: "Unterricht")
    let values = try storeFile.resourceValues(forKeys: [.isExcludedFromBackupKey])
    #expect(values.isExcludedFromBackup == true)
  }

  @Test("Entfernter Ordner: resolvedURL nil statt Fehler (Review Focus 2)")
  func unresolvableBookmarkIsReportedNotThrown() throws {
    let folder = try makeFolder("Weg")
    let store = FolderGrantStore(fileURL: storeFile)
    let grant = try store.add(folderURL: folder, name: "Weg")
    try FileManager.default.removeItem(at: folder)
    #expect(store.resolvedURL(for: grant) == nil)
  }

  @Test("Umbenennen und OneDrive-Pfad setzen bleiben nach Neustart")
  func renameAndOneDrivePathPersist() throws {
    let store = FolderGrantStore(fileURL: storeFile)
    let grant = try store.add(folderURL: try makeFolder("Unterricht"), name: "Unterricht")
    try store.rename(id: grant.id, to: "Englisch")
    store.setOneDrivePath(id: grant.id, "Schule/Englisch")
    let reloaded = FolderGrantStore(fileURL: storeFile)
    #expect(reloaded.grant(named: "Englisch")?.oneDrivePath == "Schule/Englisch")
    #expect(reloaded.grant(named: "Unterricht") == nil)
  }

  @Test("grantLocations liefert normalisierte Komponenten")
  func grantLocationsAreNormalized() throws {
    let folder = try makeFolder("Unterricht")
    let store = FolderGrantStore(fileURL: storeFile)
    _ = try store.add(folderURL: folder, name: "Unterricht")
    let locations = store.grantLocations()
    #expect(locations.count == 1)
    #expect(locations.first?.name == "Unterricht")
    #expect(locations.first?.components.last == "Unterricht")
    #expect(locations.first?.components.first != "private")
  }
}

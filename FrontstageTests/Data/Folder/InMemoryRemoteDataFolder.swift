import Foundation
import FrontstageCore

@testable import Frontstage

/// Datenordner im Speicher für Abgleich-Tests. Zwei Geräte im Test teilen sich eine Instanz.
///
/// Verhält sich wie Graph, soweit der Abgleich es braucht: jede Datei hat Kennung und eTag, jede
/// Änderung erhöht einen Zähler, `delta` liefert die Änderungen seit einem Link (Link = Zählerstand
/// als Text). Fehler lassen sich auf Wunsch auslösen.
actor InMemoryRemoteDataFolder: RemoteDataFolder {
  private struct Stored {
    var itemID: String
    var eTag: String
    var data: Data
    var lastModified: Date
  }

  /// Eine Änderung im Protokoll; Löschungen tragen nur die Kennung.
  private struct Change {
    let counter: Int
    let item: RemoteItem
  }

  static let appFolderID = "approot-1"
  static let driveID = "drive-1"

  private var files: [String: Stored] = [:]
  private var folders: Set<String> = []
  private var changes: [Change] = []
  private var nextID = 1

  /// Anzahl aller Änderungen bisher (Hochladen, Löschen, Ordner anlegen).
  private(set) var changeCount = 0
  private(set) var uploadCount = 0
  private(set) var downloadCount = 0

  private var queuedErrors: [RemoteDataFolderError] = []
  private var linksExpired = false

  init() {}

  // MARK: Fehler auslösen

  /// Der nächste Aufruf (egal welcher) wirft `error`; mit `times` mehrere Aufrufe nacheinander.
  func failNextCalls(with error: RemoteDataFolderError, times: Int = 1) {
    queuedErrors.append(contentsOf: Array(repeating: error, count: times))
  }

  /// Ab jetzt wirft jedes `delta(link:)` mit Link `resyncRequired` (410), bis eine Aufzählung ohne Link
  /// (`delta(link: nil)`) neu beginnt.
  func expireDeltaLinks() { linksExpired = true }

  private func checkQueuedError() throws {
    if !queuedErrors.isEmpty { throw queuedErrors.removeFirst() }
  }

  // MARK: Prüfwerte

  /// Aktueller Inhalt einer Datei (nil = nicht vorhanden).
  func content(at path: String) -> Data? { files[path]?.data }

  var paths: [String] { files.keys.sorted() }

  // MARK: RemoteDataFolder

  func appFolder() async throws -> AppFolderInfo {
    try checkQueuedError()
    return AppFolderInfo(driveID: Self.driveID, folderItemID: Self.appFolderID)
  }

  func delta(link: String?) async throws -> DeltaPage {
    try checkQueuedError()
    guard let link else {
      linksExpired = false
      return DeltaPage(items: currentItems(), nextLink: nil, deltaLink: String(changeCount))
    }
    if linksExpired { throw RemoteDataFolderError.resyncRequired }
    guard let since = Int(link) else { throw RemoteDataFolderError.resyncRequired }
    // Je Kennung gewinnt die letzte Änderung.
    var latest: [String: RemoteItem] = [:]
    var order: [String] = []
    for change in changes where change.counter > since {
      if latest[change.item.id] == nil { order.append(change.item.id) }
      latest[change.item.id] = change.item
    }
    return DeltaPage(items: order.compactMap { latest[$0] }, nextLink: nil, deltaLink: String(changeCount))
  }

  func listAll() async throws -> [RemoteItem] {
    try checkQueuedError()
    return currentItems()
  }

  func download(itemID: String) async throws -> Data {
    try checkQueuedError()
    guard let stored = files.values.first(where: { $0.itemID == itemID }) else {
      throw RemoteDataFolderError.server(404)
    }
    downloadCount += 1
    return stored.data
  }

  func upload(_ data: Data, to path: String, ifMatch: String?) async throws -> RemoteFile {
    try checkQueuedError()
    guard path == RemoteLayout.libraryPath || RemoteLayout.isValidPath(path) else {
      throw RemoteDataFolderError.invalidPath(path)
    }
    if let ifMatch {
      guard let existing = files[path], existing.eTag == ifMatch else {
        throw RemoteDataFolderError.preconditionFailed(path: path)
      }
    }
    changeCount += 1
    uploadCount += 1
    let itemID = files[path]?.itemID ?? newItemID()
    let stored = Stored(itemID: itemID, eTag: "\"e\(changeCount)\"", data: data, lastModified: Date())
    files[path] = stored
    ensureFolder(for: path)
    changes.append(Change(counter: changeCount, item: item(path: path, stored: stored)))
    return file(path: path, stored: stored)
  }

  func delete(_ file: RemoteFile) async throws {
    try checkQueuedError()
    guard let existing = files[file.path] else { return }  // schon weg = erledigt
    if !file.eTag.isEmpty, existing.eTag != file.eTag {
      throw RemoteDataFolderError.preconditionFailed(path: file.path)
    }
    files[file.path] = nil
    changeCount += 1
    changes.append(
      Change(
        counter: changeCount,
        item: RemoteItem(
          id: existing.itemID, name: nil, parentID: nil, isFolder: false, isDeleted: true,
          eTag: nil, size: nil, lastModified: nil)))
  }

  func ensureModelFolders() async throws {
    try checkQueuedError()
    for model in SyncModel.allCases where !folders.contains(model.rawValue) {
      folders.insert(model.rawValue)
      changeCount += 1
      changes.append(Change(counter: changeCount, item: folderItem(model.rawValue)))
    }
  }

  // MARK: Intern

  private func newItemID() -> String {
    defer { nextID += 1 }
    return "item-\(nextID)"
  }

  private func folderID(_ name: String) -> String { "folder-\(name)" }

  private func folderItem(_ name: String) -> RemoteItem {
    RemoteItem(
      id: folderID(name), name: name, parentID: Self.appFolderID, isFolder: true, isDeleted: false,
      eTag: nil, size: nil, lastModified: nil)
  }

  /// Legt den Modellordner einer hochgeladenen Datei an, falls er fehlt.
  private func ensureFolder(for path: String) {
    guard let name = path.split(separator: "/").first.map(String.init), path.contains("/"),
      !folders.contains(name)
    else { return }
    folders.insert(name)
    changes.append(Change(counter: changeCount, item: folderItem(name)))
  }

  private func item(path: String, stored: Stored) -> RemoteItem {
    let parts = path.split(separator: "/").map(String.init)
    let parent = parts.count > 1 ? folderID(parts[0]) : Self.appFolderID
    return RemoteItem(
      id: stored.itemID, name: parts.last, parentID: parent, isFolder: false, isDeleted: false,
      eTag: stored.eTag, size: stored.data.count, lastModified: stored.lastModified)
  }

  private func file(path: String, stored: Stored) -> RemoteFile {
    RemoteFile(
      path: path, itemID: stored.itemID, eTag: stored.eTag, size: stored.data.count,
      lastModified: stored.lastModified)
  }

  private func currentItems() -> [RemoteItem] {
    folders.sorted().map { folderItem($0) } + files.sorted { $0.key < $1.key }.map { item(path: $0.key, stored: $0.value) }
  }
}

/// Reicht alles an einen Datenordner weiter; `delta` hält an, solange das Tor zu ist. So lässt sich ein
/// Durchgang mitten im Lauf festhalten (Wettläufe mit `stop()` oder einem Wechsel des Datenorts).
///
/// Swift-Hinweis: Das Warten ist ein kurzes Schlafen in einer Schleife statt einer Fortsetzung; ein Akteur ist
/// während `Task.sleep` für andere Aufrufe (hier `openGate()`) frei.
actor GatedRemoteDataFolder: RemoteDataFolder {
  private let inner: any RemoteDataFolder
  private var gateClosed = false
  /// Anzahl der `delta`-Aufrufe, die am geschlossenen Tor gewartet haben.
  private(set) var waitingCount = 0
  /// Gesetzt: jedes `delete` wirft diesen Fehler.
  private var deleteError: RemoteDataFolderError?

  init(_ inner: any RemoteDataFolder) { self.inner = inner }

  func closeGate() { gateClosed = true }
  func openGate() { gateClosed = false }
  func failDeletes(with error: RemoteDataFolderError?) { deleteError = error }

  func appFolder() async throws -> AppFolderInfo { try await inner.appFolder() }
  func delta(link: String?) async throws -> DeltaPage {
    if gateClosed {
      waitingCount += 1
      while gateClosed { try? await Task.sleep(for: .milliseconds(5)) }
    }
    return try await inner.delta(link: link)
  }
  func listAll() async throws -> [RemoteItem] { try await inner.listAll() }
  func download(itemID: String) async throws -> Data { try await inner.download(itemID: itemID) }
  func upload(_ data: Data, to path: String, ifMatch: String?) async throws -> RemoteFile {
    try await inner.upload(data, to: path, ifMatch: ifMatch)
  }
  func delete(_ file: RemoteFile) async throws {
    if let deleteError { throw deleteError }
    try await inner.delete(file)
  }
  func ensureModelFolders() async throws { try await inner.ensureModelFolders() }
}

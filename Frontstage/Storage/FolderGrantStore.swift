import Foundation
import FrontstageCore

/// Speichert die Ordnerfreigaben dieses Geräts als JSON in Application Support.
/// Die Datei ist von der Sicherung ausgeschlossen: Bookmarks gelten nur auf diesem Gerät.
@MainActor final class FolderGrantStore {
  private let fileURL: URL
  private(set) var grants: [FolderGrant] = []

  /// `Application Support/FolderGrants.json`
  static var defaultFileURL: URL {
    URL.applicationSupportDirectory.appending(path: "FolderGrants.json", directoryHint: .notDirectory)
  }

  init(fileURL: URL = FolderGrantStore.defaultFileURL) {
    self.fileURL = fileURL
    if let data = try? Data(contentsOf: fileURL),
      let loaded = try? JSONDecoder().decode([FolderGrant].self, from: data)
    {
      grants = loaded
    }
  }

  // MARK: Bookmark-Optionen je Plattform

  // Lesen und Schreiben: Neben dem Dokument entstehen Notiz-Datei und Notiz-PDF (ADR-0011, Teilplan 06),
  // im Datenordner der Ablage die App-Daten (ADR-0010, Teilplan 08). Ein nur lesendes Bookmark ließe sich
  // später nicht hochstufen – jede Lehrkraft müsste alle Ordner neu freigeben. Dass die App nie eine
  // Material-Datei verändert (FR-3.4), sichert der Code: Die Ablage bietet für Material nur lesende Wege
  // (`ScopedFile`, `StorageService.withFileURL` mit `.withoutChanges`), keinen Schreibaufruf.
  #if os(macOS)
    private static let creationOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
    private static let resolutionOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
  #else
    private static let creationOptions: URL.BookmarkCreationOptions = [.minimalBookmark]
    private static let resolutionOptions: URL.BookmarkResolutionOptions = []
  #endif

  private static func makeBookmark(for url: URL) throws -> Data {
    // Das Bookmark entsteht innerhalb des Zugriffsfensters. Auf iOS liefert der Aufruf für
    // Ordner außerhalb der Ordnerauswahl `false` (z. B. im Test); das ist kein Fehler.
    let accessing = url.startAccessingSecurityScopedResource()
    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
    #if os(macOS)
      guard accessing else { throw FolderGrantError.accessDenied }
    #endif
    do {
      return try url.bookmarkData(options: creationOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
    } catch {
      throw FolderGrantError.bookmarkFailed
    }
  }

  // MARK: Verwalten

  /// Legt eine Freigabe an. `folderURL` stammt aus der Ordnerauswahl (security-scoped).
  func add(folderURL: URL, name: String) throws -> FolderGrant {
    guard !isNameTaken(name, excluding: nil) else { throw FolderGrantError.nameInUse }
    let grant = FolderGrant(
      id: UUID(), name: name, bookmark: try Self.makeBookmark(for: folderURL),
      displayPath: folderURL.path(percentEncoded: false), oneDrivePath: nil)
    grants.append(grant)
    save()
    return grant
  }

  func rename(id: UUID, to name: String) throws {
    guard let index = grants.firstIndex(where: { $0.id == id }) else { return }
    guard !isNameTaken(name, excluding: id) else { throw FolderGrantError.nameInUse }
    grants[index].name = name
    save()
  }

  func setOneDrivePath(id: UUID, _ path: String?) {
    guard let index = grants.firstIndex(where: { $0.id == id }) else { return }
    grants[index].oneDrivePath = path
    save()
  }

  func remove(id: UUID) {
    grants.removeAll { $0.id == id }
    save()
  }

  /// Löst das Bookmark auf und erneuert es bei `isStale`.
  /// `nil` heißt: Freigabe entzogen oder Ordner weg – nie ein Fehler.
  /// Auf macOS muss der Aufrufer die URL selbst mit `startAccessingSecurityScopedResource()` öffnen.
  func resolvedURL(for grant: FolderGrant) -> URL? {
    var isStale = false
    guard
      let url = try? URL(
        resolvingBookmarkData: grant.bookmark, options: Self.resolutionOptions, relativeTo: nil,
        bookmarkDataIsStale: &isStale)
    else { return nil }
    if isStale, let index = grants.firstIndex(where: { $0.id == grant.id }),
      let fresh = try? Self.makeBookmark(for: url)
    {
      grants[index].bookmark = fresh
      grants[index].displayPath = url.path(percentEncoded: false)
      save()
    }
    return url
  }

  func grant(named name: String) -> FolderGrant? {
    grants.first { Self.key($0.name) == Self.key(name) }
  }

  /// Aufgelöste Freigaben als normalisierte Pfadbestandteile für `StoragePath.relativeLocation`.
  /// Nicht auflösbare Freigaben fehlen.
  func grantLocations() -> [GrantLocation] {
    grants.compactMap { grant in
      resolvedURL(for: grant).map {
        GrantLocation(name: grant.name, components: StoragePath.normalizedComponents($0.path(percentEncoded: false)))
      }
    }
  }

  // MARK: Intern

  /// Namen gelten ohne Groß-/Kleinschreibung und in NFC als gleich.
  private static func key(_ name: String) -> String {
    name.precomposedStringWithCanonicalMapping.lowercased()
  }

  private func isNameTaken(_ name: String, excluding id: UUID?) -> Bool {
    grants.contains { $0.id != id && Self.key($0.name) == Self.key(name) }
  }

  private func save() {
    do {
      let directory = fileURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try JSONEncoder().encode(grants).write(to: fileURL, options: .atomic)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var url = fileURL
      try url.setResourceValues(values)
    } catch {
      // Speichern ist best effort: Bei einem Fehler bleiben die Freigaben im Speicher,
      // die nächste Änderung versucht es erneut.
    }
  }
}

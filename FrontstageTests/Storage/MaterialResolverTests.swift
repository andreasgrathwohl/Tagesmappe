import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct MaterialResolverTests {
  let root: URL
  let folder: URL
  let resolver: MaterialResolver

  init() throws {
    root = FileManager.default.temporaryDirectory.appending(path: "resolver-\(UUID().uuidString)", directoryHint: .isDirectory)
    folder = root.appending(path: "Unterricht", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let store = FolderGrantStore(fileURL: root.appending(path: "FolderGrants.json", directoryHint: .notDirectory))
    _ = try store.add(folderURL: folder, name: "Unterricht")
    resolver = MaterialResolver(grants: store)
  }

  @discardableResult
  private func makeFile(_ relativePath: String) throws -> URL {
    let url = folder.appending(path: relativePath, directoryHint: .notDirectory)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data("x".utf8).write(to: url)
    return url
  }

  private func reference(_ path: String, grant: String = "Unterricht") -> MaterialReference {
    MaterialReference(folderGrantName: grant, relativePath: path, displayName: "Datei", fileKind: .pdf)
  }

  @Test("Vorhandene lokale Datei: auf dem Gerät, aktuell")
  func localFileIsOnDevice() throws {
    try makeFile("8b/Arbeitsblatt Vokabeln.pdf")
    let availability = resolver.availability(of: reference("8b/Arbeitsblatt Vokabeln.pdf"), isOnline: true)
    #expect(availability == .onDevice(isCurrent: true))
  }

  @Test("Datei fehlt: nicht verfügbar, fileMissing (AK-9-Gegenfall)")
  func missingFileIsUnavailable() {
    let availability = resolver.availability(of: reference("8b/gibt-es-nicht.pdf"), isOnline: true)
    #expect(availability == .unavailable(.fileMissing))
  }

  @Test("Unbekannter Freigabename: grantMissing (Review Focus 2)")
  func unknownGrantNameIsGrantMissing() {
    let unknown = reference("a.pdf", grant: "Unbekannt")
    #expect(resolver.availability(of: unknown, isOnline: true) == .unavailable(.grantMissing))
    #expect(resolver.resolve(unknown) == nil)
  }

  @Test("NFD-Name auf der Platte löst NFC-Verweis auf (Review Focus 1)")
  func resolvesNfdNameOnDisk() throws {
    try makeFile("U\u{0308}bung.docx")
    #expect(resolver.resolve(reference("Übung.docx")) != nil)
  }

  @Test("Gewählte Datei innerhalb der Freigabe ergibt Verweis mit Dateiart")
  func pickedFileBecomesReference() throws {
    let url = try makeFile("8b/Arbeitsblatt Vokabeln.pdf")
    let picked = try #require(resolver.reference(forPickedFile: url))
    #expect(picked.folderGrantName == "Unterricht")
    #expect(picked.relativePath == "8b/Arbeitsblatt Vokabeln.pdf")
    #expect(picked.displayName == "Arbeitsblatt Vokabeln")
    #expect(picked.fileKind == .pdf)
  }

  @Test("FR-6.3: Lösung im Ordner des Blatts wird vorgeschlagen")
  func suggestsSolutionBesideSheet() throws {
    try makeFile("8b/AB Bruchrechnen.pdf")
    try makeFile("8b/AB Bruchrechnen – Lösung.pdf")
    try makeFile("8b/Andere.pdf")
    let suggestion = try #require(resolver.suggestedSolution(for: reference("8b/AB Bruchrechnen.pdf")))
    #expect(suggestion.folderGrantName == "Unterricht")
    #expect(suggestion.relativePath == "8b/AB Bruchrechnen – Lösung.pdf")
    #expect(suggestion.displayName == "AB Bruchrechnen – Lösung")
    #expect(suggestion.fileKind == .pdf)
  }

  @Test("FR-6.3: ohne passende Datei kein Vorschlag, auch im Wurzelordner")
  func noSolutionSuggestionWithoutCandidate() throws {
    try makeFile("AB Bruchrechnen.pdf")
    try makeFile("AB Brüche – Lösung.pdf")
    #expect(resolver.suggestedSolution(for: reference("AB Bruchrechnen.pdf")) == nil)
  }

  @Test("Gewählte Datei außerhalb: nil")
  func pickedFileOutsideGrantsIsNil() throws {
    let outside = root.appending(path: "Fremd.pdf", directoryHint: .notDirectory)
    try Data("x".utf8).write(to: outside)
    #expect(resolver.reference(forPickedFile: outside) == nil)
  }

  @Test("ScopedFile.close beendet den Zugriff nur einmal")
  func scopedFileClosesOnce() throws {
    try makeFile("8b/Arbeitsblatt Vokabeln.pdf")
    // Nur Zugriffe auf den eigenen temporären Ordner zählen: Andere Suiten laufen parallel.
    let scope = root.lastPathComponent
    let file = try #require(resolver.open(reference("8b/Arbeitsblatt Vokabeln.pdf")))
    #expect(ScopedFile.openCount(scopePathContaining: scope) == 1)
    file.close()
    file.close()
    #expect(ScopedFile.openCount(scopePathContaining: scope) == 0)
  }
}

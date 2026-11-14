import Foundation
import Testing
@testable import FrontstageCore

@Suite("DataFolder RemoteIndex")
struct RemoteIndexTests {
  private func id(_ n: Int) -> UUID {
    let digits = String(n)
    let padded = String(repeating: "0", count: 12 - digits.count) + digits
    return UUID(uuidString: "00000000-0000-0000-0000-\(padded)")!
  }

  private func folder(_ itemID: String, _ name: String, parent: String) -> RemoteItem {
    RemoteItem(id: itemID, name: name, parentID: parent, isFolder: true, isDeleted: false, eTag: nil, size: nil, lastModified: nil)
  }

  private func file(_ itemID: String, _ name: String, parent: String, eTag: String = "e1") -> RemoteItem {
    RemoteItem(
      id: itemID, name: name, parentID: parent, isFolder: false, isDeleted: false, eTag: eTag, size: 10,
      lastModified: Date(timeIntervalSince1970: 1_000))
  }

  private func deleted(_ itemID: String) -> RemoteItem {
    RemoteItem(id: itemID, name: nil, parentID: nil, isFolder: false, isDeleted: true, eTag: nil, size: nil, lastModified: nil)
  }

  @Test("Datei in einem Modellordner bekommt ihren Pfad über den Elternordner")
  func resolvesPathThroughParentFolder() {
    var index = RemoteIndex(appFolderID: "01APPROOT")
    index.apply([
      folder("F1", "MaterialLink", parent: "01APPROOT"),
      file("I1", "\(id(1).uuidString).json", parent: "F1", eTag: "e1"),
    ])
    #expect(index.files.map(\.path) == ["MaterialLink/\(id(1).uuidString).json"])
  }

  @Test("Späteres Vorkommen desselben Elements gewinnt")
  func lastOccurrenceWins() {
    var index = RemoteIndex(appFolderID: "01APPROOT")
    index.apply([
      folder("F1", "MaterialLink", parent: "01APPROOT"),
      file("I1", "\(id(1).uuidString).json", parent: "F1", eTag: "e1"),
      file("I1", "\(id(1).uuidString).json", parent: "F1", eTag: "e2"),
    ])
    #expect(index.files.count == 1)
    #expect(index.files.first?.eTag == "e2")
  }

  @Test("Löschung ohne Namen (Schulkonto) entfernt die Datei")
  func deletionWithoutNameRemovesFile() {
    var index = RemoteIndex(appFolderID: "01APPROOT")
    index.apply([
      folder("F1", "MaterialLink", parent: "01APPROOT"),
      file("I1", "\(id(1).uuidString).json", parent: "F1"),
    ])
    index.apply([deleted("I1")])
    #expect(index.files.isEmpty)
  }

  @Test("library.json direkt im App-Ordner, fremde und tiefere Dateien ignoriert")
  func ignoresForeignAndDeepItems() {
    var index = RemoteIndex(appFolderID: "01APPROOT")
    index.apply([
      file("L", "library.json", parent: "01APPROOT"),
      file("X", "notes.txt", parent: "01APPROOT"),
      folder("F1", "MaterialLink", parent: "01APPROOT"),
      folder("F2", "Deeper", parent: "F1"),
      file("D", "\(id(1).uuidString).json", parent: "F2"),
      file("O", "library.json", parent: "OTHERROOT"),
      file("N", "\(id(2).uuidString).json", parent: "F1"),
    ])
    #expect(index.files.map(\.path) == ["MaterialLink/\(id(2).uuidString).json", "library.json"])
    #expect(index.file(at: "library.json")?.itemID == "L")
    #expect(index.file(at: "notes.txt") == nil)
  }

  @Test("Review Focus 3: Neu-Aufzählung nach 410 baut dieselbe Liste wieder auf")
  func resyncRebuildsWithoutForgettingETags() {
    let page = [
      folder("F1", "MaterialLink", parent: "01APPROOT"),
      file("I1", "\(id(1).uuidString).json", parent: "F1", eTag: "e7"),
    ]
    var index = RemoteIndex(appFolderID: "01APPROOT")
    index.apply(page)
    index.deltaLink = "https://graph.example.com/delta?token=1"
    let before = index.files

    index.beginResync()
    #expect(index.deltaLink == nil)
    #expect(index.files.isEmpty)
    #expect(index.appFolderID == "01APPROOT")

    index.apply(page)
    #expect(index.files == before)
    #expect(index.deltaLink == nil)
  }

  @Test("Datei erscheint vor ihrem Ordner in derselben Seite")
  func fileBeforeFolderInSamePage() {
    var index = RemoteIndex(appFolderID: "01APPROOT")
    index.apply([
      file("I1", "\(id(1).uuidString).json", parent: "F1"),
      folder("F1", "MaterialLink", parent: "01APPROOT"),
    ])
    #expect(index.files.map(\.path) == ["MaterialLink/\(id(1).uuidString).json"])
  }

  @Test("Löschung meldet den Pfad der entfernten Datei")
  func deletionReportsRemovedPath() {
    var index = RemoteIndex(appFolderID: "01APPROOT")
    index.apply([
      folder("F1", "MaterialLink", parent: "01APPROOT"),
      file("I1", "\(id(1).uuidString).json", parent: "F1"),
      file("I2", "\(id(2).uuidString).json", parent: "F1"),
    ])
    let removed = index.apply([deleted("I1"), deleted("UNKNOWN")])
    #expect(removed == ["MaterialLink/\(id(1).uuidString).json"])
    #expect(index.files.map(\.path) == ["MaterialLink/\(id(2).uuidString).json"])
  }

  @Test("Nachschlagen nach Pfad liefert dieselben Dateien wie die Liste")
  func filesByPathMatchesFiles() {
    var index = RemoteIndex(appFolderID: "01APPROOT")
    index.apply([
      file("L", "library.json", parent: "01APPROOT"),
      folder("F1", "MaterialLink", parent: "01APPROOT"),
      file("I1", "\(id(1).uuidString).json", parent: "F1"),
    ])
    let byPath = index.filesByPath
    #expect(byPath.count == index.files.count)
    for file in index.files { #expect(byPath[file.path] == file) }
  }

  @Test("Index übersteht Speichern und Laden")
  func roundTripsThroughJSON() throws {
    var index = RemoteIndex(appFolderID: "01APPROOT")
    index.apply([file("L", "library.json", parent: "01APPROOT")])
    index.deltaLink = "link"
    let data = try JSONEncoder().encode(index)
    #expect(try JSONDecoder().decode(RemoteIndex.self, from: data) == index)
  }
}

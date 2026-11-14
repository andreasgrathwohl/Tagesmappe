import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

@MainActor @Suite struct BoardStoreTests {
  let tue8b = LessonKey(date: tue17, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)

  /// Hält die Datei-Container am Leben (sonst ist der `ModelContext` ungültig).
  final class Containers { var all: [ModelContainer] = [] }
  let containers = Containers()

  func dataStore(_ url: URL) throws -> DataStore {
    let container = try ModelContainerFactory.makeOneDriveContainer(url: url)
    containers.all.append(container)
    return DataStore(modelContext: ModelContext(container))
  }

  func tempURL() -> URL {
    URL.temporaryDirectory.appending(path: UUID().uuidString + ".store")
  }

  @Test("AK-31: neue Seite kariert und leer, Seite 1 unverändert")
  func addPageKeepsFirstPage() throws {
    let store = BoardStore(store: try dataStore(tempURL()))
    let p1 = try store.addPage(for: tue8b, background: .blank)
    try store.saveDrawing(Data([1, 2, 3]), to: p1)
    try store.addPage(for: tue8b, background: .grid)
    let pages = try store.pages(for: tue8b)
    #expect(pages.count == 2)
    #expect(pages[1].backgroundRaw == "grid")
    #expect(pages[1].drawingData == nil)
    #expect(pages[0].drawingData == Data([1, 2, 3]))
  }

  @Test("AK-32: zwei Seiten überstehen den Neustart; Löschen leert die Tafel")
  func boardDrawingPersistsAndDeletes() throws {
    let url = tempURL()
    do {
      let s = BoardStore(store: try dataStore(url))
      try s.addPage(for: tue8b, background: .blank)
      try s.addPage(for: tue8b, background: .lined)
    }
    let s2 = BoardStore(store: try dataStore(url))
    #expect(try s2.pages(for: tue8b).count == 2)
    try s2.deleteBoardDrawing(for: tue8b)
    #expect(try s2.pages(for: tue8b).isEmpty)
  }

  @Test("Hintergrund wechseln behält die Zeichnung")
  func setBackgroundKeepsDrawing() throws {
    let store = BoardStore(store: try dataStore(tempURL()))
    let page = try store.addPage(for: tue8b, background: .blank)
    try store.saveDrawing(Data([9]), to: page)
    try store.setBackground(.image, imageData: Data([7]), of: page)
    let loaded = try store.pages(for: tue8b)[0]
    #expect(loaded.backgroundRaw == "image")
    #expect(loaded.backgroundImageData == Data([7]))
    #expect(loaded.drawingData == Data([9]))
  }

  @Test("AK-33: letztes Tafelbild über gespeicherte Seiten")
  func previousKeyFromStoredPages() throws {
    let store = BoardStore(store: try dataStore(tempURL()))
    let tue8a6 = LessonKey(date: tue17, schoolClass: SchoolClass("8a"), subject: Subject("Englisch"), ordinal: 6)
    let wed8b = LessonKey(date: wed18, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    try store.addPage(for: tue8b, background: .blank)
    try store.addPage(for: tue8a6, background: .blank)
    #expect(try store.previousBoardDrawingKey(before: wed8b) == tue8b)
    #expect(try store.previousBoardDrawingKey(before: tue8b) == nil)
  }

  @Test("Gleiche Position von zwei Geräten: Reihenfolge nach Anlagezeit")
  func equalPositionsSortByCreation() throws {
    let dataStore = try dataStore(tempURL())
    let store = BoardStore(store: dataStore)
    let t = Date(timeIntervalSince1970: 1_000_000)
    // Absichtlich in umgekehrter Reihenfolge eingefügt.
    let later = BoardPageRecord(lessonKeyText: tue8b.storageText, position: 1, backgroundRaw: "grid")
    later.createdAt = t.addingTimeInterval(1)
    let earlier = BoardPageRecord(lessonKeyText: tue8b.storageText, position: 1, backgroundRaw: "lined")
    earlier.createdAt = t
    dataStore.modelContext.insert(later)
    dataStore.modelContext.insert(earlier)
    try dataStore.modelContext.save()
    let pages = try store.pages(for: tue8b)
    #expect(pages.map(\.backgroundRaw) == ["lined", "grid"])
  }
}

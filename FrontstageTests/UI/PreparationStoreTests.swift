import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@MainActor @Suite struct PreparationStoreTests {
  /// Stundenplan der Fixture B (Klasse 8b Englisch, Di und Do) in einem echten Speicher.
  private func seededStore() throws -> (store: any PreparationStore, di8b: LessonKey) {
    let data = try makeStore()
    for entry in fixtureB.entries { try data.addEntry(entry) }
    let key = try #require(try data.lessons(on: tue17).first).key
    let store: any PreparationStore = data
    return (store, key)
  }

  @Test("Zuordnung als Wert: id, Schlüssel, Position und Verweis kommen aus dem Datensatz")
  func assignItemReturnsValue() throws {
    let (store, key) = try seededStore()
    let ref = reference("Unit 4.pdf")
    let item = try store.assignItem(ref, to: key, at: nil)
    #expect(try store.materialLinkItems(for: key) == [item])
    #expect(item.position == 0)
    #expect(item.lessonKey == key)
    #expect(item.reference == ref)
  }

  @Test("Unbekannte id ändert nichts und liefert nil")
  func unknownIDIsIgnored() throws {
    let (store, key) = try seededStore()
    let item = try store.assignItem(reference("A.pdf"), to: key, at: nil)
    let revision = store.revision
    #expect(try store.moveLinkToNextLesson(id: UUID()) == nil)
    try store.moveLink(id: UUID(), to: key)
    try store.removeLink(id: UUID())
    #expect(try store.materialLinkItems(for: key) == [item])
    #expect(store.revision == revision)
  }

  @Test("Zuordnung über id in die nächste Stunde schieben und löschen")
  func moveAndRemoveByID() throws {
    let (store, key) = try seededStore()
    let item = try store.assignItem(reference("A.pdf"), to: key, at: nil)
    let target = try #require(try store.moveLinkToNextLesson(id: item.id))
    #expect(try store.materialLinkItems(for: key).isEmpty)
    #expect(try store.materialLinkItems(for: target).map(\.id) == [item.id])
    try store.removeLink(id: item.id)
    #expect(try store.materialLinkItems(for: target).isEmpty)
  }

  @Test("Wochenbereich liefert Werte der Tage dazwischen")
  func itemsInRange() throws {
    let (store, key) = try seededStore()
    let item = try store.assignItem(reference("A.pdf"), to: key, at: nil)
    #expect(try store.materialLinkItems(from: tue17, through: wed18) == [item])
    #expect(try store.materialLinkItems(from: wed18, through: thu19).isEmpty)
  }

  @Test("Material ohne Stunde als Werte (FR-7)")
  func orphanedItems() throws {
    let (store, key) = try seededStore()
    let item = try store.assignItem(reference("A.pdf"), to: key, at: nil)
    #expect(try store.orphanedLinkItems(on: tue17).isEmpty)
    try store.addNonTeachingPeriod(
      NonTeachingPeriod(
        from: CalendarDay(year: 2026, month: 11, day: 16), to: CalendarDay(year: 2026, month: 11, day: 20),
        title: "Ferien"))
    #expect(try store.orphanedLinkItems(on: tue17) == [item])
  }
}

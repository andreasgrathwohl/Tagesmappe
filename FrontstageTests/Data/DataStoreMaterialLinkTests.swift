import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

@MainActor @Suite struct DataStoreMaterialLinkTests {
  /// Stundenplan der Fixture in den Speicher legen.
  private func seeded(_ timetable: Timetable) throws -> DataStore {
    let store = try makeStore()
    for entry in timetable.entries { try store.addEntry(entry) }
    return store
  }

  private func key(_ day: CalendarDay, _ schoolClass: String) -> LessonKey {
    LessonKey(date: day, schoolClass: SchoolClass(schoolClass), subject: Subject("Englisch"), ordinal: 1)
  }

  /// Fixture B: Di 17.11. und Do 19.11. der Klasse 8b.
  private func fixtureBStore() throws -> (store: DataStore, di8b: LessonKey) {
    let store = try seeded(fixtureB)
    return (store, try #require(try store.lessons(on: tue17).first).key)
  }

  /// Fixture A: Di 8a (2. Stunde), Mi 8b (3. Stunde).
  private func fixtureAStore() throws -> (store: DataStore, di8a: LessonKey, mi8b: LessonKey) {
    let store = try seeded(fixtureA)
    let di8a = try #require(try store.lessons(on: tue17).first).key
    let mi8b = try #require(try store.lessons(on: wed18).first).key
    return (store, di8a, mi8b)
  }

  private func names(_ store: DataStore, _ key: LessonKey) throws -> [String] {
    try store.links(for: key).map(\.reference.displayName)
  }

  @Test("AK-6: Lösung an Position 1 ziehen")
  func moveSolutionToFirstPosition() throws {
    let (store, di8b) = try fixtureBStore()
    for name in ["Präsentation", "Arbeitsblatt", "Lösung"] { try store.assign(reference(name), to: di8b) }
    try store.moveLinks(in: di8b, fromOffsets: [2], toOffset: 0)
    #expect(try names(store, di8b) == ["Lösung", "Präsentation", "Arbeitsblatt"])
    #expect(try store.links(for: di8b).map(\.position) == [0, 1, 2])
  }

  @Test("AK-6: Präsentation ans Ende ziehen (toOffset zählt vor dem Entfernen)")
  func moveFirstToEnd() throws {
    let (store, di8b) = try fixtureBStore()
    for name in ["Präsentation", "Arbeitsblatt", "Lösung"] { try store.assign(reference(name), to: di8b) }
    try store.moveLinks(in: di8b, fromOffsets: [0], toOffset: 3)
    #expect(try names(store, di8b) == ["Arbeitsblatt", "Lösung", "Präsentation"])
  }

  @Test("Gleiche Positionen nach dem Abgleich: Anlagezeit entscheidet, Verschieben nummeriert neu")
  func equalPositionsSortByCreationAndRenumber() throws {
    let (store, di8b) = try fixtureBStore()
    let second = MaterialLinkRecord()
    let first = MaterialLinkRecord()
    for (record, name, time) in [(second, "Zweite", 2_000.0), (first, "Erste", 1_000.0)] {
      store.modelContext.insert(record)
      record.setLessonKey(di8b)
      record.setReference(reference(name))
      record.position = 0
      record.createdAt = Date(timeIntervalSince1970: time)
    }
    try store.saveAndBump()
    #expect(try names(store, di8b) == ["Erste", "Zweite"])
    try store.moveLinks(in: di8b, fromOffsets: [1], toOffset: 0)
    #expect(try names(store, di8b) == ["Zweite", "Erste"])
    #expect(try store.links(for: di8b).map(\.position) == [0, 1])
  }

  @Test("Zuordnen an Position einfügen")
  func assignAtIndexInsertsAndRenumbers() throws {
    let (store, di8b) = try fixtureBStore()
    try store.assign(reference("Präsentation"), to: di8b)
    try store.assign(reference("Arbeitsblatt"), to: di8b)
    try store.assign(reference("Lösung"), to: di8b, at: 0)
    #expect(try names(store, di8b) == ["Lösung", "Präsentation", "Arbeitsblatt"])
    #expect(try store.links(for: di8b).map(\.position) == [0, 1, 2])
  }

  @Test("Dieselbe Datei zweimal zuordnen ergibt eine Zuordnung")
  func assignSameFileTwiceKeepsOne() throws {
    let (store, di8b) = try fixtureBStore()
    let first = try store.assign(reference("Vokabeln.pdf"), to: di8b)
    let second = try store.assign(reference("Vokabeln.pdf"), to: di8b)
    #expect(first.id == second.id)
    #expect(try store.links(for: di8b).count == 1)
  }

  @Test("Dieselbe Datei nach zurückgeschriebener OneDrive-Kennung erneut zuordnen ergibt eine Zuordnung")
  func assignSameLocationAfterOneDriveIDKeepsOne() throws {
    let (store, di8b) = try fixtureBStore()
    var withID = reference("Vokabeln Unit 4.pptx")
    withID.oneDriveItemID = "01ABC"
    withID.oneDriveDriveID = "b!x"
    let first = try store.assign(withID, to: di8b)
    // Aus der Dateiauswahl kommt derselbe Ort ohne Kennung.
    let second = try store.assign(reference("Vokabeln Unit 4.pptx"), to: di8b)
    #expect(first.id == second.id)
    #expect(try store.links(for: di8b).count == 1)
  }

  @Test("AK-7: Für 8b übernehmen in die gewählte Mi 3. Stunde – dieselben 2 Materialien")
  func copyLinksToChosenLesson() throws {
    let (store, di8a, mi8b) = try fixtureAStore()
    try store.assign(reference("Präsentation"), to: di8a)
    try store.assign(reference("Arbeitsblatt"), to: di8a)
    let choices = try store.candidateLessons(for: SchoolClass("8b"), from: tue17)
    #expect(choices.first?.key == mi8b)  // Lehrkraft wählt aus der Liste (Teilplan 04)
    #expect(try store.copyMaterialLinks(from: di8a, to: mi8b) == 2)
    #expect(
      try store.links(for: mi8b).map(\.reference) == [reference("Präsentation"), reference("Arbeitsblatt")])
    #expect(try store.links(for: di8a).count == 2)
  }

  @Test("Klassen zur Wahl: alle außer der eigenen")
  func selectableClassesFromStore() throws {
    let (store, _, _) = try fixtureAStore()
    #expect(
      try store.selectableClasses(excluding: SchoolClass("8a")) == [SchoolClass("8b"), SchoolClass("9c")])
  }

  @Test("Review Focus 5: Datei, die das Ziel schon hat, wird nicht doppelt übernommen")
  func copyLinksSkipsFilesAlreadyInTarget() throws {
    let (store, di8a, mi8b) = try fixtureAStore()
    try store.assign(reference("Präsentation"), to: di8a)
    try store.assign(reference("Arbeitsblatt"), to: di8a)
    try store.assign(reference("Präsentation"), to: mi8b)
    #expect(try store.copyMaterialLinks(from: di8a, to: mi8b) == 1)
    #expect(try store.links(for: mi8b).count == 2)
  }

  @Test("Neu verknüpfen ersetzt den Ort an allen Zuordnungen (ADR-0003)")
  func replaceReferencesAtLocation() throws {
    let (store, di8a, mi8b) = try fixtureAStore()
    let vocabulary = try store.assign(reference("Vokabeln.pdf"), to: di8a)
    try store.assign(reference("Lösung"), to: di8a)
    try store.assign(reference("Vokabeln.pdf"), to: mi8b)
    try store.savePenNote(
      for: vocabulary, pageIndex: 0, drawingData: Data([1]), pageWidth: 595, pageHeight: 842)
    let renamed = MaterialReference(
      folderGrantName: "Unterricht", relativePath: "Englisch/Vokabeln neu.pdf", displayName: "Vokabeln neu",
      fileKind: .pdf)
    #expect(try store.replaceReferences(atLocation: reference("Vokabeln.pdf").locationKey, with: renamed) == 2)
    #expect(try names(store, di8a) == ["Vokabeln neu", "Lösung"])
    #expect(try store.links(for: di8a).first?.penNotes?.count == 1)
  }

  @Test("Gespeicherte Freigabe-Namen und Verweise für das Bereithalten")
  func folderGrantNamesAndLinkedReferences() throws {
    let (store, di8a, mi8b) = try fixtureAStore()
    try store.assign(reference("Vokabeln.pdf"), to: di8a)
    try store.assign(reference("Lösung"), to: mi8b)
    #expect(try store.folderGrantNames() == ["Unterricht"])
    #expect(try store.linkedReferences(for: [di8a, mi8b]).map(\.key) == [di8a, mi8b])
  }

  @Test("Woche im Vorbereiten: Zuordnungen von … bis")
  func linksInDayRange() throws {
    let (store, di8a, mi8b) = try fixtureAStore()
    try store.assign(reference("Vokabeln.pdf"), to: di8a)
    try store.assign(reference("Lösung"), to: mi8b)
    #expect(try store.links(from: tue17, through: tue17).count == 1)
    #expect(try store.links(from: tue17, through: wed18).count == 2)
    #expect(try store.links(from: thu19, through: thu19).isEmpty)
  }

  @Test("AK-8: X in die nächste Stunde – steht am Do, nicht mehr am Di")
  func moveLinkToNextLessonMovesToThursday() throws {
    let (store, di8b) = try fixtureBStore()
    let x = try store.assign(reference("Vokabeln.pdf"), to: di8b)
    let target = try store.moveLinkToNextLesson(x)
    #expect(target?.date == thu19)
    #expect(try store.links(for: di8b).isEmpty)
    #expect(try store.links(for: try #require(target)).map(\.id) == [x.id])
  }

  @Test("Review Focus 4: ohne nächste Stunde bleibt die Zuordnung, wo sie ist")
  func moveToNextLessonWithoutNextLessonKeepsLink() throws {
    let store = try makeStore()
    try store.addEntry(fixtureB.entries[0])  // nur Di 8b
    // Alle Dienstage vom 18.11. bis 15.12. unterrichtsfrei (17.11. bleibt Unterricht).
    try store.addNonTeachingPeriod(
      NonTeachingPeriod(
        from: CalendarDay(year: 2026, month: 11, day: 18), to: CalendarDay(year: 2026, month: 12, day: 15),
        title: "Pause"))
    let di8b = try #require(try store.lessons(on: tue17).first).key
    let link = try store.assign(reference("Vokabeln.pdf"), to: di8b)
    #expect(try store.moveLinkToNextLesson(link) == nil)
    #expect(try store.links(for: di8b).count == 1)
  }

  @Test("AK-15: Ausfall markieren, Material weiterreichen – Material am Do")
  func cancelAndPassOnMovesAllLinks() throws {
    let (store, di8b) = try fixtureBStore()
    try store.assign(reference("Präsentation"), to: di8b)
    try store.assign(reference("Arbeitsblatt"), to: di8b)
    try store.markCancelled(di8b)
    let target = try #require(try store.moveAllLinksToNextLesson(from: di8b))
    #expect(target.date == thu19)
    #expect(try names(store, target) == ["Präsentation", "Arbeitsblatt"])
    #expect(try store.lessons(on: tue17).first?.isCancelled == true)
  }

  @Test("AK-22 (Daten): Übernehmen ohne Notiz, Schieben mit Notiz")
  func penNotesFollowMoveButNotCopy() throws {
    let (store, di8a, mi8b) = try fixtureAStore()
    let pdf = try store.assign(reference("Vokabeln.pdf"), to: di8a)
    try store.savePenNote(
      for: pdf, pageIndex: 0, drawingData: Data([0x01, 0x02]), pageWidth: 595, pageHeight: 842)
    try store.copyMaterialLinks(from: di8a, to: mi8b)
    #expect(try store.links(for: mi8b).first?.penNotes?.isEmpty == true)
    // Fixture A: Do 1. Stunde 8a ist die nächste Stunde von Di 8a.
    let thursday = try #require(try store.moveLinkToNextLesson(pdf))
    #expect(thursday.date == thu19)
    let moved = try #require(try store.links(for: thursday).first)
    #expect(try store.penNote(for: moved, pageIndex: 0)?.drawingData == Data([0x01, 0x02]))
    #expect(moved.reference == reference("Vokabeln.pdf"))
  }

  @Test("AK-14 (Daten): Material am Ferientag bleibt als „ohne Stunde“ erhalten")
  func linkOnNonTeachingDayIsOrphaned() throws {
    let (store, di8b) = try fixtureBStore()
    let link = try store.assign(reference("Vokabeln.pdf"), to: di8b)
    #expect(try store.orphanedLinks(on: tue17).isEmpty)
    try store.addNonTeachingPeriod(
      NonTeachingPeriod(
        from: CalendarDay(year: 2026, month: 11, day: 16), to: CalendarDay(year: 2026, month: 11, day: 20),
        title: "Ferien"))
    #expect(try store.orphanedLinks(on: tue17).count == 1)
    let thu26 = CalendarDay(year: 2026, month: 11, day: 26)
    let target = try #require(try store.lessons(on: thu26).first).key
    try store.moveLink(link, to: target)
    #expect(try store.orphanedLinks(on: tue17).isEmpty)
    #expect(try store.links(for: target).count == 1)
  }

  @Test("Ausgefallene Stunde zählt nicht als „ohne Stunde“")
  func cancelledLessonIsNotOrphaned() throws {
    let (store, di8b) = try fixtureBStore()
    try store.assign(reference("Vokabeln.pdf"), to: di8b)
    try store.markCancelled(di8b)
    #expect(try store.orphanedLinks(on: tue17).isEmpty)
  }

  @Test("Zuordnung löschen löscht ihre Stiftnotizen")
  func removeLinkDeletesPenNotes() throws {
    let (store, di8b) = try fixtureBStore()
    let link = try store.assign(reference("Vokabeln.pdf"), to: di8b)
    try store.savePenNote(for: link, pageIndex: 0, drawingData: Data([1]), pageWidth: 595, pageHeight: 842)
    try store.removeLink(link)
    #expect(try store.links(for: di8b).isEmpty)
    #expect(try store.modelContext.fetch(FetchDescriptor<PenNoteRecord>()).isEmpty)
  }

  @Test("Stiftnotiz überschreiben setzt updatedAt neu und legt keine zweite an")
  func savePenNoteOverwritesSamePage() throws {
    let (store, di8b) = try fixtureBStore()
    let link = try store.assign(reference("Vokabeln.pdf"), to: di8b)
    try store.savePenNote(for: link, pageIndex: 0, drawingData: Data([1]), pageWidth: 595, pageHeight: 842)
    let note = try #require(try store.penNote(for: link, pageIndex: 0))
    note.updatedAt = Date(timeIntervalSince1970: 0)
    try store.savePenNote(for: link, pageIndex: 0, drawingData: Data([2]), pageWidth: 595, pageHeight: 842)
    #expect(try store.penNotes(for: link).count == 1)
    let after = try #require(try store.penNote(for: link, pageIndex: 0))
    #expect(after.drawingData == Data([2]))
    #expect(after.updatedAt > Date(timeIntervalSince1970: 1))
  }

  @Test("Gespeicherte Seitengröße bleibt beim Weiterschreiben auf geänderter Seite erhalten (Area anzeige)")
  func savePenNoteKeepsFirstPageSize() throws {
    let (store, di8b) = try fixtureBStore()
    let link = try store.assign(reference("Vokabeln.pdf"), to: di8b)
    try store.savePenNote(for: link, pageIndex: 0, drawingData: Data([1]), pageWidth: 595, pageHeight: 842)
    try store.savePenNote(for: link, pageIndex: 0, drawingData: Data([2]), pageWidth: 842, pageHeight: 595)
    let note = try #require(try store.penNote(for: link, pageIndex: 0))
    #expect(note.pageWidth == 595)
    #expect(note.pageHeight == 842)
    #expect(try store.penNotes(for: link).count == 1)
  }
}

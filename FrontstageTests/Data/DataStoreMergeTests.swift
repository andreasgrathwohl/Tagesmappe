import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

@MainActor @Suite struct DataStoreMergeTests {
  private let store: DataStore
  private let t1 = Date(timeIntervalSince1970: 1_000)
  private let t2 = Date(timeIntervalSince1970: 2_000)
  private let t3 = Date(timeIntervalSince1970: 3_000)
  private let di8a = LessonKey(
    date: tue17, schoolClass: SchoolClass("8a"), subject: Subject("Englisch"), ordinal: 1)

  init() throws {
    store = try makeStore()
  }

  private var context: ModelContext { store.modelContext }

  /// Legt eine Zuordnung der erfundenen Datei „Vokabeln.pdf“ zur Stunde Di 8a an.
  private func insertLink(createdAt: Date) -> MaterialLinkRecord {
    let link = MaterialLinkRecord()
    context.insert(link)
    link.createdAt = createdAt
    link.setLessonKey(di8a)
    link.setReference(reference("Vokabeln.pdf"))
    return link
  }

  private func insertNote(
    on link: MaterialLinkRecord, page: Int, drawing: Data?, createdAt: Date, updatedAt: Date
  ) {
    let note = PenNoteRecord(materialLink: link, pageIndex: page)
    context.insert(note)
    note.drawingData = drawing
    note.createdAt = createdAt
    note.updatedAt = updatedAt
  }

  private func insertTimetable(createdAt: Date) -> TimetableRecord {
    let timetable = TimetableRecord(isActive: true)
    context.insert(timetable)
    timetable.createdAt = createdAt
    return timetable
  }

  private func fetchLinks() throws -> [MaterialLinkRecord] {
    try context.fetch(FetchDescriptor<MaterialLinkRecord>(sortBy: [SortDescriptor(\.createdAt)]))
  }

  @Test("Review Focus 2: Stiftnotizen der aufgegebenen Zuordnung überleben das Löschen")
  func mergeKeepsPenNotesOfDroppedLink() throws {
    _ = insertLink(createdAt: t1)
    let younger = insertLink(createdAt: t2)
    insertNote(on: younger, page: 1, drawing: Data([7]), createdAt: t2, updatedAt: t2)
    try context.save()

    try store.mergeDuplicates()

    let links = try fetchLinks()
    #expect(links.count == 1)
    #expect(links[0].createdAt == t1)
    #expect(links[0].penNotes?.map(\.pageIndex) == [1])
    #expect(try context.fetchCount(FetchDescriptor<PenNoteRecord>()) == 1)
  }

  @Test("Gleiche Seite: Zeichnung der zuletzt geänderten Notiz bleibt")
  func mergeTakesLatestDrawingForSamePage() throws {
    let older = insertLink(createdAt: t1)
    let younger = insertLink(createdAt: t2)
    insertNote(on: older, page: 0, drawing: Data([1]), createdAt: t1, updatedAt: t1)
    insertNote(on: younger, page: 0, drawing: Data([2]), createdAt: t2, updatedAt: t3)
    try context.save()

    try store.mergeDuplicates()

    let notes = try context.fetch(FetchDescriptor<PenNoteRecord>())
    #expect(notes.count == 1)
    #expect(notes[0].drawingData == Data([2]))
    #expect(notes[0].updatedAt == t3)
  }

  @Test("Review Focus 1: Einträge wandern vor dem Löschen des Stundenplans")
  func mergeMovesEntriesBeforeDeletingTimetable() throws {
    _ = insertTimetable(createdAt: t1)
    let younger = insertTimetable(createdAt: t2)
    let thursday = TimetableEntry(
      weekday: .thursday, period: 3, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"))
    store.insertEntryRecord(thursday, origin: .manual, into: younger)
    try context.save()

    try store.mergeDuplicates()

    #expect(
      try store.timetable()?.entries.contains { $0.weekday == .thursday && $0.period == 3 } == true)
    #expect(try context.fetchCount(FetchDescriptor<TimetableRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<TimetableEntryRecord>()) == 1)
  }

  @Test("Doppelte Stundenangaben: je Feld der jüngste Stand")
  func mergeLessonInfoFields() throws {
    let older = LessonInfoRecord(lessonKeyText: di8a.storageText)
    context.insert(older)
    older.createdAt = t1
    older.topic = "Alt"
    older.topicUpdatedAt = t1
    older.toPrepare = "Vokabeln lernen"
    older.toPrepareUpdatedAt = t3
    let younger = LessonInfoRecord(lessonKeyText: di8a.storageText)
    context.insert(younger)
    younger.createdAt = t2
    younger.topic = "Neu"
    younger.topicUpdatedAt = t3
    younger.toPrepare = "Anderes"
    younger.toPrepareUpdatedAt = t2
    try context.save()

    try store.mergeDuplicates()

    let infos = try context.fetch(FetchDescriptor<LessonInfoRecord>())
    #expect(infos.count == 1)
    #expect(infos[0].topic == "Neu")
    #expect(infos[0].topicUpdatedAt == t3)
    #expect(infos[0].toPrepare == "Vokabeln lernen")
    #expect(infos[0].toPrepareUpdatedAt == t3)
  }

  @Test("Zweiter Lauf ändert nichts")
  func mergeIsIdempotent() throws {
    _ = insertLink(createdAt: t1)
    _ = insertLink(createdAt: t2)
    try context.save()

    #expect(try store.mergeDuplicates().isEmpty == false)
    let revision = store.revision
    #expect(try store.mergeDuplicates().isEmpty == true)
    #expect(store.revision == revision)
  }
}

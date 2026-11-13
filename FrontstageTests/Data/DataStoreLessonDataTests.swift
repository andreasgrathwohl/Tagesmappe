import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

@MainActor @Suite struct DataStoreLessonDataTests {
  let store: DataStore
  let di8b: LessonKey
  let do8b: LessonKey

  var modelContext: ModelContext { store.modelContext }

  init() throws {
    store = try makeStore()
    di8b = LessonKey(date: tue17, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    do8b = LessonKey(date: thu19, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
  }

  @Test("AK-25 (Daten): Thema und Bereitlegen eintragen, dann Bereitlegen leeren")
  func lessonInfoClearPrepareKeepsTopic() throws {
    try store.setLessonInfo(LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "Buch, Heft"), for: di8b)
    #expect(try store.lessonInfo(for: di8b) == LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "Buch, Heft"))
    try store.setLessonInfo(LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: ""), for: di8b)
    let info = try store.lessonInfo(for: di8b)
    #expect(info.topic == "Unit 4 – Wortschatz")
    #expect(info.toPrepare == nil)
    #expect(try modelContext.fetchCount(FetchDescriptor<LessonInfoRecord>()) == 1)
  }

  @Test("Stundenangaben gelten nur für ihre Unterrichtsstunde")
  func lessonInfoIsPerLesson() throws {
    try store.setLessonInfo(LessonInfo(topic: "Unit 4"), for: di8b)
    #expect(try store.lessonInfo(for: do8b).isEmpty)
  }

  @Test("Mehrere Datensätze einer Stunde: der älteste wird beschrieben")
  func lessonInfoWritesOldestRecord() throws {
    let older = LessonInfoRecord(lessonKeyText: di8b.storageText)
    older.createdAt = Date(timeIntervalSince1970: 1000)
    let newer = LessonInfoRecord(lessonKeyText: di8b.storageText)
    newer.createdAt = Date(timeIntervalSince1970: 2000)
    modelContext.insert(older)
    modelContext.insert(newer)
    try store.setLessonInfo(LessonInfo(homework: "S. 12"), for: di8b)
    #expect(older.homework == "S. 12")
    #expect(newer.homework == nil)
    #expect(older.homeworkUpdatedAt != nil)
  }

  @Test("AK-31/AK-32 (Daten): zwei Seiten bleiben, Löschen leert das Tafelbild")
  func boardPagesPersistAndDelete() throws {
    let p1 = try store.addBoardPage(for: di8b, background: .blank)
    try store.saveBoardPageDrawing(p1, drawingData: Data([0x0A]))
    try store.addBoardPage(for: di8b, background: .grid)
    #expect(try store.boardPages(for: di8b).map(\.background) == [.blank, .grid])
    #expect(try store.boardPages(for: di8b).map(\.backgroundRaw) == ["blank", "grid"])
    #expect(try store.boardPages(for: di8b).first?.drawingData == Data([0x0A]))
    #expect(try store.lessonKeysWithBoardPages() == [di8b])
    try store.deleteBoardDrawing(for: di8b)
    #expect(try store.boardPages(for: di8b).isEmpty)
  }

  @Test("Eine gelöschte Seite lässt Lücken; neue Seiten kommen ans Ende")
  func deleteKeepsPositionsAndAppends() throws {
    let p0 = try store.addBoardPage(for: di8b, background: .blank)
    try store.addBoardPage(for: di8b, background: .lined)
    try store.deleteBoardPage(p0)
    let third = try store.addBoardPage(for: di8b, background: .grid)
    #expect(try store.boardPages(for: di8b).map(\.position) == [1, 2])
    #expect(third.position == 2)
  }

  @Test("Hintergrund ändern setzt Bild und Änderungszeit")
  func setBackgroundUpdatesPage() throws {
    let page = try store.addBoardPage(for: di8b, background: .blank)
    let before = page.updatedAt
    try store.setBoardPageBackground(page, background: .image, imageData: Data([0x01]))
    #expect(page.background == .image)
    #expect(page.backgroundImageData == Data([0x01]))
    #expect(page.updatedAt >= before)
  }
}

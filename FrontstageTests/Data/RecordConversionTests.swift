import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

/// Jedes `@Model`-Objekt wird vor dem ersten Zugriff in einen eigenen In-Memory-Kontext eingefügt.
/// Ohne Kontext hinge der Test davon ab, dass der Test-Host beim Start schon einen Container mit
/// demselben Schema geladen hat; sonst bricht SwiftData mit „failed to find a currently active
/// container“ ab.
@MainActor @Suite struct RecordConversionTests {
  private let container: ModelContainer  // festhalten, solange der Kontext lebt
  private let context: ModelContext

  init() throws {
    container = try ModelContainerFactory.makeInMemoryContainer()
    context = ModelContext(container)
  }

  /// Fügt den Datensatz in den Test-Kontext ein und gibt ihn zurück.
  @discardableResult
  private func inserted<Record: PersistentModel>(_ record: Record) -> Record {
    context.insert(record)
    return record
  }

  @Test("Stundenplan hin und zurück, mit A/B-Wochen und Zeitraster")
  func timetableRoundTrip() {
    let entry = TimetableEntry(
      weekVariant: .a, weekday: .tuesday, period: 2, schoolClass: SchoolClass("8b"),
      subject: Subject("Englisch"))
    let record = inserted(
      TimetableRecord(
        name: "Beispielplan", weekVariantCount: 2,
        referenceWeekAText: CalendarDay(year: 2026, month: 11, day: 16).storageText))
    record.setBellSchedule(
      BellSchedule(periods: [
        2: TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20)
      ]))
    // Erst einfügen, dann die Beziehung setzen (wie `DataStore.insertEntryRecord`).
    let entryRecord = inserted(TimetableEntryRecord())
    entryRecord.apply(entry, origin: .manual)
    record.entries = [entryRecord]

    let back = record.makeTimetable()
    #expect(back.weekVariantCount == 2)
    #expect(back.referenceWeekA == CalendarDay(year: 2026, month: 11, day: 16))
    #expect(back.bellSchedule.periods[2] == TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20))
    #expect(back.entries == [entry])
  }

  @Test("Fehlende Bezugswoche und unlesbares Zeitraster ergeben Rückfallwerte")
  func timetableFallbacks() {
    let record = inserted(TimetableRecord())
    record.bellScheduleData = Data("kein json".utf8)
    let back = record.makeTimetable()
    #expect(back.referenceWeekA == CalendarDay(record.createdAt, calendar: .current))
    #expect(back.bellSchedule.periods.isEmpty)
  }

  @Test("Klasse wird normalisiert gespeichert, Fach mit Anzeigename")
  func entryStoresNormalizedClassAndSubjectDisplay() {
    let record = inserted(TimetableEntryRecord())
    record.apply(
      TimetableEntry(weekday: .monday, period: 1, schoolClass: SchoolClass("08B"), subject: Subject("Englisch")),
      origin: .source)
    #expect(record.schoolClassText == "8b")
    #expect(record.subjectText == "Englisch")
    #expect(record.origin == .source)
    #expect(record.makeEntry()?.schoolClass == SchoolClass("8b"))
  }

  @Test("Ausfall und Vertretungsstunde hin und zurück, mit Herkunft")
  func scheduleChangeRoundTrip() {
    let key = LessonKey(date: tue17, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    let cancellation = ScheduleChange.cancellation(key, .source)
    let substitute = ScheduleChange.substituteLesson(
      date: wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"), .manual)

    let first = inserted(ScheduleChangeRecord())
    first.apply(cancellation)
    #expect(first.makeChange() == cancellation)

    let second = inserted(ScheduleChangeRecord())
    second.apply(substitute)
    #expect(second.makeChange() == substitute)
    #expect(second.snapshot()?.change == substitute)
  }

  @Test("Unterrichtsfreie Zeit hin und zurück")
  func nonTeachingPeriodRoundTrip() {
    let period = NonTeachingPeriod(from: tue17, to: thu19, title: "Studientage")
    let record = inserted(NonTeachingPeriodRecord())
    record.apply(period)
    #expect(record.makePeriod() == period)
  }

  @Test("Zuordnung trägt Schlüssel und Tag als Text")
  func linkStoresLessonKeyAndDayText() {
    let key = LessonKey(date: tue17, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    let link = inserted(MaterialLinkRecord())
    link.setLessonKey(key)
    #expect(link.dayText == "2026-11-17")
    #expect(link.lessonKey == key)
  }

  @Test("Verweis hin und zurück über die Felder der Zuordnung")
  func linkReferenceRoundTrip() {
    let ref = MaterialReference(
      folderGrantName: "Unterricht", relativePath: "Englisch/Folien.pptx", displayName: "Folien.pptx",
      fileKind: .presentation, oneDriveItemID: "01ABC", oneDriveDriveID: "b!x")
    let link = inserted(MaterialLinkRecord())
    link.setReference(ref)
    #expect(link.reference == ref)
    #expect(link.snapshot().fileIdentity == "onedrive:01ABC")

    link.fileKindRaw = "x"
    #expect(link.reference.fileKind == .other)
  }

  @Test("Tafelhintergrund: unbekannter Rohwert ergibt leer")
  func boardBackgroundFallsBackToBlank() {
    let page = inserted(BoardPageRecord())
    page.background = .grid
    #expect(page.backgroundRaw == "grid")
    page.backgroundRaw = "x"
    #expect(page.background == .blank)
  }

  @Test("Stiftnotiz-Abbild trägt die Zuordnung")
  func penNoteSnapshotCarriesLinkID() {
    let link = inserted(MaterialLinkRecord())
    let note = inserted(PenNoteRecord(materialLink: nil, pageIndex: 3))
    note.materialLink = link
    let snapshot = note.snapshot()
    #expect(snapshot.linkID == link.id)
    #expect(snapshot.pageIndex == 3)
  }

  @Test("Stundenangaben: nur geänderte Felder bekommen einen neuen Zeitstempel")
  func lessonInfoApplyStampsOnlyChangedFields() {
    let t1 = Date(timeIntervalSince1970: 1_000)
    let t2 = Date(timeIntervalSince1970: 2_000)
    let record = inserted(LessonInfoRecord())
    record.apply(LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: "Buch, Heft"), now: t1)
    record.apply(LessonInfo(topic: "Unit 4 – Wortschatz", toPrepare: nil), now: t2)
    #expect(record.topicUpdatedAt == t1)
    #expect(record.toPrepareUpdatedAt == t2)
    #expect(record.homeworkUpdatedAt == nil)
    #expect(record.updatedAt == t2)
    #expect(record.toPrepare == nil)
    #expect(record.snapshot().fieldUpdatedAt == [.topic: t1, .toPrepare: t2])
  }

  @Test("Ungültige Rohwerte ergeben nil statt Absturz")
  func invalidRawValuesYieldNil() {
    #expect(inserted(TimetableEntryRecord(weekdayRaw: 9)).makeEntry() == nil)
    #expect(inserted(TimetableEntryRecord(weekVariantRaw: "z")).makeEntry() == nil)
    #expect(inserted(TimetableEntryRecord(originRaw: "x")).origin == .manual)
    #expect(inserted(ScheduleChangeRecord(kindRaw: "x")).makeChange() == nil)
    #expect(inserted(NonTeachingPeriodRecord(fromText: "", toText: "2026-11-17")).makePeriod() == nil)
    #expect(inserted(MaterialLinkRecord(lessonKeyText: "")).lessonKey == nil)
  }
}

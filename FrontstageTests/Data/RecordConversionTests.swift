import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

@Suite struct RecordConversionTests {
  @Test("Stundenplan hin und zurück, mit A/B-Wochen und Zeitraster")
  func timetableRoundTrip() {
    let entry = TimetableEntry(
      weekVariant: .a, weekday: .tuesday, period: 2, schoolClass: SchoolClass("8b"),
      subject: Subject("Englisch"))
    let record = TimetableRecord(
      name: "Beispielplan", weekVariantCount: 2,
      referenceWeekAText: CalendarDay(year: 2026, month: 11, day: 16).storageText)
    record.setBellSchedule(
      BellSchedule(periods: [
        2: TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20)
      ]))
    let entryRecord = TimetableEntryRecord(timetable: record)
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
    let record = TimetableRecord()
    record.bellScheduleData = Data("kein json".utf8)
    let back = record.makeTimetable()
    #expect(back.referenceWeekA == CalendarDay(record.createdAt, calendar: .current))
    #expect(back.bellSchedule.periods.isEmpty)
  }

  @Test("Klasse wird normalisiert gespeichert, Fach mit Anzeigename")
  func entryStoresNormalizedClassAndSubjectDisplay() {
    let record = TimetableEntryRecord()
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

    let first = ScheduleChangeRecord()
    first.apply(cancellation)
    #expect(first.makeChange() == cancellation)

    let second = ScheduleChangeRecord()
    second.apply(substitute)
    #expect(second.makeChange() == substitute)
    #expect(second.snapshot()?.change == substitute)
  }

  @Test("Unterrichtsfreie Zeit hin und zurück")
  func nonTeachingPeriodRoundTrip() {
    let period = NonTeachingPeriod(from: tue17, to: thu19, title: "Studientage")
    let record = NonTeachingPeriodRecord()
    record.apply(period)
    #expect(record.makePeriod() == period)
  }

  @Test("Zuordnung trägt Schlüssel und Tag als Text")
  func linkStoresLessonKeyAndDayText() {
    let key = LessonKey(date: tue17, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)
    let link = MaterialLinkRecord()
    link.setLessonKey(key)
    #expect(link.dayText == "2026-11-17")
    #expect(link.lessonKey == key)
  }

  @Test("Verweis hin und zurück über die Felder der Zuordnung")
  func linkReferenceRoundTrip() {
    let ref = MaterialReference(
      folderGrantName: "Unterricht", relativePath: "Englisch/Folien.pptx", displayName: "Folien.pptx",
      fileKind: .presentation, oneDriveItemID: "01ABC", oneDriveDriveID: "b!x")
    let link = MaterialLinkRecord()
    link.setReference(ref)
    #expect(link.reference == ref)
    #expect(link.snapshot().fileIdentity == "onedrive:01ABC")

    link.fileKindRaw = "x"
    #expect(link.reference.fileKind == .other)
  }

  @Test("Tafelhintergrund: unbekannter Rohwert ergibt leer")
  func boardBackgroundFallsBackToBlank() {
    let page = BoardPageRecord()
    page.background = .grid
    #expect(page.backgroundRaw == "grid")
    page.backgroundRaw = "x"
    #expect(page.background == .blank)
  }

  @Test("Stiftnotiz-Abbild trägt die Zuordnung")
  func penNoteSnapshotCarriesLinkID() {
    let link = MaterialLinkRecord()
    let note = PenNoteRecord(materialLink: link, pageIndex: 3)
    let snapshot = note.snapshot()
    #expect(snapshot.linkID == link.id)
    #expect(snapshot.pageIndex == 3)
  }

  @Test("Stundenangaben: nur geänderte Felder bekommen einen neuen Zeitstempel")
  func lessonInfoApplyStampsOnlyChangedFields() {
    let t1 = Date(timeIntervalSince1970: 1_000)
    let t2 = Date(timeIntervalSince1970: 2_000)
    let record = LessonInfoRecord()
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
    #expect(TimetableEntryRecord(weekdayRaw: 9).makeEntry() == nil)
    #expect(TimetableEntryRecord(weekVariantRaw: "z").makeEntry() == nil)
    #expect(TimetableEntryRecord(originRaw: "x").origin == .manual)
    #expect(ScheduleChangeRecord(kindRaw: "x").makeChange() == nil)
    #expect(NonTeachingPeriodRecord(fromText: "", toText: "2026-11-17").makePeriod() == nil)
    #expect(MaterialLinkRecord(lessonKeyText: "").lessonKey == nil)
  }
}

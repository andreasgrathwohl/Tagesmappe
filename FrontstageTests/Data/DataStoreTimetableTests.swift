import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

/// Einträge der Fixture B (Di 2. und Do 3. Stunde, 8b Englisch) in den Speicher legen.
@MainActor private func seedFixtureB(_ store: DataStore) throws {
  for entry in fixtureB.entries { try store.addEntry(entry) }
}

private let di8b = LessonKey(
  date: tue17, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)

@MainActor @Suite struct DataStoreTimetableTests {
  @Test("AK-1 (Daten): Eintrag Di 2. Stunde 8b Englisch erscheint an jedem Dienstag")
  func addedEntryAppearsEveryTuesday() throws {
    let store = try makeStore()
    try store.addEntry(
      TimetableEntry(
        weekVariant: nil, weekday: .tuesday, period: 2, schoolClass: SchoolClass("8b"),
        subject: Subject("Englisch")))
    #expect(try store.lessons(on: tue17).map(\.key.schoolClass) == [SchoolClass("8b")])
    #expect(try store.lessons(on: CalendarDay(year: 2026, month: 11, day: 24)).count == 1)
  }

  @Test("Doppelter Eintrag wird nicht noch einmal gespeichert")
  func duplicateEntryIsIgnored() throws {
    let store = try makeStore()
    let entry = fixtureB.entries[0]
    try store.addEntry(entry)
    let revision = store.revision
    try store.addEntry(entry)
    #expect(store.revision == revision)
    #expect(try store.timetable()?.entries.count == 1)
  }

  @Test("AK-15 (Daten): Di 8b als Ausfall markiert, Stundenplan-Eintrag bleibt")
  func markCancelledFlagsLessonAndKeepsEntry() throws {
    let store = try makeStore()
    try seedFixtureB(store)
    try store.markCancelled(di8b)
    try store.markCancelled(di8b)  // idempotent
    let tue = try store.lessons(on: tue17)
    #expect(tue.first?.isCancelled == true)
    #expect(tue.first?.cancellationOrigin == .manual)
    #expect(try store.scheduleChanges() == [.cancellation(di8b, .manual)])
    #expect(try store.timetable()?.entries.count == 2)
  }

  @Test("Von Hand gesetzter Ausfall lässt sich aufheben")
  func removeCancellationRemovesManualCancellation() throws {
    let store = try makeStore()
    try seedFixtureB(store)
    try store.markCancelled(di8b)
    #expect(try store.removeCancellation(di8b) == true)
    #expect(try store.scheduleChanges().isEmpty)
    #expect(try store.removeCancellation(di8b) == false)
  }

  @Test("AK-16 (Daten): Vertretungsstunde Mi 4. Stunde 6c Mathe nur an diesem Datum")
  func substituteLessonOnlyOnItsDate() throws {
    let store = try makeStore()
    try seedFixtureB(store)
    let key = try store.addSubstituteLesson(
      date: wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"))
    #expect(key?.date == wed18)
    #expect(try store.lessons(on: wed18).contains { $0.isSubstituteLesson && $0.period == 4 })
    #expect(
      try store.lessons(on: CalendarDay(year: 2026, month: 11, day: 25)).contains {
        $0.isSubstituteLesson
      } == false)
  }

  @Test("Vertretungsstunde von Hand entfernen")
  func removeSubstituteLessonRemovesManualOne() throws {
    let store = try makeStore()
    try seedFixtureB(store)
    try store.addSubstituteLesson(
      date: wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"))
    #expect(
      try store.removeSubstituteLesson(
        date: wed18, period: 4, schoolClass: SchoolClass("6c"), subject: Subject("Mathe")))
    #expect(try store.lessons(on: wed18).isEmpty)
  }

  @Test("Ausfall aus der Quelle lässt sich nicht von Hand aufheben")
  func removeCancellationKeepsSourceCancellation() throws {
    let store = try makeStore()
    try store.replaceScheduleChanges([.cancellation(di8b, .source)], sourceFetchedAt: nil)
    #expect(try store.removeCancellation(di8b) == false)
    #expect(try store.scheduleChanges().count == 1)
  }

  @Test("Von Hand geänderter Quell-Eintrag zählt als von Hand geändert (AK-3-Vorarbeit)")
  func replacedImportedEntryIsManuallyEdited() throws {
    let store = try makeStore()
    let e = fixtureB.entries[0]
    let e2 = TimetableEntry(
      weekday: .tuesday, period: 3, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"))
    try store.replaceTimetable(
      entries: [e], manuallyEdited: [], weekVariantCount: 1, referenceWeekA: nil, bellSchedule: nil)
    #expect(try store.manuallyEditedEntries().isEmpty)
    try store.replaceEntry(e, with: e2)
    #expect(try store.manuallyEditedEntries() == [e2])
    let records = try store.activeTimetableRecord()?.entries ?? []
    let record = try #require(records.first)
    #expect(record.origin == .source)
  }

  @Test("Zwei Wochenvarianten: Bezugswoche wird auf den Montag gesetzt, andere Anzahl wird abgelehnt")
  func weekVariantsNormalizeReferenceWeek() throws {
    let store = try makeStore()
    try store.setWeekVariants(count: 2, referenceWeekA: wed18)
    let timetable = try #require(try store.timetable())
    #expect(timetable.weekVariantCount == 2)
    #expect(timetable.referenceWeekA == CalendarDay(year: 2026, month: 11, day: 16))
    #expect(throws: DataStoreError.invalidWeekVariantCount(3)) {
      try store.setWeekVariants(count: 3, referenceWeekA: wed18)
    }
  }

  @Test("revision steigt bei jeder Änderung")
  func revisionIncreasesOnWrite() throws {
    let store = try makeStore()
    #expect(store.revision == 0)
    try store.addEntry(fixtureB.entries[0])
    #expect(store.revision == 1)
    try store.markCancelled(di8b)
    try store.markCancelled(di8b)
    #expect(store.revision == 2)
  }

  @Test("Unterrichtsfreier Zeitraum: keine Unterrichtsstunden")
  func nonTeachingPeriodHasNoLessons() throws {
    let store = try makeStore()
    try store.addEntry(
      TimetableEntry(
        weekday: .tuesday, period: 2, schoolClass: SchoolClass("8b"), subject: Subject("Englisch")))
    let tue3 = CalendarDay(year: 2026, month: 11, day: 3)
    #expect(try store.lessons(on: tue3).count == 1)
    try store.addNonTeachingPeriod(
      NonTeachingPeriod(
        from: CalendarDay(year: 2026, month: 11, day: 2),
        to: CalendarDay(year: 2026, month: 11, day: 6), title: "Herbstferien"))
    #expect(try store.lessons(on: tue3).isEmpty)
    #expect(try store.nonTeachingPeriods().count == 1)
  }

  @Test("Nächste Stunde: gleiche Klasse und gleiches Fach")
  func nextLessonKeepsClassAndSubject() throws {
    let store = try makeStore()
    try seedFixtureB(store)
    let next = try store.nextLesson(after: di8b)
    #expect(next?.date == thu19)
    #expect(next?.schoolClass == SchoolClass("8b"))
  }
}

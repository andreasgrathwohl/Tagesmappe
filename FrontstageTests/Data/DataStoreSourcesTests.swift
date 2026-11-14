import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

@MainActor @Suite struct DataStoreSourcesTests {
  private let mo5_8a = TimetableEntry(
    weekday: .monday, period: 5, schoolClass: SchoolClass("8a"), subject: Subject("Englisch"))
  private let di2_8b = TimetableEntry(
    weekday: .tuesday, period: 2, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"))
  private let mi4_7a = TimetableEntry(
    weekday: .wednesday, period: 4, schoolClass: SchoolClass("7a"), subject: Subject("Deutsch"))
  private let di8b = LessonKey(
    date: tue17, schoolClass: SchoolClass("8b"), subject: Subject("Englisch"), ordinal: 1)

  @Test("AK-3 (Daten): Übernahme behält den von Hand angelegten Eintrag und markiert Quell-Einträge")
  func replaceTimetableKeepsManualOriginAndMarksSource() throws {
    let store = try makeStore()
    try store.addEntry(mo5_8a, origin: .manual)
    try store.replaceTimetable(
      entries: [mo5_8a, di2_8b, mi4_7a], manuallyEdited: [mo5_8a], weekVariantCount: 1,
      referenceWeekA: nil,
      bellSchedule: BellSchedule(periods: [
        2: TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20)
      ]))
    #expect(try store.timetable()?.entries.count == 3)
    #expect(try store.manuallyEditedEntries() == [mo5_8a])
    #expect(
      try store.timetable()?.bellSchedule.periods[2]
        == TimeOfDay(hour: 8, minute: 35)...TimeOfDay(hour: 9, minute: 20))
  }

  @Test("Übernahme entfernt Einträge, die in der Quelle fehlen, und behält gleiche Datensätze")
  func replaceTimetableDropsMissingAndKeepsRecords() throws {
    let store = try makeStore()
    try store.replaceTimetable(
      entries: [di2_8b, mi4_7a], manuallyEdited: [], weekVariantCount: 1, referenceWeekA: nil,
      bellSchedule: nil)
    let beforeRecords = try store.activeTimetableRecord()?.entries ?? []
    let before = try #require(beforeRecords.first { $0.makeEntry() == di2_8b })
    try store.replaceTimetable(
      entries: [di2_8b], manuallyEdited: [], weekVariantCount: 2,
      referenceWeekA: wed18, bellSchedule: nil)
    #expect(try store.timetable()?.entries == [di2_8b])
    #expect(try store.timetable()?.weekVariantCount == 2)
    #expect(try store.timetable()?.referenceWeekA == CalendarDay(year: 2026, month: 11, day: 16))
    let afterRecords = try store.activeTimetableRecord()?.entries ?? []
    let after = try #require(afterRecords.first)
    #expect(after.id == before.id)
  }

  @Test("Abweichungen ersetzen und Stand setzen in einem Schritt")
  func replaceScheduleChangesSetsFetchedAt() throws {
    let store = try makeStore()
    let t1 = Date(timeIntervalSince1970: 1_800_000_000)
    let substitute = ScheduleChange.substituteLesson(
      date: wed18, period: 3, schoolClass: SchoolClass("6c"), subject: Subject("Mathe"), .source)
    try store.markCancelled(di8b)
    try store.replaceScheduleChanges([.cancellation(di8b, .manual), substitute], sourceFetchedAt: t1)
    #expect(Set(try store.scheduleChanges()) == [.cancellation(di8b, .manual), substitute])
    #expect(try store.sourceFetchedAt() == t1)
    #expect(try store.modelContext.fetchCount(FetchDescriptor<ScheduleChangeRecord>()) == 2)
  }

  @Test("Quelle umstellen speichert den Rohwert")
  func sourceRawRoundTrip() throws {
    let store = try makeStore()
    #expect(try store.timetableSourceRaw() == "manual")
    try store.setTimetableSourceRaw("schulmanager")
    #expect(try store.timetableSourceRaw() == "schulmanager")
  }
}

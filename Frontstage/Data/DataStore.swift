import Foundation
import FrontstageCore
import Observation
import SwiftData

/// Fehler des `DataStore`, die der Aufrufer sich merken oder anzeigen kann.
enum DataStoreError: Error, Equatable {
  /// Wochenvarianten gibt es nur als 1 (jede Woche gleich) oder 2 (A-/B-Woche).
  case invalidWeekVariantCount(Int)
}

/// Einziger Schreibzugang zu den App-Daten (Übersicht, Abstimmung Punkt 4).
/// Lesen für Listen darf die Oberfläche auch per `@Query`.
///
/// Swift-Hinweis: `@Observable` (Observation-Framework) macht gespeicherte Eigenschaften für SwiftUI
/// beobachtbar. Eine Ansicht, die `revision` liest, wird bei jeder Änderung neu gezeichnet.
/// Jede Schreiboperation endet mit `modelContext.save()` über `saveAndBump()`.
@MainActor @Observable final class DataStore {
  let modelContext: ModelContext
  /// Liefert den heutigen Tag; die Uhr wird nur hier gelesen, damit Tests sie festlegen können.
  let today: @MainActor () -> CalendarDay

  /// Steigt nach jedem erfolgreichen `save()` (auch beim Zusammenführen, das über `saveAndBump()`
  /// speichert); die Oberfläche lädt darauf neu.
  private(set) var revision: Int = 0

  init(
    modelContext: ModelContext,
    today: @escaping @MainActor () -> CalendarDay = { CalendarDay(Date(), calendar: .current) }
  ) {
    self.modelContext = modelContext
    self.today = today
  }

  // MARK: - Speichern

  /// Speichert und erhöht danach `revision`. Scheitert das Speichern, werden die ungespeicherten
  /// Änderungen verworfen, damit der Kontext nicht halb geschriebene Daten behält.
  func saveAndBump() throws {
    do {
      try modelContext.save()
    } catch {
      modelContext.rollback()
      throw error
    }
    revision += 1
  }

  // MARK: - Stundenplan (FR-1, FR-1.1, FR-1.2)

  /// Der älteste aktive Stundenplan. Gibt es auf zwei Geräten je einen, gewinnt der ältere.
  func activeTimetableRecord() throws -> TimetableRecord? {
    var descriptor = FetchDescriptor<TimetableRecord>(
      predicate: #Predicate { $0.isActive }, sortBy: [SortDescriptor(\.createdAt)])
    descriptor.fetchLimit = 1
    return try modelContext.fetch(descriptor).first
  }

  /// Der Kern-Stundenplan; `nil` ohne aktiven Stundenplan.
  func timetable() throws -> Timetable? {
    try activeTimetableRecord()?.makeTimetable()
  }

  /// Legt einen Eintrag an; bei Bedarf entsteht der aktive Stundenplan. Ein Duplikat ändert nichts.
  func addEntry(_ entry: TimetableEntry, origin: Origin = .manual) throws {
    let timetable = try ensureActiveTimetableRecord()
    if entryRecords(of: timetable, matching: entry).first != nil { return }
    insertEntryRecord(entry, origin: origin, into: timetable)
    try saveAndBump()
  }

  /// Von Hand ändern: Die Herkunft bleibt; ein Quell-Eintrag bekommt `isManuallyEdited = true`.
  /// Gibt es den neuen Eintrag schon, wird der alte nur entfernt (kein Duplikat).
  func replaceEntry(_ old: TimetableEntry, with new: TimetableEntry) throws {
    guard let timetable = try activeTimetableRecord(),
      let record = entryRecords(of: timetable, matching: old).first
    else { return }
    if old == new { return }
    if entryRecords(of: timetable, matching: new).first != nil {
      modelContext.delete(record)
    } else {
      let origin = record.origin
      record.apply(new, origin: origin)
      if origin == .source { record.isManuallyEdited = true }
    }
    try saveAndBump()
  }

  func removeEntry(_ entry: TimetableEntry) throws {
    guard let timetable = try activeTimetableRecord() else { return }
    let matches = entryRecords(of: timetable, matching: entry)
    guard !matches.isEmpty else { return }
    for record in matches { modelContext.delete(record) }
    try saveAndBump()
  }

  /// `count` nur 1 oder 2; `referenceWeekA` wird auf den Montag seiner Woche gesetzt.
  func setWeekVariants(count: Int, referenceWeekA: CalendarDay) throws {
    guard count == 1 || count == 2 else { throw DataStoreError.invalidWeekVariantCount(count) }
    let timetable = try ensureActiveTimetableRecord()
    timetable.weekVariantCount = count
    timetable.referenceWeekAText = referenceWeekA.mondayOfWeek.storageText
    try saveAndBump()
  }

  func setBellSchedule(_ schedule: BellSchedule) throws {
    let timetable = try ensureActiveTimetableRecord()
    timetable.setBellSchedule(schedule)
    try saveAndBump()
  }

  /// Einträge mit Herkunft `.manual` oder `isManuallyEdited` (Eingabe für `ImportDiffer`, AK-3).
  func manuallyEditedEntries() throws -> Set<TimetableEntry> {
    guard let timetable = try activeTimetableRecord() else { return [] }
    var result = Set<TimetableEntry>()
    for record in timetable.entries ?? [] where record.origin == .manual || record.isManuallyEdited {
      if let entry = record.makeEntry() { result.insert(entry) }
    }
    return result
  }

  // MARK: - Unterrichtsfreie Zeiträume (FR-7)

  /// Nach Beginn sortiert (bei gleichem Beginn nach Ende und Titel).
  func nonTeachingPeriods() throws -> [NonTeachingPeriod] {
    try modelContext.fetch(FetchDescriptor<NonTeachingPeriodRecord>()).compactMap { $0.makePeriod() }
      .sorted { ($0.from, $0.to, $0.title) < ($1.from, $1.to, $1.title) }
  }

  func addNonTeachingPeriod(_ period: NonTeachingPeriod) throws {
    let existing = try modelContext.fetch(FetchDescriptor<NonTeachingPeriodRecord>())
    if existing.contains(where: { $0.makePeriod() == period }) { return }
    let record = NonTeachingPeriodRecord()
    modelContext.insert(record)
    record.apply(period)
    try saveAndBump()
  }

  func removeNonTeachingPeriod(_ period: NonTeachingPeriod) throws {
    let matches = try modelContext.fetch(FetchDescriptor<NonTeachingPeriodRecord>()).filter {
      $0.makePeriod() == period
    }
    guard !matches.isEmpty else { return }
    for record in matches { modelContext.delete(record) }
    try saveAndBump()
  }

  // MARK: - Abweichungen (FR-8, FR-9)

  func scheduleChanges() throws -> [ScheduleChange] {
    try scheduleChangeRecords().compactMap { $0.makeChange() }
  }

  /// Idempotent: Besteht schon ein Ausfall dieser Stunde, gleich welcher Herkunft, geschieht nichts.
  func markCancelled(_ key: LessonKey) throws {
    let exists = try scheduleChanges().contains {
      if case .cancellation(let existingKey, _) = $0 { return existingKey == key }
      return false
    }
    if exists { return }
    insertChangeRecord(.cancellation(key, .manual))
    try saveAndBump()
  }

  /// Hebt nur einen von Hand markierten Ausfall auf. `false`, wenn keiner besteht – auch wenn nur
  /// ein Ausfall mit Herkunft `.source` besteht (dann bleibt alles unverändert).
  @discardableResult
  func removeCancellation(_ key: LessonKey) throws -> Bool {
    let target = ScheduleChange.cancellation(key, .manual)
    let matches = try scheduleChangeRecords().filter { $0.makeChange() == target }
    guard !matches.isEmpty else { return false }
    for record in matches { modelContext.delete(record) }
    try saveAndBump()
    return true
  }

  /// Legt eine Vertretungsstunde mit Herkunft `.manual` an und gibt ihren Schlüssel zurück.
  /// `nil`, wenn die Stunde nicht berechnet wird (unterrichtsfreier Tag oder kein Stundenplan).
  /// Besteht dieselbe Vertretung schon (beliebige Herkunft), wird nichts gespeichert.
  @discardableResult
  func addSubstituteLesson(
    date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject
  ) throws -> LessonKey? {
    let exists = try scheduleChanges().contains {
      if case .substituteLesson(let d, let p, let c, let s, _) = $0 {
        return d == date && p == period && c == schoolClass && s == subject
      }
      return false
    }
    if !exists {
      insertChangeRecord(
        .substituteLesson(
          date: date, period: period, schoolClass: schoolClass, subject: subject, .manual))
      try saveAndBump()
    }
    return try lessons(on: date).first {
      $0.isSubstituteLesson && $0.period == period && $0.key.schoolClass == schoolClass
        && $0.key.subject == subject
    }?.key
  }

  /// Nur Herkunft `.manual`; `false` bei `.source` oder wenn es die Vertretung nicht gibt.
  @discardableResult
  func removeSubstituteLesson(
    date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject
  ) throws -> Bool {
    let target = ScheduleChange.substituteLesson(
      date: date, period: period, schoolClass: schoolClass, subject: subject, .manual)
    let matches = try scheduleChangeRecords().filter { $0.makeChange() == target }
    guard !matches.isEmpty else { return false }
    for record in matches { modelContext.delete(record) }
    try saveAndBump()
    return true
  }

  // MARK: - Unterrichtsstunden (berechnet, nie gespeichert)

  /// Leer ohne Stundenplan und an unterrichtsfreien Tagen.
  func lessons(on day: CalendarDay) throws -> [Lesson] {
    guard let timetable = try timetable() else { return [] }
    return TimetableCalculator.lessons(
      on: day, timetable: timetable, nonTeachingPeriods: try nonTeachingPeriods(),
      changes: try scheduleChanges())
  }

  /// Nächste nicht ausgefallene Stunde derselben Klasse und desselben Fachs (Nutzerentscheidung 2026-11-13).
  func nextLesson(after key: LessonKey) throws -> LessonKey? {
    guard let timetable = try timetable() else { return nil }
    return TimetableCalculator.nextLesson(
      after: key, timetable: timetable, nonTeachingPeriods: try nonTeachingPeriods(),
      changes: try scheduleChanges())
  }

  // MARK: - Hilfen (auch für DataStore+Sources)

  /// Der aktive Stundenplan; fehlt er, wird er angelegt (erst beim ersten Schreiben, nicht beim
  /// App-Start – das verringert doppelte Stundenpläne bei zwei Geräten). Speichert nicht selbst:
  /// Der Aufrufer ruft danach `saveAndBump()`.
  func ensureActiveTimetableRecord() throws -> TimetableRecord {
    if let existing = try activeTimetableRecord() { return existing }
    let record = TimetableRecord(
      referenceWeekAText: today().mondayOfWeek.storageText, isActive: true)
    modelContext.insert(record)
    return record
  }

  func scheduleChangeRecords() throws -> [ScheduleChangeRecord] {
    try modelContext.fetch(
      FetchDescriptor<ScheduleChangeRecord>(sortBy: [SortDescriptor(\.createdAt)]))
  }

  func insertChangeRecord(_ change: ScheduleChange) {
    let record = ScheduleChangeRecord()
    modelContext.insert(record)
    record.apply(change)
  }

  func insertEntryRecord(_ entry: TimetableEntry, origin: Origin, into timetable: TimetableRecord) {
    let record = TimetableEntryRecord()
    modelContext.insert(record)
    record.apply(entry, origin: origin)
    record.timetable = timetable
  }

  private func entryRecords(of timetable: TimetableRecord, matching entry: TimetableEntry)
    -> [TimetableEntryRecord]
  {
    (timetable.entries ?? []).filter { $0.makeEntry() == entry }
  }
}

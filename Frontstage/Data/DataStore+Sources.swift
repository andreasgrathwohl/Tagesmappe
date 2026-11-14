import Foundation
import FrontstageCore
import SwiftData

/// Was Teilplan 05 über sein Protokoll `TimetableRepository` aufruft. Rohwerte statt
/// `TimetableSourceKind`, damit dieser Teilplan nicht von Teilplan 05 abhängt.
extension DataStore {
  /// `sourceKindRaw` des aktiven Stundenplans; ohne Stundenplan `"manual"`.
  func timetableSourceRaw() throws -> String {
    try activeTimetableRecord()?.sourceKindRaw ?? "manual"
  }

  /// Legt bei Bedarf den aktiven Stundenplan an.
  func setTimetableSourceRaw(_ raw: String) throws {
    let timetable = try ensureActiveTimetableRecord()
    timetable.sourceKindRaw = raw
    try saveAndBump()
  }

  /// „Stand“ (Glossar): Zeitpunkt der letzten erfolgreichen Abfrage, gespiegelt.
  func sourceFetchedAt() throws -> Date? {
    try activeTimetableRecord()?.sourceFetchedAt
  }

  /// Übernahme eines Imports in einem `save()`: ersetzt alle Einträge des aktiven Stundenplans durch `entries`.
  /// Einträge in `manuallyEdited` behalten Herkunft und `isManuallyEdited` ihres vorhandenen Datensatzes
  /// (neu angelegt: `.manual`); alle anderen werden Herkunft `.source` mit `isManuallyEdited = false`.
  /// Gleiche Einträge behalten ihren Datensatz (`createdAt` bleibt).
  /// `referenceWeekA` nil → unverändert; `bellSchedule` nil → unverändert.
  func replaceTimetable(
    entries: [TimetableEntry], manuallyEdited: Set<TimetableEntry>, weekVariantCount: Int,
    referenceWeekA: CalendarDay?, bellSchedule: BellSchedule?
  ) throws {
    guard weekVariantCount == 1 || weekVariantCount == 2 else {
      throw DataStoreError.invalidWeekVariantCount(weekVariantCount)
    }
    let timetable = try ensureActiveTimetableRecord()

    // Gewünschte Einträge ohne Doppelte, Reihenfolge der Eingabe bleibt.
    var wanted: [TimetableEntry] = []
    var wantedSet = Set<TimetableEntry>()
    for entry in entries where wantedSet.insert(entry).inserted { wanted.append(entry) }

    // Vorhandene Datensätze: behalten, was gewünscht und noch nicht vergeben ist; sonst löschen.
    var claimed = Set<TimetableEntry>()
    for record in timetable.entries ?? [] {
      guard let entry = record.makeEntry(), wantedSet.contains(entry), claimed.insert(entry).inserted
      else {
        modelContext.delete(record)
        continue
      }
      if !manuallyEdited.contains(entry) {
        record.originRaw = Origin.source.rawValue
        record.isManuallyEdited = false
      }
    }
    for entry in wanted where !claimed.contains(entry) {
      insertEntryRecord(
        entry, origin: manuallyEdited.contains(entry) ? .manual : .source, into: timetable)
    }

    timetable.weekVariantCount = weekVariantCount
    if let referenceWeekA { timetable.referenceWeekAText = referenceWeekA.mondayOfWeek.storageText }
    if let bellSchedule { timetable.setBellSchedule(bellSchedule) }
    try saveAndBump()
  }

  /// Ersetzt die Menge aller Abweichungen durch `changes` (Datensätze gleicher Abweichungen bleiben,
  /// fehlende werden gelöscht, neue angelegt) und setzt, wenn nicht nil, den Stand – ein `save()`.
  /// Welche `.source`-Abweichungen wegfallen, rechnet Teilplan 05 im Kern (`ScheduleChangeMerger`) aus.
  func replaceScheduleChanges(_ changes: [ScheduleChange], sourceFetchedAt: Date?) throws {
    var wanted: [ScheduleChange] = []
    var wantedSet = Set<ScheduleChange>()
    for change in changes where wantedSet.insert(change).inserted { wanted.append(change) }

    var claimed = Set<ScheduleChange>()
    for record in try scheduleChangeRecords() {
      guard let change = record.makeChange(), wantedSet.contains(change),
        claimed.insert(change).inserted
      else {
        modelContext.delete(record)
        continue
      }
    }
    for change in wanted where !claimed.contains(change) { insertChangeRecord(change) }

    if let sourceFetchedAt {
      try ensureActiveTimetableRecord().sourceFetchedAt = sourceFetchedAt
    }
    try saveAndBump()
  }
}

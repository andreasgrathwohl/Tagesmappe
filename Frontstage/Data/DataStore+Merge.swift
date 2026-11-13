import Foundation
import FrontstageCore
import SwiftData

/// Zusammenführen doppelter Datensätze nach einer iCloud-Synchronisierung (Architecture Doc,
/// Nebenläufigkeit). Die Entscheidung trifft der reine Kern (`SyncMerger`); hier wird nur angewendet.
extension DataStore {
  /// Bildet alle Datensätze als Wertabbilder ab (Mengen im Hunderterbereich, daher vollständig geladen).
  /// Unlesbare Einträge, Abweichungen und Zeiträume (Rohtext nicht auswertbar) fehlen im Schnappschuss
  /// und bleiben damit unangetastet.
  func makeSyncSnapshot() throws -> SyncSnapshot {
    SyncSnapshot(
      timetables: try modelContext.fetch(FetchDescriptor<TimetableRecord>()).map { $0.snapshot() },
      entries: try modelContext.fetch(FetchDescriptor<TimetableEntryRecord>()).compactMap {
        $0.snapshot()
      },
      links: try modelContext.fetch(FetchDescriptor<MaterialLinkRecord>()).map { $0.snapshot() },
      penNotes: try modelContext.fetch(FetchDescriptor<PenNoteRecord>()).map { $0.snapshot() },
      lessonInfos: try modelContext.fetch(FetchDescriptor<LessonInfoRecord>()).map { $0.snapshot() },
      scheduleChanges: try modelContext.fetch(FetchDescriptor<ScheduleChangeRecord>()).compactMap {
        $0.snapshot()
      },
      nonTeachingPeriods: try modelContext.fetch(FetchDescriptor<NonTeachingPeriodRecord>())
        .compactMap { $0.snapshot() })
  }

  /// Schnappschuss → Plan → anwenden → speichern. Idempotent; ein leerer Plan speichert nichts.
  @discardableResult
  func mergeDuplicates() throws -> MergePlan {
    let plan = SyncMerger.plan(for: try makeSyncSnapshot())
    if plan.isEmpty { return plan }

    // Wörterbuch je Modell (id → Datensatz). Doppelte ids dürfte es nicht geben; falls doch, gewinnt
    // der erste Treffer, statt abzustürzen.
    let timetables = Dictionary(
      try modelContext.fetch(FetchDescriptor<TimetableRecord>()).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })
    let entries = Dictionary(
      try modelContext.fetch(FetchDescriptor<TimetableEntryRecord>()).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })
    let links = Dictionary(
      try modelContext.fetch(FetchDescriptor<MaterialLinkRecord>()).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })
    let notes = Dictionary(
      try modelContext.fetch(FetchDescriptor<PenNoteRecord>()).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })
    let infos = Dictionary(
      try modelContext.fetch(FetchDescriptor<LessonInfoRecord>()).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })
    let changes = Dictionary(
      try modelContext.fetch(FetchDescriptor<ScheduleChangeRecord>()).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })
    let periods = Dictionary(
      try modelContext.fetch(FetchDescriptor<NonTeachingPeriodRecord>()).map { ($0.id, $0) },
      uniquingKeysWith: { first, _ in first })

    // 1. Einträge an den behaltenen Stundenplan hängen (vor dem Löschen, sonst fiele der Eintrag
    //    mit dem aufgegebenen Stundenplan per Kaskade weg).
    for (entryID, timetableID) in plan.entryTimetableChanges {
      if let entry = entries[entryID], let timetable = timetables[timetableID] {
        entry.timetable = timetable
      }
    }

    // 2. Stiftnotizen an die behaltene Zuordnung hängen (aus demselben Grund vor dem Löschen).
    for (noteID, linkID) in plan.penNoteLinkChanges {
      if let note = notes[noteID], let link = links[linkID] {
        note.materialLink = link
      }
    }

    // 3. Zeichnung der zuletzt geänderten Notiz übernehmen (die Quelle existiert noch).
    for (keeperID, sourceID) in plan.penNoteDrawingSources {
      guard let keeper = notes[keeperID], let source = notes[sourceID] else { continue }
      keeper.drawingData = source.drawingData
      keeper.pageWidth = source.pageWidth
      keeper.pageHeight = source.pageHeight
      keeper.updatedAt = source.updatedAt
    }

    // 4. Stundenangaben je Feld übernehmen: Wert und Feld-Zeitstempel (die Quelle existiert noch).
    for (keeperID, sources) in plan.lessonInfoFieldSources {
      guard let keeper = infos[keeperID] else { continue }
      for (field, sourceID) in sources {
        guard let source = infos[sourceID] else { continue }
        switch field {
        case .topic:
          keeper.topic = source.topic
          keeper.topicUpdatedAt = source.topicUpdatedAt
        case .toPrepare:
          keeper.toPrepare = source.toPrepare
          keeper.toPrepareUpdatedAt = source.toPrepareUpdatedAt
        case .homework:
          keeper.homework = source.homework
          keeper.homeworkUpdatedAt = source.homeworkUpdatedAt
        }
        if source.updatedAt > keeper.updatedAt { keeper.updatedAt = source.updatedAt }
      }
    }

    // 5. Records löschen; Kaskaden treffen jetzt nur noch Aufgegebenes.
    for id in plan.deletions {
      if let record = timetables[id] {
        modelContext.delete(record)
      } else if let record = entries[id] {
        modelContext.delete(record)
      } else if let record = links[id] {
        modelContext.delete(record)
      } else if let record = notes[id] {
        modelContext.delete(record)
      } else if let record = infos[id] {
        modelContext.delete(record)
      } else if let record = changes[id] {
        modelContext.delete(record)
      } else if let record = periods[id] {
        modelContext.delete(record)
      }
    }

    // 6. Speichern (erhöht auch `revision`, damit die Oberfläche neu lädt).
    try saveAndBump()
    return plan
  }
}

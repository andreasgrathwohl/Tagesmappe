import Foundation
import FrontstageCore
import OSLog
import SwiftData

/// Zusammenführen doppelter Datensätze nach einer iCloud-Synchronisierung (Architecture Doc,
/// Nebenläufigkeit). Die Entscheidung trifft der reine Kern (`SyncMerger`); hier wird nur angewendet.
extension DataStore {
  /// Bildet alle Datensätze als Wertabbilder ab (Mengen im Hunderterbereich, daher vollständig geladen).
  /// Unlesbare Einträge, Abweichungen und Zeiträume (Rohtext nicht auswertbar) fehlen im Schnappschuss
  /// und bleiben damit unangetastet.
  func makeSyncSnapshot() throws -> SyncSnapshot {
    try LoadedRecords(modelContext).snapshot()
  }

  /// Schnappschuss → Plan → anwenden → speichern. Idempotent; ein leerer Plan speichert nichts.
  @discardableResult
  func mergeDuplicates() throws -> MergePlan {
    // Einmal laden: dieselben Datensätze liefern den Schnappschuss und die id-Wörterbücher.
    let loaded = try LoadedRecords(modelContext)
    let plan = SyncMerger.plan(for: loaded.snapshot())
    let coursePlan = CoursePlanMerger.plan(for: loaded.coursePlanSnapshot())
    let themePlan = ThemeMerger.plan(
      for: loaded.themes.map { ThemeMergeEntry(id: $0.id, createdAt: $0.createdAt, updatedAt: $0.updatedAt) })
    // Früher Ausgang nur, wenn alle drei Pläne leer sind: Doppelte Jahrespläne oder ein doppeltes
    // Erscheinungsbild allein müssen laufen.
    if plan.isEmpty && coursePlan.isEmpty && themePlan.isEmpty { return plan }

    // Wörterbuch je Modell (id → Datensatz). Doppelte ids dürfte es nicht geben; falls doch, gewinnt
    // der erste Treffer, statt abzustürzen.
    let timetables = Self.byID(loaded.timetables, id: \.id)
    let entries = Self.byID(loaded.entries, id: \.id)
    let links = Self.byID(loaded.links, id: \.id)
    let notes = Self.byID(loaded.penNotes, id: \.id)
    let infos = Self.byID(loaded.lessonInfos, id: \.id)
    let changes = Self.byID(loaded.scheduleChanges, id: \.id)
    let periods = Self.byID(loaded.nonTeachingPeriods, id: \.id)

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

    // 4a. Lösung (FR-6.3) der aufgegebenen Zuordnung an die behaltene ohne Lösung (die Quelle existiert noch).
    for (keeperID, sourceID) in plan.linkSolutionSources {
      if let keeper = links[keeperID], let source = links[sourceID] {
        keeper.setSolution(source.solution)
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

    // 6. Jahrespläne: Kinder an den behaltenen Plan hängen, Wochen-Inhalt übernehmen, dann löschen
    //    (Kinder zuerst; sonst nähme die Kaskade der Pläne sie mit und ein zweites Löschen träfe Totes).
    let years = Self.byID(loaded.schoolYears, id: \.id)
    let coursePlans = Self.byID(loaded.coursePlans, id: \.id)
    let weeks = Self.byID(loaded.planWeeks, id: \.id)
    let assessments = Self.byID(loaded.assessments, id: \.id)

    for (childID, planID) in coursePlan.parentChanges {
      guard let target = coursePlans[planID] else { continue }
      if let week = weeks[childID] {
        week.coursePlan = target
      } else if let assessment = assessments[childID] {
        assessment.coursePlan = target
      }
    }

    for (keeperID, sourceID) in coursePlan.weekContentSources {
      guard let keeper = weeks[keeperID], let source = weeks[sourceID] else { continue }
      keeper.topic = source.topic
      keeper.notes = source.notes
      keeper.updatedAt = source.updatedAt
    }

    for id in coursePlan.deletions {
      if let record = weeks[id] {
        modelContext.delete(record)
      } else if let record = assessments[id] {
        modelContext.delete(record)
      }
    }
    for id in coursePlan.deletions {
      if let record = coursePlans[id] {
        modelContext.delete(record)
      } else if let record = years[id] {
        modelContext.delete(record)
      }
    }

    // 7. Erscheinungsbild: Inhalt des zuletzt geänderten auf den behaltenen Datensatz, dann löschen.
    let themes = Self.byID(loaded.themes, id: \.id)
    if let keeperID = themePlan.keeperID, let sourceID = themePlan.contentSourceID, keeperID != sourceID,
      let keeper = themes[keeperID], let source = themes[sourceID]
    {
      keeper.baseToneRaw = source.baseToneRaw
      keeper.accentHex = source.accentHex
      keeper.appearanceModeRaw = source.appearanceModeRaw
      keeper.updatedAt = source.updatedAt
    }
    for id in themePlan.deletions {
      if let record = themes[id] { modelContext.delete(record) }
    }

    // 8. Speichern (erhöht auch `revision`, damit die Oberfläche neu lädt).
    try saveAndBump()
    return plan
  }

  /// Zusammenführen nach einer bereits gespeicherten Änderung: Ein Fehler wird nur protokolliert,
  /// damit der Aufrufer keinen Fehler meldet, obwohl seine Änderung gespeichert ist
  /// (wie `SyncMergeTrigger`; der nächste Anlass führt erneut zusammen).
  func mergeDuplicatesLoggingFailure() {
    do {
      try mergeDuplicates()
    } catch {
      Self.mergeLogger.error(
        "Zusammenführen fehlgeschlagen: \(String(describing: error), privacy: .public)")
    }
  }

  private static let mergeLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.example.frontstage", category: "sync")

  /// id → Datensatz; bei doppelter id gewinnt der erste Treffer.
  private static func byID<Record>(_ records: [Record], id: (Record) -> UUID) -> [UUID: Record] {
    Dictionary(records.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })
  }
}

/// Alle zusammenführbaren Datensätze, einmal geladen.
@MainActor private struct LoadedRecords {
  let timetables: [TimetableRecord]
  let entries: [TimetableEntryRecord]
  let links: [MaterialLinkRecord]
  let penNotes: [PenNoteRecord]
  let lessonInfos: [LessonInfoRecord]
  let scheduleChanges: [ScheduleChangeRecord]
  let nonTeachingPeriods: [NonTeachingPeriodRecord]
  let schoolYears: [SchoolYearRecord]
  let coursePlans: [CoursePlanRecord]
  let planWeeks: [PlanWeekRecord]
  let assessments: [AssessmentRecord]
  let themes: [ThemeRecord]

  init(_ context: ModelContext) throws {
    schoolYears = try context.fetch(FetchDescriptor<SchoolYearRecord>())
    coursePlans = try context.fetch(FetchDescriptor<CoursePlanRecord>())
    planWeeks = try context.fetch(FetchDescriptor<PlanWeekRecord>())
    assessments = try context.fetch(FetchDescriptor<AssessmentRecord>())
    themes = try context.fetch(FetchDescriptor<ThemeRecord>())
    timetables = try context.fetch(FetchDescriptor<TimetableRecord>())
    entries = try context.fetch(FetchDescriptor<TimetableEntryRecord>())
    links = try context.fetch(FetchDescriptor<MaterialLinkRecord>())
    penNotes = try context.fetch(FetchDescriptor<PenNoteRecord>())
    lessonInfos = try context.fetch(FetchDescriptor<LessonInfoRecord>())
    scheduleChanges = try context.fetch(FetchDescriptor<ScheduleChangeRecord>())
    nonTeachingPeriods = try context.fetch(FetchDescriptor<NonTeachingPeriodRecord>())
  }

  /// Unlesbare Schuljahre, Jahrespläne (Jahrgang außerhalb 1...13) und Leistungsnachweise
  /// (unbekannte Art) fehlen und bleiben unangetastet.
  func coursePlanSnapshot() -> CoursePlanMergeSnapshot {
    CoursePlanMergeSnapshot(
      years: schoolYears.compactMap { record in
        record.makeSchoolYear().map {
          CoursePlanMergeSnapshot.Year(id: record.id, startYear: $0.startYear, createdAt: record.createdAt)
        }
      },
      plans: coursePlans.compactMap { record in
        record.key.map { CoursePlanMergeSnapshot.Plan(id: record.id, key: $0, createdAt: record.createdAt) }
      },
      weeks: planWeeks.map { record in
        let week = record.makePlanWeek()
        return CoursePlanMergeSnapshot.Week(
          id: record.id, planID: record.coursePlan?.id, monday: week.monday,
          createdAt: record.createdAt, updatedAt: record.updatedAt)
      },
      assessments: assessments.compactMap { record in
        record.makeAssessment().map {
          CoursePlanMergeSnapshot.Item(
            id: record.id, planID: record.coursePlan?.id, monday: $0.monday, day: $0.day,
            kind: $0.kind, title: $0.title, createdAt: record.createdAt)
        }
      })
  }

  func snapshot() -> SyncSnapshot {
    SyncSnapshot(
      timetables: timetables.map { $0.snapshot() },
      entries: entries.compactMap { $0.snapshot() },
      links: links.map { $0.snapshot() },
      penNotes: penNotes.map { $0.snapshot() },
      lessonInfos: lessonInfos.map { $0.snapshot() },
      scheduleChanges: scheduleChanges.compactMap { $0.snapshot() },
      nonTeachingPeriods: nonTeachingPeriods.compactMap { $0.snapshot() })
  }
}

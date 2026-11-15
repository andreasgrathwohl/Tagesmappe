import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

@MainActor @Suite struct RecordCodecTests {
  private let date = Date(timeIntervalSince1970: 1_800_000_000)
  private let later = Date(timeIntervalSince1970: 1_800_003_600)

  private func makeContext() throws -> ModelContext { try makeStore().modelContext }

  /// Füllt einen Store mit je einem Datensatz aller dreizehn Modelle (alle Felder gesetzt).
  @discardableResult
  private func populate(_ context: ModelContext) -> (timetable: TimetableRecord, link: MaterialLinkRecord) {
    let timetable = TimetableRecord(
      name: "Plan A", sourceKindRaw: "schulmanager", weekVariantCount: 2,
      referenceWeekAText: "2026-11-16", isActive: true)
    timetable.createdAt = date
    timetable.validFromText = "2026-09-01"
    timetable.validToText = "2027-07-31"
    timetable.sourceFetchedAt = later
    timetable.setBellSchedule(
      BellSchedule(periods: [
        1: TimeOfDay(hour: 8, minute: 0)...TimeOfDay(hour: 8, minute: 45),
        2: TimeOfDay(hour: 8, minute: 50)...TimeOfDay(hour: 9, minute: 35),
        3: TimeOfDay(hour: 9, minute: 50)...TimeOfDay(hour: 10, minute: 35),
      ]))
    context.insert(timetable)

    let entry = TimetableEntryRecord(
      weekVariantRaw: "a", weekdayRaw: 2, period: 3, schoolClassText: "8b", subjectText: "Englisch",
      originRaw: "source", isManuallyEdited: true, timetable: timetable)
    entry.createdAt = date
    context.insert(entry)

    let period = NonTeachingPeriodRecord(fromText: "2026-12-21", toText: "2027-01-01", title: "Ferien")
    period.createdAt = date
    context.insert(period)

    let change = ScheduleChangeRecord(
      kindRaw: "substituteLesson", originRaw: "source", dayText: "2026-11-17", lessonKeyText: nil,
      period: 4, schoolClassText: "9c", subjectText: "Deutsch")
    change.createdAt = date
    context.insert(change)

    let link = MaterialLinkRecord(
      lessonKeyText: "2026-11-17|3|8b|Englisch", dayText: "2026-11-17", position: 1,
      folderGrantName: "Unterricht", relativePath: "Englisch/Blatt.pdf", displayName: "Blatt.pdf",
      fileKindRaw: "pdf", oneDriveItemID: "item-1", oneDriveDriveID: "drive-1")
    link.createdAt = date
    context.insert(link)

    let note = PenNoteRecord(materialLink: link, pageIndex: 2)
    note.createdAt = date
    note.drawingData = Data([1, 2, 3, 4])
    note.pageWidth = 595
    note.pageHeight = 842
    note.updatedAt = later
    context.insert(note)

    let info = LessonInfoRecord(lessonKeyText: "2026-11-17|3|8b|Englisch")
    info.createdAt = date
    info.topic = "Past Tense"
    info.toPrepare = "Kopien"
    info.homework = "S. 12"
    info.updatedAt = later
    info.topicUpdatedAt = date
    info.toPrepareUpdatedAt = later
    info.homeworkUpdatedAt = later
    context.insert(info)

    let page = BoardPageRecord(lessonKeyText: "2026-11-17|3|8b|Englisch", position: 1, backgroundRaw: "grid")
    page.createdAt = date
    page.backgroundImageData = Data([9, 8, 7])
    page.drawingData = Data([5, 6])
    page.updatedAt = later
    context.insert(page)

    let year = SchoolYearRecord()
    year.createdAt = date
    year.apply(
      SchoolYear(
        firstDay: CalendarDay(year: 2026, month: 8, day: 31),
        secondTermStart: CalendarDay(year: 2027, month: 2, day: 1),
        lastDay: CalendarDay(year: 2027, month: 7, day: 2), gradeOverrides: ["ef": 11]))
    context.insert(year)

    let plan = CoursePlanRecord()
    plan.createdAt = date
    plan.subjectText = "Englisch"
    plan.gradeLevel = 8
    plan.startYear = 2026
    plan.notes = "Lehrwerk Band 4"
    context.insert(plan)

    let week = PlanWeekRecord()
    week.createdAt = date
    week.coursePlan = plan
    week.mondayText = "2026-11-16"
    week.position = 12
    week.topic = "Past Tense"
    week.notes = "Kopien"
    week.updatedAt = later
    context.insert(week)

    let assessment = AssessmentRecord()
    assessment.createdAt = date
    assessment.coursePlan = plan
    assessment.mondayText = "2026-11-16"
    assessment.dayText = "2026-11-18"
    assessment.kindRaw = "classTest"
    assessment.title = "Klassenarbeit 2"
    assessment.updatedAt = later
    context.insert(assessment)

    let theme = ThemeRecord()
    theme.createdAt = date
    theme.baseToneRaw = "petrol"
    theme.accentHex = "#C2410C"
    theme.appearanceModeRaw = "dark"
    theme.updatedAt = later
    context.insert(theme)

    return (timetable, link)
  }

  /// Übernimmt in der Reihenfolge Eltern vor Kindern (`SyncModel.applyOrder`).
  private func copy(_ records: [ExportedRecord], into context: ModelContext) throws {
    for model in SyncModel.applyOrder {
      for record in records where record.payload.model == model {
        try RecordCodec.upsert(
          record.payload, id: record.id, attachmentData: record.attachmentData, into: context)
      }
    }
  }

  private func hashes(_ records: [ExportedRecord]) throws -> [UUID: String] {
    Dictionary(uniqueKeysWithValues: try records.map { ($0.id, try RecordCodec.state(of: $0).payloadHash) })
  }

  @Test("FR-14/FR-15: Jedes der dreizehn Modelle hin und zurück ergibt dieselbe Prüfsumme")
  func roundTripKeepsHashForEveryModel() throws {
    let source = try makeContext()
    populate(source)
    let exported = try RecordCodec.exportAll(from: source)
    #expect(Set(exported.map(\.payload.model)) == Set(SyncModel.allCases))

    let target = try makeContext()
    try copy(exported, into: target)
    try target.save()
    let again = try RecordCodec.exportAll(from: target)

    #expect(try hashes(again) == hashes(exported))
    // Anhänge kommen byteweise zurück.
    let sourcePage = exported.first { $0.payload.model == .boardPage }
    let targetPage = again.first { $0.payload.model == .boardPage }
    #expect(sourcePage?.attachmentData == targetPage?.attachmentData)
    #expect(sourcePage?.attachmentData.keys.sorted() == ["backgroundImage", "drawing"])
  }

  @Test("Beziehungen kommen über die Kennung des Elterndatensatzes zurück")
  func relationsRestoredByParentID() throws {
    let source = try makeContext()
    let (timetable, link) = populate(source)
    let target = try makeContext()
    try copy(try RecordCodec.exportAll(from: source), into: target)
    try target.save()

    let entries = try target.fetch(FetchDescriptor<TimetableEntryRecord>())
    #expect(entries.first?.timetable?.id == timetable.id)
    let notes = try target.fetch(FetchDescriptor<PenNoteRecord>())
    #expect(notes.first?.materialLink?.id == link.id)
  }

  @Test("Planwoche und Leistungsnachweis kommen über die Kennung des Jahresplans zurück")
  func coursePlanChildrenRestoredByParentID() throws {
    let source = try makeContext()
    populate(source)
    let plan = try #require(try source.fetch(FetchDescriptor<CoursePlanRecord>()).first)
    let target = try makeContext()
    try copy(try RecordCodec.exportAll(from: source), into: target)
    try target.save()

    let weeks = try target.fetch(FetchDescriptor<PlanWeekRecord>())
    #expect(weeks.count == 1)
    #expect(weeks.first?.coursePlan?.id == plan.id)
    #expect(weeks.first?.topic == "Past Tense")
    let assessments = try target.fetch(FetchDescriptor<AssessmentRecord>())
    #expect(assessments.count == 1)
    #expect(assessments.first?.coursePlan?.id == plan.id)
    #expect(assessments.first?.kindRaw == "classTest")
    let year = try #require(try target.fetch(FetchDescriptor<SchoolYearRecord>()).first)
    #expect(year.makeSchoolYear()?.gradeOverrides == ["ef": 11])
  }

  @Test("Löschen eines Jahresplans nimmt Planwochen und Leistungsnachweise mit")
  func deletingCoursePlanCascades() throws {
    let context = try makeContext()
    populate(context)
    try context.save()
    let plan = try #require(try context.fetch(FetchDescriptor<CoursePlanRecord>()).first)
    try RecordCodec.delete(id: plan.id, model: .coursePlan, from: context)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<CoursePlanRecord>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<PlanWeekRecord>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<AssessmentRecord>()) == 0)
  }

  @Test("Kind ohne Eltern wirft missingParent")
  func childWithoutParentThrows() throws {
    let context = try makeContext()
    let missing = UUID()
    let entry = TimetableEntryPayload(
      createdAt: date, weekVariantRaw: nil, weekdayRaw: 1, period: 1, schoolClassText: "8b",
      subjectText: "Englisch", originRaw: "manual", isManuallyEdited: false, timetableID: missing)
    #expect(throws: RecordCodecError.missingParent(missing)) {
      try RecordCodec.upsert(.timetableEntry(entry), id: UUID(), attachmentData: [:], into: context)
    }
    #expect(try context.fetchCount(FetchDescriptor<TimetableEntryRecord>()) == 0)
  }

  @Test("Überschreiben nach id legt keinen zweiten Datensatz an")
  func upsertOverwritesByID() throws {
    let context = try makeContext()
    let id = UUID()
    let first = NonTeachingPeriodPayload(createdAt: date, fromText: "2026-12-21", toText: "2027-01-01", title: "Ferien")
    var second = first
    second.title = "Weihnachtsferien"
    try RecordCodec.upsert(.nonTeachingPeriod(first), id: id, attachmentData: [:], into: context)
    try context.save()
    try RecordCodec.upsert(.nonTeachingPeriod(second), id: id, attachmentData: [:], into: context)
    try context.save()

    let all = try context.fetch(FetchDescriptor<NonTeachingPeriodRecord>())
    #expect(all.count == 1)
    #expect(all.first?.title == "Weihnachtsferien")
    #expect(all.first?.id == id)
  }

  @Test("createdAt bleibt beim Übernehmen erhalten")
  func upsertKeepsCreatedAt() throws {
    let context = try makeContext()
    let payload = NonTeachingPeriodPayload(createdAt: date, fromText: "2026-12-21", toText: "2027-01-01", title: "Ferien")
    try RecordCodec.upsert(.nonTeachingPeriod(payload), id: UUID(), attachmentData: [:], into: context)
    let all = try context.fetch(FetchDescriptor<NonTeachingPeriodRecord>())
    #expect(all.first?.createdAt == date)
  }

  @Test("Fehlende Anhangsdaten werfen attachmentMissing")
  func missingAttachmentThrows() throws {
    let context = try makeContext()
    let note = PenNotePayload(
      createdAt: date, materialLinkID: nil, pageIndex: 0, drawing: AttachmentRef(hash: "00", byteCount: 1),
      pageWidth: 0, pageHeight: 0, updatedAt: date)
    #expect(throws: RecordCodecError.attachmentMissing("drawing")) {
      try RecordCodec.upsert(.penNote(note), id: UUID(), attachmentData: [:], into: context)
    }
  }

  @Test("Löschen nach id nimmt Stiftnotizen mit (Kaskade aus 02)")
  func deleteCascades() throws {
    let context = try makeContext()
    let (_, link) = populate(context)
    try context.save()
    try RecordCodec.delete(id: link.id, model: .materialLink, from: context)
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<MaterialLinkRecord>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<PenNoteRecord>()) == 0)
  }

  @Test("liveIDs liefert alle Kennungen")
  func liveIDsCoverAllModels() throws {
    let context = try makeContext()
    populate(context)
    try context.save()
    let exported = try RecordCodec.exportAll(from: context)
    #expect(try RecordCodec.liveIDs(in: context) == Set(exported.map(\.id)))
    #expect(exported.count == 13)
  }

  @Test("export(_:) liefert nur die genannten Datensätze")
  func exportByIdentifier() throws {
    let context = try makeContext()
    let (timetable, _) = populate(context)
    try context.save()
    let result = try RecordCodec.export([timetable.persistentModelID], from: context)
    #expect(result.map(\.id) == [timetable.id])
  }
}

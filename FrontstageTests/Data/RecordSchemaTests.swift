import Foundation
import SwiftData
import Testing

@testable import Frontstage

/// Liefert ein Bündel, das den Schlüssel `FrontstageCloudKitContainer` nicht trägt
/// (`Bundle(for:)` braucht eine Klasse; `Bundle.main` wäre im gehosteten Test die App).
private final class BundleToken {}

@MainActor @Suite struct RecordSchemaTests {
  @Test("Jedes Modell lässt sich mit Vorgabewerten anlegen und speichern")
  func everyRecordSavesWithDefaults() throws {
    let container = try ModelContainerFactory.makeInMemoryContainer()  // festhalten, solange der Kontext lebt
    let context = ModelContext(container)
    let link = MaterialLinkRecord()
    context.insert(TimetableRecord())
    context.insert(TimetableEntryRecord())
    context.insert(NonTeachingPeriodRecord())
    context.insert(ScheduleChangeRecord())
    context.insert(link)
    context.insert(PenNoteRecord(materialLink: link, pageIndex: 0))
    context.insert(LessonInfoRecord())
    context.insert(BoardPageRecord())
    context.insert(SchoolYearRecord())
    context.insert(CoursePlanRecord())
    context.insert(PlanWeekRecord())
    context.insert(AssessmentRecord())
    context.insert(ThemeRecord())
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<SchoolYearRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<CoursePlanRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<PlanWeekRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<AssessmentRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<TimetableRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<TimetableEntryRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<NonTeachingPeriodRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<ScheduleChangeRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<MaterialLinkRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<LessonInfoRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<BoardPageRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<PenNoteRecord>()) == 1)
    #expect(try context.fetchCount(FetchDescriptor<ThemeRecord>()) == 1)
  }

  @Test("Zuordnung löschen löscht ihre Stiftnotizen mit (Area anzeige, Stiftnotizen)")
  func deletingLinkCascadesToPenNotes() throws {
    let container = try ModelContainerFactory.makeInMemoryContainer()
    let context = ModelContext(container)
    let link = MaterialLinkRecord(dayText: "2026-11-17", displayName: "Beispiel.pdf")
    context.insert(link)
    context.insert(PenNoteRecord(materialLink: link, pageIndex: 0))
    context.insert(PenNoteRecord(materialLink: link, pageIndex: 1))
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<PenNoteRecord>()) == 2)

    context.delete(link)
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<MaterialLinkRecord>()) == 0)
    #expect(try context.fetchCount(FetchDescriptor<PenNoteRecord>()) == 0)
  }

  @Test("Stundenplan löschen löscht seine Einträge mit")
  func deletingTimetableCascadesToEntries() throws {
    let container = try ModelContainerFactory.makeInMemoryContainer()
    let context = ModelContext(container)
    let timetable = TimetableRecord(name: "Beispielplan", isActive: true)
    context.insert(timetable)
    context.insert(TimetableEntryRecord(weekdayRaw: 2, period: 2, schoolClassText: "8b", subjectText: "Englisch", timetable: timetable))
    context.insert(TimetableEntryRecord(weekdayRaw: 4, period: 3, schoolClassText: "8b", subjectText: "Englisch", timetable: timetable))
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<TimetableEntryRecord>()) == 2)

    context.delete(timetable)
    try context.save()
    #expect(try context.fetchCount(FetchDescriptor<TimetableEntryRecord>()) == 0)
  }

  @Test("Container-Kennung kommt aus der Info.plist, fehlt sie, gilt nil")
  func containerIdentifierFromBundle() {
    #expect(ModelContainerFactory.cloudKitContainerIdentifier(bundle: Bundle(for: BundleToken.self)) == nil)
  }
}

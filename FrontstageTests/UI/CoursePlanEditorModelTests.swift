import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Logik eines geöffneten Jahresplans (FR-15.2 bis FR-15.4).
@MainActor @Suite struct CoursePlanEditorModelTests {
  private let store = FakeCoursePlanStore()
  private let key = CoursePlanKey(
    subject: Subject("Englisch"), gradeLevel: GradeLevel(8)!, startYear: 2026)
  private let year = SchoolYear(
    firstDay: CalendarDay(year: 2026, month: 8, day: 3),
    secondTermStart: CalendarDay(year: 2027, month: 2, day: 1),
    lastDay: CalendarDay(year: 2027, month: 7, day: 30))
  private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

  /// Legt Schuljahr, Unterrichtswochen und einen leeren Plan an.
  private func makeModel() throws -> CoursePlanEditorModel {
    store.years = [year]
    store.weeks[2026] = TeachingWeekCalculator.weeks(of: year, nonTeachingPeriods: [])
    let id = try store.createCoursePlan(key)
    let now = fixedNow
    return CoursePlanEditorModel(planID: id, store: store, now: { now })
  }

  private func weekEntry(_ model: CoursePlanEditorModel, number: Int) -> PlanLayoutWeek? {
    ((model.layout?.first ?? []) + (model.layout?.second ?? [])).first { $0.week.number == number }
  }

  @Test("AK-47: Woche 8 bearbeiten → Thema, KA 1 am Di, Test ohne Tag, Notiz")
  func editsWeekEight() throws {
    let model = try makeModel()
    let week = try #require(weekEntry(model, number: 8)?.week)
    let tuesday = week.monday.adding(days: 1)
    let editor = model.editor(for: week)
    #expect(editor.selectableDays.contains(tuesday))

    editor.topic = "Present Perfect"
    editor.notes = "Vokabeln wiederholen"
    editor.save()
    editor.addAssessment(kind: .classTest, title: "KA 1", day: tuesday)
    editor.addAssessment(kind: .test, title: "Vokabeltest", day: nil)

    let entry = try #require(weekEntry(model, number: 8))
    #expect(entry.planWeek?.topic == "Present Perfect")
    #expect(entry.planWeek?.notes == "Vokabeln wiederholen")
    #expect(entry.assessments.map(\.title) == ["KA 1", "Vokabeltest"])
    #expect(entry.assessments.map(\.day) == [tuesday, nil])
    #expect(entry.assessments.map(\.kind) == [.classTest, .test])
    #expect(editor.assessments.count == 2)
  }

  @Test("Tag außerhalb der Unterrichtstage der Woche entfällt")
  func dropsDayOutsideWeek() throws {
    let model = try makeModel()
    let week = try #require(weekEntry(model, number: 8)?.week)
    let editor = model.editor(for: week)
    editor.addAssessment(kind: .test, title: "Test", day: week.monday.adding(days: 6))
    #expect(weekEntry(model, number: 8)?.assessments.first?.day == nil)
  }

  @Test("AK-47: Jahresnotiz bleibt gespeichert")
  func savesPlanNote() throws {
    let model = try makeModel()
    model.notes = "Lehrwerk Band 3, Kapitel 1 bis 6"
    model.saveNotes()
    let planID = try #require(try store.coursePlanSummaries().first?.id)
    let reopened = CoursePlanEditorModel(planID: planID, store: store)
    #expect(reopened.notes == "Lehrwerk Band 3, Kapitel 1 bis 6")
  }

  @Test("Neuladen während der Eingabe verwirft die ungespeicherte Jahresnotiz nicht")
  func reloadKeepsUnsavedNote() throws {
    let model = try makeModel()
    let planID = try #require(try store.coursePlanSummaries().first?.id)
    model.notes = "Entwurf"
    // Änderung vom anderen Gerät, während das Feld den Fokus hat.
    try store.setPlanNote("Fremder Stand", planID: planID)
    model.reload()
    #expect(model.notes == "Entwurf")
    model.saveNotes()
    #expect(try store.coursePlan(id: planID)?.notes == "Entwurf")
    // Nach dem Speichern übernimmt das Neuladen wieder den Stand vom anderen Gerät.
    try store.setPlanNote("Später", planID: planID)
    model.reload()
    #expect(model.notes == "Später")
  }

  @Test("Ohne eigene Eingabe übernimmt das Neuladen die Jahresnotiz vom anderen Gerät")
  func reloadTakesRemoteNote() throws {
    let model = try makeModel()
    let planID = try #require(try store.coursePlanSummaries().first?.id)
    try store.setPlanNote("Vom iPad", planID: planID)
    model.reload()
    #expect(model.notes == "Vom iPad")
    try store.setPlanNote("Wieder geändert", planID: planID)
    model.reload()
    #expect(model.notes == "Wieder geändert")
  }

  @Test("Unveränderte Jahresnotiz wird nicht erneut gespeichert")
  func unchangedNoteIsNotSaved() throws {
    let model = try makeModel()
    model.notes = "Lehrwerk Band 3"
    model.saveNotes()
    let revision = store.revision
    model.saveNotes()
    model.notes = "Lehrwerk Band 3  "
    model.saveNotes()
    #expect(store.revision == revision)
    #expect(model.notes == "Lehrwerk Band 3")
  }

  @Test("Sheet ohne Änderung schließen schreibt die Planwoche nicht neu")
  func unchangedWeekIsNotSaved() throws {
    let model = try makeModel()
    let week = try #require(weekEntry(model, number: 5)?.week)
    let first = model.editor(for: week)
    first.topic = "Unit 3"
    first.save()
    let stored = try #require(weekEntry(model, number: 5)?.planWeek)
    let revision = store.revision

    let reopened = model.editor(for: week)
    reopened.topic = " Unit 3 "
    reopened.save()
    #expect(store.revision == revision)
    #expect(weekEntry(model, number: 5)?.planWeek == stored)
  }

  @Test("Leere Woche ohne Eingabe schließen legt nichts an")
  func emptyWeekWithoutInputIsNotSaved() throws {
    let model = try makeModel()
    let week = try #require(weekEntry(model, number: 6)?.week)
    let revision = store.revision
    model.editor(for: week).save()
    #expect(store.revision == revision)
  }

  @Test("Planwoche ohne Montag: Leistungsnachweise lassen sich nicht eintragen")
  func unassignedWeekWithoutMondayCannotAddAssessment() throws {
    let model = try makeModel()
    let planID = try #require(try store.coursePlanSummaries().first?.id)
    let loose = PlanWeek(
      id: UUID(), monday: nil, position: 0, topic: "Projekt", notes: nil, updatedAt: fixedNow)
    try store.savePlanWeek(loose, planID: planID)
    model.reload()
    let editor = model.editor(forUnassigned: loose)
    #expect(!editor.canAddAssessments)
    editor.addAssessment(kind: .test, title: "Vokabeltest", day: nil)
    #expect(editor.assessments.isEmpty)
    #expect(try store.coursePlan(id: planID)?.assessments.isEmpty == true)
  }

  @Test("Speichern von Notizen überschreibt kein inzwischen geändertes Thema")
  func savingNotesKeepsRemoteTopic() throws {
    let model = try makeModel()
    let week = try #require(weekEntry(model, number: 5)?.week)
    let first = model.editor(for: week)
    first.topic = "Unit 3"
    first.save()
    let planID = try #require(try store.coursePlanSummaries().first?.id)
    let stored = try #require(weekEntry(model, number: 5)?.planWeek)
    let sheet = model.editor(for: week)
    // Das andere Gerät ändert das Thema, während das Sheet offen ist.
    let remote = PlanWeek(
      id: stored.id, monday: stored.monday, position: stored.position, topic: "Unit 4",
      notes: nil, updatedAt: fixedNow)
    try store.savePlanWeek(remote, planID: planID)
    sheet.notes = "Vokabeln"
    sheet.save()
    let plan = try #require(try store.coursePlan(id: planID))
    let result = try #require(plan.planWeeks.first { $0.id == stored.id })
    #expect(result.topic == "Unit 4")
    #expect(result.notes == "Vokabeln")
  }

  @Test("Zweimal Hinzufügen ohne Titel legt nur einen Platzhalter an")
  func blankPlaceholderIsNotDuplicated() throws {
    let model = try makeModel()
    let week = try #require(weekEntry(model, number: 8)?.week)
    let editor = model.editor(for: week)
    editor.addAssessment(kind: .test, title: "", day: nil)
    editor.addAssessment(kind: .test, title: "", day: nil)
    #expect(editor.assessments.count == 1)
    editor.addAssessment(kind: .classTest, title: "", day: nil)
    #expect(editor.assessments.count == 2)
  }

  @Test("AK-49: Übernehmen meldet die Zahl der nicht zugeordneten Einträge")
  func copyReportsUnassignedCount() throws {
    let model = try makeModel()
    let monday = CalendarDay(year: 2025, month: 8, day: 4)
    let sourceWeek = TeachingWeek(
      number: 1, monday: monday, isoWeek: monday.isoWeek, term: .first, teachingDays: [monday])
    let source = PlanWeek(
      id: UUID(), monday: monday, position: 0, topic: "Unit 1", notes: nil, updatedAt: fixedNow)
    // Zielwochen fehlen → die übernommene Planwoche bleibt ohne Woche.
    store.copyResult = CoursePlanCopier.copy(
      sourceWeeks: [sourceWeek], sourcePlanWeeks: [source], sourceAssessments: [], sourceNote: nil,
      targetWeeks: [], targetPlanWeeks: [], targetAssessments: [], targetNote: nil,
      nextUnassignedPosition: 0, now: fixedNow, makeID: { UUID() })
    model.copy(from: UUID())
    #expect(model.noticeKey == "coursePlan.copy.done %lld")
    #expect(model.noticeArgument == 1)
  }

  @Test("Zuweisen bietet nur leere Wochen an")
  func emptyWeeksOnlyOffersFreeWeeks() throws {
    let model = try makeModel()
    let all = model.emptyWeeks()
    let week = try #require(weekEntry(model, number: 8)?.week)
    #expect(all.contains(week))
    let editor = model.editor(for: week)
    editor.topic = "Unit 2"
    editor.save()
    let free = model.emptyWeeks()
    #expect(!free.contains(week))
    #expect(free.count == all.count - 1)
  }

  @Test("AK-45: Kopf zeigt gilt für 8a, 8b")
  func followingClasses() throws {
    store.followers[key] = [SchoolClass("8a"), SchoolClass("8b")]
    let model = try makeModel()
    #expect(model.followingClasses == [SchoolClass("8a"), SchoolClass("8b")])
    #expect(model.key == key)
  }

  @Test("Thema leeren und speichern löscht die Planwoche")
  func clearingWeekDeletesIt() throws {
    let model = try makeModel()
    let week = try #require(weekEntry(model, number: 3)?.week)
    let editor = model.editor(for: week)
    editor.topic = "Unit 1"
    editor.save()
    #expect(weekEntry(model, number: 3)?.planWeek != nil)
    editor.topic = ""
    editor.notes = ""
    editor.save()
    #expect(weekEntry(model, number: 3)?.planWeek == nil)
  }

  @Test("Frühere Jahre desselben Fachs und Jahrgangs, neuestes zuerst")
  func listsEarlierPlans() throws {
    let older = try store.createCoursePlan(
      CoursePlanKey(subject: Subject("englisch"), gradeLevel: GradeLevel(8)!, startYear: 2024))
    let old = try store.createCoursePlan(
      CoursePlanKey(subject: Subject("Englisch"), gradeLevel: GradeLevel(8)!, startYear: 2025))
    _ = try store.createCoursePlan(
      CoursePlanKey(subject: Subject("Mathematik"), gradeLevel: GradeLevel(8)!, startYear: 2025))
    let model = try makeModel()
    #expect(model.earlierPlans.map(\.id) == [old, older])
  }
}

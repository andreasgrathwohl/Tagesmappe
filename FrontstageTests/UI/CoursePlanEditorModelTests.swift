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

  @Test("AK-47: Jahresnotiz bleibt nach reload")
  func savesPlanNote() throws {
    let model = try makeModel()
    model.notes = "Lehrwerk Band 3, Kapitel 1 bis 6"
    model.saveNotes()
    model.notes = ""
    model.reload()
    #expect(model.notes == "Lehrwerk Band 3, Kapitel 1 bis 6")
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

import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

private func cd(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
  CalendarDay(year: year, month: month, day: day)
}

private func year2026() -> SchoolYear {
  SchoolYear(firstDay: cd(2026, 9, 14), secondTermStart: cd(2027, 2, 1), lastDay: cd(2027, 7, 28))
}

private func year2025() -> SchoolYear {
  SchoolYear(firstDay: cd(2025, 9, 15), secondTermStart: cd(2026, 2, 2), lastDay: cd(2026, 7, 29))
}

private let english8of2026 = CoursePlanKey(
  subject: Subject("Englisch"), gradeLevel: GradeLevel(8)!, startYear: 2026)
private let english8of2025 = CoursePlanKey(
  subject: Subject("Englisch"), gradeLevel: GradeLevel(8)!, startYear: 2025)

/// Schuljahre 2025/26 und 2026/27 mit den Herbstferien und den Weihnachtsferien der Testdaten.
@MainActor private func seedYearsAndHolidays(_ store: DataStore) throws {
  try store.saveSchoolYear(year2025())
  try store.saveSchoolYear(year2026())
  for period in [
    NonTeachingPeriod(from: cd(2025, 10, 27), to: cd(2025, 10, 31), title: "Herbstferien"),
    NonTeachingPeriod(from: cd(2026, 11, 2), to: cd(2026, 11, 6), title: "Herbstferien"),
    NonTeachingPeriod(from: cd(2026, 12, 23), to: cd(2027, 1, 9), title: "Weihnachtsferien"),
  ] {
    try store.addNonTeachingPeriod(period)
  }
}

private func entry(_ weekday: Weekday, _ period: Int, _ schoolClass: String, _ subject: String)
  -> TimetableEntry
{
  TimetableEntry(
    weekday: weekday, period: period, schoolClass: SchoolClass(schoolClass), subject: Subject(subject))
}

private func lesson(_ day: CalendarDay, _ schoolClass: String, _ subject: String) -> Lesson {
  Lesson(
    key: LessonKey(
      date: day, schoolClass: SchoolClass(schoolClass), subject: Subject(subject), ordinal: 1),
    period: 1, time: nil, isSubstituteLesson: false, isCancelled: false, cancellationOrigin: nil)
}

private func planWeek(_ monday: CalendarDay?, topic: String?, position: Int = 0) -> PlanWeek {
  PlanWeek(
    id: UUID(), monday: monday, position: position, topic: topic, notes: nil,
    updatedAt: Date(timeIntervalSince1970: 0))
}

private func assessment(
  _ monday: CalendarDay?, day: CalendarDay? = nil, kind: AssessmentKind = .classTest,
  title: String = "KA 1"
) -> Assessment {
  Assessment(
    id: UUID(), monday: monday, day: day, kind: kind, title: title,
    updatedAt: Date(timeIntervalSince1970: 0))
}

@MainActor @Suite struct CoursePlanStoreTests {
  @Test("AK-45: ein Plan für Englisch 8 2026/27, zweites Anlegen liefert dieselbe id")
  func createIsIdempotentPerKey() throws {
    let store = try makeStore()
    let first = try store.createCoursePlan(english8of2026)
    let revision = store.revision
    let second = try store.createCoursePlan(
      CoursePlanKey(subject: Subject(" englisch "), gradeLevel: GradeLevel(8)!, startYear: 2026))
    #expect(first == second)
    #expect(store.revision == revision)
    #expect(try store.coursePlanSummaries().map(\.id) == [first])
  }

  @Test("AK-45: gilt für 8a und 8b, nicht für 7a")
  func classesFollowingPlan() throws {
    let store = try makeStore()
    try store.saveSchoolYear(year2026())
    for e in [
      entry(.tuesday, 2, "8a", "Englisch"), entry(.wednesday, 3, "8b", "Englisch"),
      entry(.thursday, 1, "7a", "Englisch"), entry(.friday, 4, "8b", "Mathe"),
    ] {
      try store.addEntry(e)
    }
    #expect(
      try store.classes(following: english8of2026) == [SchoolClass("8a"), SchoolClass("8b")])
    #expect(try store.timetableClasses().count == 3)
    #expect(try store.timetableSubjects().map(\.normalized) == ["englisch", "mathe"])
  }

  @Test("AK-46: 43 Unterrichtswochen aus Schuljahr und Ferien des Stores")
  func teachingWeeksFromStore() throws {
    let store = try makeStore()
    try seedYearsAndHolidays(store)
    let weeks = try store.teachingWeeks(startYear: 2026)
    #expect(weeks.count == 43)
    #expect(weeks.filter { $0.term == .first }.count == 17)
    #expect(weeks.filter { $0.term == .second }.count == 26)
    #expect(try store.teachingWeeks(startYear: 2025).count == 45)
    #expect(try store.teachingWeeks(startYear: 2030).isEmpty)
  }

  @Test("Schuljahr mit Überschneidung wird abgelehnt")
  func overlappingSchoolYearThrows() throws {
    let store = try makeStore()
    try store.saveSchoolYear(year2026())
    let overlapping = SchoolYear(
      firstDay: cd(2027, 7, 1), secondTermStart: cd(2028, 2, 1), lastDay: cd(2028, 7, 26))
    #expect(throws: CoursePlanError.invalidSchoolYear(.overlaps(startYear: 2026))) {
      try store.saveSchoolYear(overlapping)
    }
    #expect(try store.schoolYears().map(\.startYear) == [2026])
  }

  @Test("Schuljahr gleichen Startjahres wird ersetzt, nicht doppelt gespeichert")
  func savingSameStartYearReplaces() throws {
    let store = try makeStore()
    try store.saveSchoolYear(year2026())
    var changed = year2026()
    changed.lastDay = cd(2027, 7, 30)
    try store.saveSchoolYear(changed)
    #expect(try store.schoolYears() == [changed])
  }

  @Test("AK-47: Ferien ändern → Einträge unter nicht zugeordnet, nichts gelöscht")
  func holidayChangeKeepsEntries() throws {
    let store = try makeStore()
    try seedYearsAndHolidays(store)
    let planID = try store.createCoursePlan(english8of2026)
    let monday = cd(2026, 11, 16)
    try store.savePlanWeek(planWeek(monday, topic: "Unit 2 – Past tense"), planID: planID)
    try store.saveAssessment(assessment(monday, day: cd(2026, 11, 17)), planID: planID)

    func layout() throws -> PlanLayout {
      let content = try #require(try store.coursePlan(id: planID))
      return PlanLayouter.layout(
        weeks: try store.teachingWeeks(startYear: 2026), planWeeks: content.planWeeks,
        assessments: content.assessments)
    }
    #expect(try layout().unassignedWeeks.isEmpty)
    #expect(try layout().unassignedAssessments.isEmpty)

    try store.addNonTeachingPeriod(
      NonTeachingPeriod(from: cd(2026, 11, 16), to: cd(2026, 11, 20), title: "Studienwoche"))
    let after = try layout()
    #expect(after.unassignedWeeks.count == 1)
    #expect(after.unassignedWeeks.first?.topic == "Unit 2 – Past tense")
    #expect(after.unassignedAssessments.count == 1)
    let content = try #require(try store.coursePlan(id: planID))
    #expect(content.planWeeks.count == 1)
    #expect(content.assessments.count == 1)
  }

  @Test("Leere Planwoche wird gelöscht")
  func emptyPlanWeekIsDeleted() throws {
    let store = try makeStore()
    try seedYearsAndHolidays(store)
    let planID = try store.createCoursePlan(english8of2026)
    var week = planWeek(cd(2026, 11, 9), topic: "Unit 1 – Back to school")
    try store.savePlanWeek(week, planID: planID)
    #expect(try store.coursePlan(id: planID)?.planWeeks.count == 1)

    week.topic = nil
    try store.savePlanWeek(week, planID: planID)
    #expect(try store.coursePlan(id: planID)?.planWeeks.isEmpty == true)

    // Eine neue leere Planwoche wird gar nicht erst gespeichert.
    let revision = store.revision
    try store.savePlanWeek(planWeek(cd(2026, 11, 16), topic: "  "), planID: planID)
    #expect(store.revision == revision)
    #expect(try store.coursePlan(id: planID)?.planWeeks.isEmpty == true)
  }

  @Test("Zuweisen in belegte Woche wirft weekOccupied")
  func assignToOccupiedWeekThrows() throws {
    let store = try makeStore()
    try seedYearsAndHolidays(store)
    let planID = try store.createCoursePlan(english8of2026)
    let occupied = planWeek(cd(2026, 11, 16), topic: "Unit 2 – Past tense")
    let loose = planWeek(nil, topic: "Projekt Schulfest")
    try store.savePlanWeek(occupied, planID: planID)
    try store.savePlanWeek(loose, planID: planID)

    #expect(throws: CoursePlanError.weekOccupied) {
      try store.assignPlanWeek(id: loose.id, to: cd(2026, 11, 16))
    }
    try store.assignPlanWeek(id: loose.id, to: cd(2026, 11, 23))
    let content = try #require(try store.coursePlan(id: planID))
    #expect(content.planWeeks.first { $0.id == loose.id }?.monday == cd(2026, 11, 23))
    #expect(content.planWeeks.first { $0.id == occupied.id }?.monday == cd(2026, 11, 16))
  }

  @Test("Tag außerhalb der Woche wirft dayNotInWeek")
  func assessmentDayOutsideWeekThrows() throws {
    let store = try makeStore()
    try seedYearsAndHolidays(store)
    let planID = try store.createCoursePlan(english8of2026)
    let monday = cd(2026, 11, 16)

    #expect(throws: CoursePlanError.dayNotInWeek) {
      try store.saveAssessment(assessment(monday, day: cd(2026, 11, 23)), planID: planID)
    }
    #expect(throws: CoursePlanError.dayNotInWeek) {  // Samstag
      try store.saveAssessment(assessment(monday, day: cd(2026, 11, 21)), planID: planID)
    }
    #expect(try store.coursePlan(id: planID)?.assessments.isEmpty == true)

    let valid = assessment(monday, day: cd(2026, 11, 18))
    try store.saveAssessment(valid, planID: planID)
    #expect(try store.coursePlan(id: planID)?.assessments.map(\.id) == [valid.id])
  }

  @Test("Leistungsnachweis zuweisen behält den Wochentag und lässt sich entfernen")
  func assignAndRemoveAssessment() throws {
    let store = try makeStore()
    try seedYearsAndHolidays(store)
    let planID = try store.createCoursePlan(english8of2026)
    let ka = assessment(cd(2026, 11, 16), day: cd(2026, 11, 18))
    try store.saveAssessment(ka, planID: planID)
    let target = try #require(
      try store.teachingWeeks(startYear: 2026).first { $0.monday == cd(2026, 11, 23) })
    try store.assignAssessment(id: ka.id, to: target)
    let moved = try #require(try store.coursePlan(id: planID)?.assessments.first)
    #expect(moved.monday == cd(2026, 11, 23))
    #expect(moved.day == cd(2026, 11, 25))
    try store.removeAssessment(id: ka.id)
    #expect(try store.coursePlan(id: planID)?.assessments.isEmpty == true)
  }

  @Test("AK-49: Übernehmen aus 2025/26 legt Einträge an, Quelle unverändert")
  func copyLeavesSourceUntouched() throws {
    let store = try makeStore()
    try seedYearsAndHolidays(store)
    let sourceID = try store.createCoursePlan(english8of2025)
    let targetID = try store.createCoursePlan(english8of2026)
    try store.setPlanNote("Lektüre ab Unit 3", planID: sourceID)
    try store.savePlanWeek(planWeek(cd(2025, 9, 15), topic: "Unit 1 – Back to school"), planID: sourceID)
    try store.saveAssessment(
      assessment(cd(2025, 9, 15), day: cd(2025, 9, 17), kind: .test, title: "Vokabeltest Unit 2"),
      planID: sourceID)
    let before = try #require(try store.coursePlan(id: sourceID))

    let result = try store.copyCoursePlan(from: sourceID, to: targetID)

    #expect(result.planWeeks.count == 1)
    #expect(result.assessments.count == 1)
    #expect(result.unassignedCount == 0)
    let target = try #require(try store.coursePlan(id: targetID))
    #expect(target.planWeeks.map(\.topic) == ["Unit 1 – Back to school"])
    #expect(target.planWeeks.first?.monday == cd(2026, 9, 14))
    #expect(target.assessments.first?.monday == cd(2026, 9, 14))
    #expect(target.assessments.first?.day == cd(2026, 9, 16))
    #expect(target.notes == "Lektüre ab Unit 3")
    #expect(try store.coursePlan(id: sourceID) == before)
  }

  @Test("Übernehmen ohne Schuljahr der Quelle wirft schoolYearMissing")
  func copyWithoutSchoolYearThrows() throws {
    let store = try makeStore()
    try store.saveSchoolYear(year2026())
    let sourceID = try store.createCoursePlan(english8of2025)
    let targetID = try store.createCoursePlan(english8of2026)
    #expect(throws: CoursePlanError.schoolYearMissing(startYear: 2025)) {
      try store.copyCoursePlan(from: sourceID, to: targetID)
    }
  }

  @Test("Schreiben in einen fehlenden Plan wirft planMissing")
  func missingPlanThrows() throws {
    let store = try makeStore()
    let unknown = UUID()
    #expect(throws: CoursePlanError.planMissing(unknown)) {
      try store.setPlanNote("x", planID: unknown)
    }
  }

  @Test("Schuljahr löschen lässt Jahrespläne stehen")
  func removingSchoolYearKeepsPlans() throws {
    let store = try makeStore()
    try seedYearsAndHolidays(store)
    let planID = try store.createCoursePlan(english8of2026)
    try store.savePlanWeek(planWeek(cd(2026, 11, 9), topic: "Unit 2 – Past tense"), planID: planID)
    try store.removeSchoolYear(startYear: 2026)
    #expect(try store.schoolYears().map(\.startYear) == [2025])
    #expect(try store.teachingWeeks(startYear: 2026).isEmpty)
    #expect(try store.coursePlanSummaries().map(\.id) == [planID])
    #expect(try store.coursePlan(id: planID)?.planWeeks.count == 1)
  }

  @Test("Hand-Jahrgang für ef macht den Plan Jahrgang 11 zuständig")
  func gradeOverrideApplies() throws {
    let store = try makeStore()
    try seedYearsAndHolidays(store)
    try store.addEntry(entry(.tuesday, 2, "ef", "Englisch"))
    let key = CoursePlanKey(
      subject: Subject("Englisch"), gradeLevel: GradeLevel(11)!, startYear: 2026)
    let planID = try store.createCoursePlan(key)
    try store.savePlanWeek(planWeek(cd(2026, 11, 9), topic: "Projekt Schulfest"), planID: planID)
    let efLesson = lesson(cd(2026, 11, 10), "ef", "Englisch")

    #expect(try store.lessonPlanHint(for: efLesson) == nil)
    #expect(try store.classes(following: key).isEmpty)

    try store.setGradeOverride(GradeLevel(11), for: SchoolClass("ef"), startYear: 2026)
    #expect(try store.lessonPlanHint(for: efLesson)?.plannedTopic == "Projekt Schulfest")
    #expect(try store.classes(following: key) == [SchoolClass("ef")])

    try store.setGradeOverride(nil, for: SchoolClass("ef"), startYear: 2026)
    #expect(try store.lessonPlanHint(for: efLesson) == nil)
    #expect(throws: CoursePlanError.schoolYearMissing(startYear: 2030)) {
      try store.setGradeOverride(GradeLevel(11), for: SchoolClass("ef"), startYear: 2030)
    }
  }

  @Test("AK-50: Hinweis für 8a Englisch am 10.11.2026")
  func lessonPlanHintFromStore() throws {
    let store = try makeStore()
    try seedYearsAndHolidays(store)
    let planID = try store.createCoursePlan(english8of2026)
    let monday = cd(2026, 11, 9)
    try store.savePlanWeek(planWeek(monday, topic: "Unit 2 – Past tense"), planID: planID)
    try store.saveAssessment(assessment(monday, day: cd(2026, 11, 10)), planID: planID)
    try store.saveAssessment(
      assessment(monday, kind: .test, title: "Vokabeltest Unit 2"), planID: planID)

    let hint = try #require(try store.lessonPlanHint(for: lesson(cd(2026, 11, 10), "8a", "Englisch")))
    #expect(hint.coursePlanID == planID)
    #expect(hint.plannedTopic == "Unit 2 – Past tense")
    #expect(hint.markers.map(\.timing) == [.onDay, .thisWeek])
    #expect(hint.markers.map(\.assessment.title) == ["KA 1", "Vokabeltest Unit 2"])

    #expect(try store.lessonPlanHint(for: lesson(cd(2026, 11, 10), "8a", "Mathe")) == nil)
    let week = try store.plannedAssessments(inWeekOf: monday)
    #expect(week.map(\.assessment.title) == ["KA 1", "Vokabeltest Unit 2"])
    #expect(try store.plannedAssessments(inWeekOf: cd(2026, 11, 16)).isEmpty)
  }
}

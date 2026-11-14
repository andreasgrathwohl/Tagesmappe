import Foundation
import Testing

@testable import FrontstageCore

@Suite("CoursePlan Hint") struct LessonPlanHintTests {
  @Test("AK-50/AK-51: 8a Englisch am Di 10.11.2026")
  func hintForLesson() {
    let hint = LessonPlanHinter.hint(
      for: lesson(d(2026, 11, 10), "8a", "Englisch"), schoolYears: [year2026()],
      plans: [english8With(kaOn: d(2026, 11, 10))])
    #expect(hint?.plannedTopic == "Unit 2 – Past tense")
    #expect(hint?.markers.map(\.assessment.title) == ["KA 1", "Vokabeltest Unit 2"])
    #expect(hint?.markers.map(\.timing) == [.onDay, .thisWeek])
  }

  @Test("AK-51: Do 8b sieht nur den Test der Woche")
  func otherDayShowsOnlyWeekMarker() {
    let hint = LessonPlanHinter.hint(
      for: lesson(d(2026, 11, 12), "8b", "Englisch"), schoolYears: [year2026()],
      plans: [english8With(kaOn: d(2026, 11, 10))])
    #expect(hint?.markers.map(\.assessment.title) == ["Vokabeltest Unit 2"])
    #expect(hint?.markers.map(\.timing) == [.thisWeek])
  }

  @Test("AK-50: 7a Englisch und 8a Mathe bekommen keinen Hinweis")
  func otherGradeOrSubjectHasNoHint() {
    let plans = [english8With(kaOn: d(2026, 11, 10))]
    #expect(
      LessonPlanHinter.hint(
        for: lesson(d(2026, 11, 10), "7a", "Englisch"), schoolYears: [year2026()], plans: plans)
        == nil)
    #expect(
      LessonPlanHinter.hint(
        for: lesson(d(2026, 11, 10), "8a", "Mathe"), schoolYears: [year2026()], plans: plans)
        == nil)
  }

  @Test("Fach normalisiert: „englisch“ findet „Englisch“")
  func subjectMatchesNormalized() {
    let hint = LessonPlanHinter.hint(
      for: lesson(d(2026, 11, 10), "8a", "englisch"), schoolYears: [year2026()],
      plans: [english8With(kaOn: nil)])
    #expect(hint?.plannedTopic == "Unit 2 – Past tense")
  }

  @Test("Klasse ohne Ziffern: mit Hand-Jahrgang Plan 11, ohne keiner")
  func classWithoutDigitsUsesOverrideOrNothing() {
    let plan = english8With(kaOn: nil)
    let plan11 = CoursePlanSnapshotEntry(
      id: plan.id,
      key: CoursePlanKey(subject: plan.key.subject, gradeLevel: GradeLevel(11)!, startYear: 2026),
      planWeeks: plan.planWeeks, assessments: plan.assessments)
    var withOverride = year2026()
    withOverride.gradeOverrides = ["leistungskurs": 11]
    let stunde = lesson(d(2026, 11, 10), "Leistungskurs", "Englisch")
    #expect(
      LessonPlanHinter.hint(for: stunde, schoolYears: [withOverride], plans: [plan11])?.plannedTopic
        == "Unit 2 – Past tense")
    #expect(LessonPlanHinter.hint(for: stunde, schoolYears: [year2026()], plans: [plan11]) == nil)
  }

  @Test("Ausfall und Datum außerhalb jedes Schuljahrs: kein Hinweis")
  func cancelledOrOutsideHasNoHint() {
    let plans = [english8With(kaOn: d(2026, 11, 10))]
    #expect(
      LessonPlanHinter.hint(
        for: lesson(d(2026, 11, 10), "8a", "Englisch", cancelled: true),
        schoolYears: [year2026()], plans: plans) == nil)
    #expect(
      LessonPlanHinter.hint(
        for: lesson(d(2026, 8, 3), "8a", "Englisch"), schoolYears: [year2026()], plans: plans)
        == nil)
  }

  @Test("Woche ohne Thema und ohne Leistungsnachweis: nil")
  func emptyWeekIsNil() {
    // Woche ab 16.11.2026: im Plan steht dort nichts.
    #expect(
      LessonPlanHinter.hint(
        for: lesson(d(2026, 11, 17), "8a", "Englisch"), schoolYears: [year2026()],
        plans: [english8With(kaOn: d(2026, 11, 10))]) == nil)
  }

  @Test("Leistungsnachweise der Woche für Vorbereiten")
  func weekAssessments() {
    let result = LessonPlanHinter.assessments(
      inWeekOf: d(2026, 11, 9), plans: [english8With(kaOn: d(2026, 11, 10))])
    #expect(result.map(\.assessment.title) == ["KA 1", "Vokabeltest Unit 2"])
    #expect(
      LessonPlanHinter.assessments(inWeekOf: d(2026, 11, 16), plans: [english8With(kaOn: nil)])
        .isEmpty)
  }
}

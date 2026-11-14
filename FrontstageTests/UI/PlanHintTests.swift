import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Wochenthema und Leistungsnachweise in Tagesansicht und Vorbereiten (FR-15.5, FR-15.6).
@MainActor @Suite struct PlanHintTests {
  private let data: DataStore
  private let storage = FakeStorage()

  private static let tue10 = CalendarDay(year: 2026, month: 11, day: 10)
  private static let thu12 = CalendarDay(year: 2026, month: 11, day: 12)
  private static let monday9 = CalendarDay(year: 2026, month: 11, day: 9)

  /// Schuljahr 2026/27, Stundenplan wie in AK-51 und ein Plan Englisch 8 wie in AK-47.
  init() throws {
    data = try makeStore()
    try data.saveSchoolYear(
      SchoolYear(
        firstDay: CalendarDay(year: 2026, month: 9, day: 14),
        secondTermStart: CalendarDay(year: 2027, month: 2, day: 1),
        lastDay: CalendarDay(year: 2027, month: 7, day: 28)))
    try Fixtures.seed(
      data,
      [
        Fixtures.entry(.tuesday, 2, "8a", "Englisch"), Fixtures.entry(.thursday, 3, "8b", "Englisch"),
        Fixtures.entry(.tuesday, 4, "8a", "Mathe"), Fixtures.entry(.tuesday, 5, "7a", "Englisch"),
      ])
    let planID = try data.createCoursePlan(
      CoursePlanKey(subject: Subject("Englisch"), gradeLevel: GradeLevel(8)!, startYear: 2026))
    let stamp = Date(timeIntervalSince1970: 0)
    try data.savePlanWeek(
      PlanWeek(
        id: UUID(), monday: Self.monday9, position: 0, topic: "Unit 2 – Past tense", notes: nil,
        updatedAt: stamp),
      planID: planID)
    try data.saveAssessment(
      Assessment(
        id: UUID(), monday: Self.monday9, day: Self.tue10, kind: .classTest, title: "KA 1",
        updatedAt: stamp),
      planID: planID)
    try data.saveAssessment(
      Assessment(
        id: UUID(), monday: Self.monday9, day: nil, kind: .test, title: "Vokabeltest Unit 2",
        updatedAt: stamp),
      planID: planID)
  }

  private func dayModel(_ day: CalendarDay) -> DayViewModel {
    DayViewModel(environment: Fixtures.environment(store: data, storage: storage, today: day))
  }

  private func lessonRows(_ model: DayViewModel) -> [LessonRow] {
    guard case .rows(let rows) = model.content else { return [] }
    return rows.compactMap { row in
      if case .lesson(let lesson) = row { return lesson }
      return nil
    }
  }

  private func row(_ model: DayViewModel, _ schoolClass: String, _ subject: String) throws -> LessonRow {
    try #require(
      lessonRows(model).first {
        $0.lesson.key.schoolClass == SchoolClass(schoolClass) && $0.lesson.key.subject == Subject(subject)
      })
  }

  @Test("AK-51: Tagesansicht Di 10.11. – 8a Englisch mit KA 1 und Test, 8a Mathe ohne")
  func dayRowsCarryMarkers() throws {
    let model = dayModel(Self.tue10)
    let english = try row(model, "8a", "Englisch")
    let hint = try #require(english.planHint)
    #expect(hint.markers.map(\.assessment.title) == ["KA 1", "Vokabeltest Unit 2"])
    #expect(hint.markers.map(\.timing) == [.onDay, .thisWeek])
    #expect(hint.markers.map(\.assessment.kind) == [.classTest, .test])
    #expect(try row(model, "8a", "Mathe").planHint == nil)
  }

  @Test("AK-51: Do 12.11. – 8b nur der Test der Woche")
  func thursdayShowsWeekMarkerOnly() throws {
    let model = dayModel(Self.thu12)
    let hint = try #require(try row(model, "8b", "Englisch").planHint)
    #expect(hint.markers.map(\.assessment.title) == ["Vokabeltest Unit 2"])
    #expect(hint.markers.map(\.timing) == [.thisWeek])
  }

  @Test("AK-51: Vorbereiten-Woche ab 9.11. listet beide Leistungsnachweise")
  func preparationWeekListsAssessments() {
    let model = PreparationViewModel(
      environment: Fixtures.environment(store: data, storage: storage, today: Self.tue10))
    #expect(model.weekStart == Self.monday9)
    #expect(model.weekAssessments.map(\.assessment.title) == ["KA 1", "Vokabeltest Unit 2"])
    model.showNextWeek()
    #expect(model.weekAssessments.isEmpty)
  }

  @Test("AK-50: Vorschlag übernehmen schreibt das Thema, ohne Tipp bleibt es leer")
  func suggestionWritesTopicOnlyOnTap() throws {
    let model = dayModel(Self.tue10)
    let english = try row(model, "8a", "Englisch")
    #expect(english.planHint?.plannedTopic == "Unit 2 – Past tense")

    let editor = LessonInfoEditor(key: english.lesson.key, store: data)
    #expect(try data.lessonInfo(for: english.lesson.key).topic == nil)

    // „Als Thema übernehmen“
    editor.topic = try #require(english.planHint?.plannedTopic)
    editor.save()
    #expect(try data.lessonInfo(for: english.lesson.key).topic == "Unit 2 – Past tense")
  }

  @Test("AK-50: 7a bekommt keinen Vorschlag")
  func noSuggestionForOtherGrade() throws {
    let model = dayModel(Self.tue10)
    #expect(try row(model, "7a", "Englisch").planHint == nil)
  }

  @Test("Ausfall trägt keinen Hinweis")
  func cancelledLessonHasNoHint() throws {
    let key = Fixtures.key(Self.tue10, "8a", "Englisch")
    try data.markCancelled(key)
    let model = dayModel(Self.tue10)
    let english = try row(model, "8a", "Englisch")
    #expect(english.status == .cancelled(.manual))
    #expect(english.planHint == nil)
  }
}

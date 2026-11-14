import FrontstageCore
import Testing

@testable import Frontstage

/// Liste der Jahrespläne (FR-15.2).
@MainActor @Suite struct CoursePlanListModelTests {
  private let store = FakeCoursePlanStore()
  private let today = CalendarDay(year: 2026, month: 9, day: 10)

  private func year(_ start: Int) -> SchoolYear {
    SchoolYear(
      firstDay: CalendarDay(year: start, month: 8, day: 3),
      secondTermStart: CalendarDay(year: start + 1, month: 2, day: 2),
      lastDay: CalendarDay(year: start + 1, month: 7, day: 30))
  }

  private func key(_ subject: String, _ grade: Int, _ start: Int) -> CoursePlanKey {
    CoursePlanKey(subject: Subject(subject), gradeLevel: GradeLevel(grade)!, startYear: start)
  }

  @Test("Laufendes Schuljahr zuerst, dann neuere, dann ältere")
  func groupsCurrentYearFirst() throws {
    store.years = [year(2025), year(2026), year(2027)]
    for start in [2024, 2025, 2026, 2027] { _ = try store.createCoursePlan(key("Englisch", 8, start)) }
    let model = CoursePlanListModel(store: store, today: today)
    #expect(model.groups.map(\.title) == ["2026/27", "2027/28", "2025/26", "2024/25"])
    #expect(model.hasSchoolYear)
  }

  @Test("Ohne Schuljahr: hasSchoolYear false")
  func withoutSchoolYear() {
    let model = CoursePlanListModel(store: store, today: today)
    #expect(!model.hasSchoolYear)
    #expect(model.groups.isEmpty)
    #expect(model.newPlanOptions().startYears.isEmpty)
  }

  @Test("Neuer Plan mit vorhandenem Schlüssel wählt den vorhandenen")
  func createSelectsExisting() throws {
    store.years = [year(2026)]
    let existing = try store.createCoursePlan(key("Englisch", 8, 2026))
    let model = CoursePlanListModel(store: store, today: today)
    model.create(subject: Subject("englisch"), grade: GradeLevel(8)!, startYear: 2026)
    #expect(model.selection == existing)
    #expect(model.groups.first?.plans.count == 1)
  }

  @Test("Vorschläge: Fächer, Jahrgänge (auch von Hand) und Schuljahre")
  func offersOptions() {
    var manual = year(2026)
    manual.gradeOverrides["q"] = 11
    store.years = [manual]
    store.subjects = [Subject("Englisch")]
    store.classes = [SchoolClass("8a"), SchoolClass("8b"), SchoolClass("q")]
    let options = CoursePlanListModel(store: store, today: today).newPlanOptions()
    #expect(options.subjects == [Subject("Englisch")])
    #expect(options.grades.map(\.value) == [8, 11])
    #expect(options.startYears == [2026])
  }
}

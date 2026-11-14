import FrontstageCore
import Testing

@testable import Frontstage

/// „Einrichten › Schuljahre“ (FR-15.1).
@MainActor @Suite struct SchoolYearSettingsModelTests {
  private let store = FakeCoursePlanStore()
  private let today = CalendarDay(year: 2026, month: 9, day: 10)

  private func year(_ start: Int) -> SchoolYear {
    SchoolYear(
      firstDay: CalendarDay(year: start, month: 8, day: 3),
      secondTermStart: CalendarDay(year: start + 1, month: 2, day: 2),
      lastDay: CalendarDay(year: start + 1, month: 7, day: 30))
  }

  private func makeModel() -> SchoolYearSettingsModel {
    SchoolYearSettingsModel(store: store, today: today)
  }

  @Test("AK-46: Schuljahr 2026/27 anlegen")
  func savesNewYear() throws {
    let model = makeModel()
    model.newYear()
    #expect(model.draft?.firstDay == CalendarDay(year: 2026, month: 8, day: 1))
    #expect(model.draft?.secondTermStart == CalendarDay(year: 2027, month: 2, day: 1))
    #expect(model.draft?.lastDay == CalendarDay(year: 2027, month: 7, day: 31))
    model.saveDraft()
    #expect(model.draft == nil)
    #expect(model.issueKey == nil)
    #expect(model.years.map(\.title) == ["2026/27"])
    #expect(try store.schoolYears().count == 1)
  }

  @Test("Neues Jahr nach 2025/26 schlägt dieselben Tage ein Jahr später vor")
  func proposesFollowingYear() throws {
    try store.saveSchoolYear(year(2025))
    let model = makeModel()
    model.newYear()
    #expect(model.draft?.firstDay == CalendarDay(year: 2026, month: 8, day: 3))
    #expect(model.draft?.secondTermStart == CalendarDay(year: 2027, month: 2, day: 2))
    #expect(model.draft?.lastDay == CalendarDay(year: 2027, month: 7, day: 30))
  }

  @Test("Überschneidung → Meldung, nichts gespeichert")
  func overlapShowsIssue() throws {
    try store.saveSchoolYear(year(2025))
    let model = makeModel()
    model.newYear()
    // Erster Schultag mitten im Schuljahr 2025/26.
    model.draft?.firstDay = CalendarDay(year: 2026, month: 6, day: 1)
    model.saveDraft()
    #expect(model.issueKey == "setup.schoolYears.error.overlap %@")
    #expect(model.issueOverlapTitle == "2025/26")
    #expect(model.draft != nil)
    #expect(try store.schoolYears().count == 1)
  }

  @Test("Letzter Schultag vor dem ersten → Meldung")
  func orderShowsIssue() {
    let model = makeModel()
    model.newYear()
    model.draft?.lastDay = CalendarDay(year: 2026, month: 7, day: 1)
    model.saveDraft()
    #expect(model.issueKey == "setup.schoolYears.error.order")
  }

  @Test("AK-45: EF braucht einen Jahrgang, 8a nicht")
  func listsClassesWithoutDigits() throws {
    store.classes = [SchoolClass("8a"), SchoolClass("EF")]
    try store.saveSchoolYear(year(2026))
    let model = makeModel()
    var list = model.classesNeedingGrade(startYear: 2026)
    #expect(list.map(\.schoolClass) == [SchoolClass("EF")])
    #expect(list.first?.grade == nil)
    model.setGrade(GradeLevel(10), for: SchoolClass("EF"), startYear: 2026)
    list = model.classesNeedingGrade(startYear: 2026)
    #expect(list.first?.grade == GradeLevel(10))
    #expect(try store.schoolYears().first?.gradeOverrides["ef"] == 10)
  }

  @Test("Jahrgang im offenen Entwurf wirkt erst mit Speichern")
  func gradeInDraftIsSavedWithDraft() throws {
    store.classes = [SchoolClass("EF")]
    let model = makeModel()
    model.newYear()
    model.setGrade(GradeLevel(11), for: SchoolClass("EF"), startYear: 2026)
    #expect(model.classesNeedingGrade(startYear: 2026).first?.grade == GradeLevel(11))
    model.saveDraft()
    #expect(try store.schoolYears().first?.gradeOverrides["ef"] == 11)
  }

  @Test("Entfernen löscht nur das Schuljahr")
  func removesYear() throws {
    try store.saveSchoolYear(year(2025))
    let model = makeModel()
    model.remove(startYear: 2025)
    #expect(model.years.isEmpty)
  }
}

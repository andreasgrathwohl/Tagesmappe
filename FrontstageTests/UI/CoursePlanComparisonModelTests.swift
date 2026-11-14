import Foundation
import FrontstageCore
import Testing

@testable import Frontstage

/// Vergleich früherer Jahre (FR-15.3, AK-48).
@MainActor @Suite struct CoursePlanComparisonModelTests {
  private let store = FakeCoursePlanStore()

  private func key(_ subject: String, _ grade: Int, _ year: Int) -> CoursePlanKey {
    CoursePlanKey(subject: Subject(subject), gradeLevel: GradeLevel(grade)!, startYear: year)
  }

  /// Schuljahr ab dem ersten Montag im August des Startjahres.
  private func schoolYear(_ start: Int, firstMonday: Int) -> SchoolYear {
    SchoolYear(
      firstDay: CalendarDay(year: start, month: 8, day: firstMonday),
      secondTermStart: CalendarDay(year: start + 1, month: 2, day: 2),
      lastDay: CalendarDay(year: start + 1, month: 7, day: 24))
  }

  /// Legt einen Plan mit Thema in Woche 1 an und liefert seine id.
  @discardableResult
  private func addPlan(_ key: CoursePlanKey, firstMonday: Int, topic: String?) throws -> UUID {
    let year = schoolYear(key.startYear, firstMonday: firstMonday)
    if store.weeks[key.startYear] == nil {
      store.weeks[key.startYear] = TeachingWeekCalculator.weeks(of: year, nonTeachingPeriods: [])
    }
    let id = try store.createCoursePlan(key)
    if let topic, let monday = store.weeks[key.startYear]?.first?.monday {
      try store.savePlanWeek(
        PlanWeek(
          id: UUID(), monday: monday, position: 0, topic: topic, notes: nil,
          updatedAt: Date(timeIntervalSince1970: 0)),
        planID: id)
    }
    return id
  }

  /// Englisch 8 in 2024/25, 2025/26, 2026/27 und Englisch 7 in 2025/26.
  private func makeModel() throws -> CoursePlanComparisonModel {
    try addPlan(key("Englisch", 8, 2024), firstMonday: 5, topic: "Unit 1 – 2024")
    try addPlan(key("Englisch", 8, 2025), firstMonday: 4, topic: "Unit 1 – 2025")
    try addPlan(key("Englisch", 7, 2025), firstMonday: 4, topic: "Andere Klasse")
    let current = try addPlan(key("Englisch", 8, 2026), firstMonday: 3, topic: "Unit 1 – 2026")
    return CoursePlanComparisonModel(planID: current, store: store)
  }

  @Test("AK-48: frühere Jahre 2025/26 und 2024/25, nicht Englisch 7")
  func listsEarlierYears() throws {
    let model = try makeModel()
    #expect(model.earlier.map(\.key.startYear) == [2025, 2024])
    #expect(model.earlier.allSatisfy { $0.key.gradeLevel == GradeLevel(8)! })
  }

  @Test("AK-48: Spalten 2026/27, 2025/26, 2024/25; Zeile 1 mit den Themen der Woche 1")
  func buildsRows() throws {
    let model = try makeModel()
    #expect(model.columnTitles == ["2026/27", "2025/26", "2024/25"])
    let first = try #require(model.rows.first)
    #expect(first.number == 1)
    #expect(first.cells.map { $0?.topic } == ["Unit 1 – 2026", "Unit 1 – 2025", "Unit 1 – 2024"])
  }

  @Test("Höchstens vier Spalten")
  func limitsColumns() throws {
    for (offset, monday) in [(2023, 7), (2022, 1), (2021, 2)] {
      try addPlan(key("Englisch", 8, offset), firstMonday: monday, topic: nil)
    }
    let model = try makeModel()
    #expect(model.earlier.count == 5)
    #expect(model.selected.count == 3)
    model.toggle(model.earlier[2].id)
    #expect(model.selected.count == 4)
    model.toggle(model.earlier[3].id)
    #expect(model.selected.count == 4)
    #expect(model.columnTitles.count == 4)
    // Abwählen schafft wieder Platz; der aktuelle Plan lässt sich nicht abwählen.
    model.toggle(model.earlier[0].id)
    #expect(model.selected.count == 3)
    model.toggle(model.selected[0])
    #expect(model.selected.count == 3)
  }
}

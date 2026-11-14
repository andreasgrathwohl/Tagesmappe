import Foundation
import Testing

@testable import FrontstageCore

private let holidays2026: [NonTeachingPeriod] = [
  NonTeachingPeriod(from: d(2026, 11, 2), to: d(2026, 11, 6), title: "Herbst"),
  NonTeachingPeriod(from: d(2026, 12, 23), to: d(2027, 1, 8), title: "Weihnachten"),
  NonTeachingPeriod(from: d(2027, 3, 26), to: d(2027, 3, 26), title: "Karfreitag"),
  NonTeachingPeriod(from: d(2027, 4, 5), to: d(2027, 4, 5), title: "Ostermontag"),
]

/// Eine freie Woche, damit 2025/26 mehr Wochen hat als 2026/27.
private let holidays2025: [NonTeachingPeriod] = [
  NonTeachingPeriod(from: d(2025, 11, 3), to: d(2025, 11, 7), title: "Herbst")
]

private func uid(_ n: Int) -> UUID {
  UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}

private func at(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 1000) }

private func key(_ subject: String, _ grade: Int, _ year: Int) -> CoursePlanKey {
  CoursePlanKey(subject: Subject(subject), gradeLevel: GradeLevel(grade)!, startYear: year)
}

@Suite("CoursePlan History") struct CoursePlanHistoryTests {
  @Test("AK-48: nur gleiches Fach und gleicher Jahrgang, neuestes zuerst")
  func earlierYears() {
    let e8 = { (y: Int) in key("Englisch", 8, y) }
    let keys = [
      e8(2024), e8(2025), key("Englisch", 7, 2025), key("englisch ", 8, 2023), e8(2027),
      key("Mathe", 8, 2025),
    ]
    #expect(CoursePlanHistory.earlier(than: e8(2026), among: keys).map(\.startYear) == [2025, 2024, 2023])
  }

  private func columns() -> (ComparisonColumn, ComparisonColumn) {
    let weeks25 = TeachingWeekCalculator.weeks(of: year2025(), nonTeachingPeriods: holidays2025)
    let weeks26 = TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)
    let old = ComparisonColumn(
      key: key("Englisch", 8, 2025), weeks: weeks25,
      planWeeks: [
        PlanWeek(
          id: uid(1), monday: weeks25[0].monday, position: 0, topic: "Unit 1 – Intro",
          notes: nil, updatedAt: at(1))
      ],
      assessments: [
        Assessment(
          id: uid(2), monday: weeks25[3].monday, day: nil, kind: .test, title: "Test 1",
          updatedAt: at(1))
      ])
    let current = ComparisonColumn(
      key: key("Englisch", 8, 2026), weeks: weeks26, planWeeks: [], assessments: [])
    return (old, current)
  }

  @Test("AK-48: Zeile n zeigt Woche n jedes Jahres; kürzeres Jahr hat leere Zellen")
  func rowsAlignByWeekNumber() {
    let (old, current) = columns()
    #expect(old.weeks.count == 45 && current.weeks.count == 43)
    let rows = CoursePlanComparison.rows([old, current])
    #expect(rows.count == 45)
    #expect(rows.map(\.number) == Array(1...45))
    #expect(rows[44].cells[1] == nil)
    #expect(rows[44].cells[0] != nil)
    #expect(rows[0].cells[0]?.topic == "Unit 1 – Intro")
    #expect(rows[0].cells[1]?.topic == nil)
    #expect(rows[3].cells[0]?.assessments.map(\.title) == ["Test 1"])
  }

  @Test("AK-48: Halbjahresgrenze je Spalte markiert")
  func marksSecondTermStart() {
    let (old, current) = columns()
    let rows = CoursePlanComparison.rows([old, current])
    #expect(rows[17].cells[1]?.startsSecondTerm == true)
    let oldStart = old.weeks.firstIndex { $0.term == .second }!
    #expect(rows[oldStart].cells[0]?.startsSecondTerm == true)
    for (index, row) in rows.enumerated() {
      for (column, startIndex) in [(0, oldStart), (1, 17)] {
        guard let cell = row.cells[column] else { continue }
        #expect(cell.startsSecondTerm == (index == startIndex))
      }
    }
  }

  @Test("Keine Spalten oder leere Spalten ergeben keine Zeilen")
  func emptyInput() {
    #expect(CoursePlanComparison.rows([]).isEmpty)
  }
}

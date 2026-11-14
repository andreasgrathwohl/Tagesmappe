import Foundation
import Testing

@testable import FrontstageCore

private let holidays2025: [NonTeachingPeriod] = [
  NonTeachingPeriod(from: d(2025, 10, 27), to: d(2025, 10, 31), title: "Herbst"),
  NonTeachingPeriod(from: d(2026, 4, 3), to: d(2026, 4, 3), title: "Karfreitag"),
]

private let holidays2026: [NonTeachingPeriod] = [
  NonTeachingPeriod(from: d(2026, 11, 2), to: d(2026, 11, 6), title: "Herbst"),
  NonTeachingPeriod(from: d(2026, 12, 23), to: d(2027, 1, 8), title: "Weihnachten"),
  NonTeachingPeriod(from: d(2027, 3, 26), to: d(2027, 3, 26), title: "Karfreitag"),
  NonTeachingPeriod(from: d(2027, 4, 5), to: d(2027, 4, 5), title: "Ostermontag"),
]

private func uid(_ n: Int) -> UUID {
  UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}

private func at(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 1000) }

private func sourceWeeks() -> [TeachingWeek] {
  TeachingWeekCalculator.weeks(of: year2025(), nonTeachingPeriods: holidays2025)
}

private func targetWeeks() -> [TeachingWeek] {
  TeachingWeekCalculator.weeks(of: year2026(), nonTeachingPeriods: holidays2026)
}

private func topics(_ weeks: [TeachingWeek]) -> [PlanWeek] {
  weeks.map {
    PlanWeek(
      id: uid($0.number), monday: $0.monday, position: 0, topic: "Thema \($0.number)",
      notes: nil, updatedAt: at(1))
  }
}

@Suite("CoursePlan Copy") struct CoursePlanCopierTests {
  private func run(
    sourcePlanWeeks: [PlanWeek], sourceAssessments: [Assessment] = [], sourceNote: String? = nil,
    target: [TeachingWeek]? = nil, targetPlanWeeks: [PlanWeek] = [],
    targetAssessments: [Assessment] = [], targetNote: String? = nil, position: Int = 0
  ) -> CopyResult {
    var n = 1000
    return CoursePlanCopier.copy(
      sourceWeeks: sourceWeeks(), sourcePlanWeeks: sourcePlanWeeks,
      sourceAssessments: sourceAssessments, sourceNote: sourceNote,
      targetWeeks: target ?? targetWeeks(), targetPlanWeeks: targetPlanWeeks,
      targetAssessments: targetAssessments, targetNote: targetNote,
      nextUnassignedPosition: position, now: at(9), makeID: { n += 1; return uid(n) })
  }

  @Test("Fixture: 45 Quell- und 43 Zielwochen")
  func fixtureWeekCounts() {
    #expect(sourceWeeks().count == 45)
    #expect(targetWeeks().count == 43)
  }

  @Test("AK-49: Woche 1 → Woche 1, KA 1 am selben Wochentag, Überzähliges nicht zugeordnet")
  func copiesWeekByWeek() {
    let source = sourceWeeks()
    let target = targetWeeks()
    let planWeeks = topics(source)
    let ka = Assessment(
      id: uid(100), monday: d(2025, 11, 10), day: d(2025, 11, 11), kind: .classTest,
      title: "KA 1", updatedAt: at(1))
    let own = PlanWeek(
      id: uid(200), monday: target[1].monday, position: 0, topic: "Projekt Schulfest",
      notes: nil, updatedAt: at(2))
    let result = run(
      sourcePlanWeeks: planWeeks, sourceAssessments: [ka], sourceNote: "Lektüre im 2. Halbjahr",
      targetPlanWeeks: [own])
    #expect(result.planWeeks.first { $0.monday == d(2026, 9, 14) }?.topic == "Thema 1")
    #expect(
      result.assessments == [
        Assessment(
          id: result.assessments[0].id, monday: d(2026, 11, 9), day: d(2026, 11, 10),
          kind: .classTest, title: "KA 1", updatedAt: at(9))
      ])
    #expect(
      result.planWeeks.filter { $0.monday == nil }.map(\.topic)
        == ["Thema 2", "Thema 44", "Thema 45"])
    #expect(result.planWeeks.filter { $0.monday == nil }.map(\.position) == [0, 1, 2])
    #expect(!result.planWeeks.contains { $0.monday == target[1].monday })
    #expect(result.planNote == "Lektüre im 2. Halbjahr" && result.unassignedCount == 3)
    #expect(Set(result.planWeeks.map(\.id)).isDisjoint(with: Set(planWeeks.map(\.id))))
  }

  @Test("Belegte Zielwoche behält ihr Thema")
  func occupiedTargetWeekKeepsOwnContent() {
    let target = targetWeeks()
    let own = PlanWeek(
      id: uid(200), monday: target[0].monday, position: 0, topic: "Eigenes", notes: nil,
      updatedAt: at(2))
    let result = run(sourcePlanWeeks: topics(sourceWeeks()), targetPlanWeeks: [own])
    #expect(!result.planWeeks.contains { $0.monday == target[0].monday })
    #expect(result.planWeeks.contains { $0.monday == nil && $0.topic == "Thema 1" })
  }

  @Test("Leere Planwoche im Ziel zählt nicht als belegt")
  func emptyTargetPlanWeekDoesNotBlock() {
    let target = targetWeeks()
    let empty = PlanWeek(
      id: uid(200), monday: target[0].monday, position: 0, topic: "  ", notes: nil,
      updatedAt: at(2))
    let result = run(sourcePlanWeeks: topics(sourceWeeks()), targetPlanWeeks: [empty])
    #expect(result.planWeeks.contains { $0.monday == target[0].monday && $0.topic == "Thema 1" })
  }

  @Test("Überzähliges in Wochenreihenfolge, Positionen ab nextUnassignedPosition")
  func overflowGoesToUnassignedInOrder() {
    let source = sourceWeeks()
    let loose = PlanWeek(
      id: uid(300), monday: nil, position: 0, topic: "Lose", notes: nil, updatedAt: at(1))
    let result = run(sourcePlanWeeks: [loose] + topics(source).reversed(), position: 5)
    let unassigned = result.planWeeks.filter { $0.monday == nil }
    #expect(unassigned.map(\.topic) == ["Thema 44", "Thema 45", "Lose"])
    #expect(unassigned.map(\.position) == [5, 6, 7])
  }

  @Test("Zweimal übernehmen legt keinen Leistungsnachweis doppelt an")
  func copyingTwiceAddsNoDuplicateAssessments() {
    let ka = Assessment(
      id: uid(100), monday: d(2025, 11, 10), day: d(2025, 11, 11), kind: .classTest,
      title: "KA 1", updatedAt: at(1))
    let first = run(sourcePlanWeeks: [], sourceAssessments: [ka])
    #expect(first.assessments.count == 1)
    let second = run(
      sourcePlanWeeks: [], sourceAssessments: [ka], targetAssessments: first.assessments)
    #expect(second.assessments.isEmpty)
  }

  @Test("Ziel mit eigener Notiz behält sie")
  func targetNoteIsKept() {
    let result = run(sourcePlanWeeks: [], sourceNote: "Quelle", targetNote: "Eigene")
    #expect(result.planNote == nil)
  }

  @Test("Leistungsnachweis ohne Zielwoche wird ohne Woche und ohne Tag übernommen")
  func assessmentWithoutTargetWeekIsUnassigned() {
    let source = sourceWeeks()
    let last = source[44]
    let ka = Assessment(
      id: uid(100), monday: last.monday, day: last.monday, kind: .test, title: "Test",
      updatedAt: at(1))
    let result = run(sourcePlanWeeks: [], sourceAssessments: [ka])
    #expect(result.assessments.count == 1)
    #expect(result.assessments[0].monday == nil && result.assessments[0].day == nil)
    #expect(result.unassignedCount == 1)
  }
}

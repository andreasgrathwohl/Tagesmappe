import Foundation
import Testing

@testable import FrontstageCore

private func uid(_ n: Int) -> UUID {
  UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}

private func at(_ n: Int) -> Date { Date(timeIntervalSince1970: Double(n) * 1000) }

private let key = CoursePlanKey(subject: Subject("Englisch"), gradeLevel: GradeLevel(8)!, startYear: 2026)
private let monday = d(2026, 9, 14)

private typealias Snap = CoursePlanMergeSnapshot

@Suite("CoursePlan Merge") struct CoursePlanMergerTests {
  @Test("Doppelter Jahresplan: ältester bleibt, Kinder wandern")
  func duplicatePlansKeepOldestAndMoveChildren() {
    let snapshot = Snap(
      plans: [.init(id: uid(1), key: key, createdAt: at(1)), .init(id: uid(2), key: key, createdAt: at(2))],
      weeks: [.init(id: uid(10), planID: uid(2), monday: monday, createdAt: at(3), updatedAt: at(3))])
    let plan = CoursePlanMerger.plan(for: snapshot)
    #expect(plan.deletions == [uid(2)])
    #expect(plan.parentChanges == [uid(10): uid(1)])
    #expect(plan.weekContentSources.isEmpty)
  }

  @Test("Doppelte Planwoche: älteste bleibt, jüngster Inhalt gilt")
  func duplicateWeeksTakeLatestContent() {
    let snapshot = Snap(weeks: [
      .init(id: uid(10), planID: uid(1), monday: monday, createdAt: at(1), updatedAt: at(5)),
      .init(id: uid(11), planID: uid(1), monday: monday, createdAt: at(2), updatedAt: at(8)),
    ])
    let plan = CoursePlanMerger.plan(for: snapshot)
    #expect(plan.deletions == [uid(11)])
    #expect(plan.weekContentSources == [uid(10): uid(11)])
  }

  @Test("Doppelte Planwoche: behaltene Woche ist zugleich die jüngste, keine Quelle")
  func keeperAlreadyNewestNeedsNoSource() {
    let snapshot = Snap(weeks: [
      .init(id: uid(10), planID: uid(1), monday: monday, createdAt: at(1), updatedAt: at(9)),
      .init(id: uid(11), planID: uid(1), monday: monday, createdAt: at(2), updatedAt: at(8)),
    ])
    let plan = CoursePlanMerger.plan(for: snapshot)
    #expect(plan.deletions == [uid(11)])
    #expect(plan.weekContentSources.isEmpty)
  }

  @Test("Doppelte Planwoche über zwei doppelte Pläne hinweg wird erkannt")
  func weeksOfMergedPlansCollapse() {
    let snapshot = Snap(
      plans: [.init(id: uid(1), key: key, createdAt: at(1)), .init(id: uid(2), key: key, createdAt: at(2))],
      weeks: [
        .init(id: uid(10), planID: uid(1), monday: monday, createdAt: at(3), updatedAt: at(3)),
        .init(id: uid(11), planID: uid(2), monday: monday, createdAt: at(4), updatedAt: at(6)),
      ])
    let plan = CoursePlanMerger.plan(for: snapshot)
    #expect(plan.deletions == [uid(2), uid(11)])
    #expect(plan.parentChanges.isEmpty)
    #expect(plan.weekContentSources == [uid(10): uid(11)])
  }

  @Test("Nicht zugeordnete Planwochen bleiben alle")
  func unassignedWeeksAreNeverMerged() {
    let snapshot = Snap(weeks: [
      .init(id: uid(10), planID: uid(1), monday: nil, createdAt: at(1), updatedAt: at(1)),
      .init(id: uid(11), planID: uid(1), monday: nil, createdAt: at(2), updatedAt: at(2)),
    ])
    #expect(CoursePlanMerger.plan(for: snapshot).isEmpty)
  }

  @Test("Gleicher Leistungsnachweis einmal, verschiedene Titel beide")
  func duplicateAssessments() {
    func item(_ n: Int, _ title: String) -> Snap.Item {
      .init(
        id: uid(n), planID: uid(1), monday: monday, day: nil, kind: .test, title: title,
        createdAt: at(n))
    }
    let snapshot = Snap(assessments: [
      item(20, "Vokabeltest"), item(21, " Vokabeltest "), item(22, "Grammartest"),
    ])
    let plan = CoursePlanMerger.plan(for: snapshot)
    #expect(plan.deletions == [uid(21)])
  }

  @Test("Doppeltes Schuljahr: ältestes bleibt")
  func duplicateSchoolYears() {
    let snapshot = Snap(years: [
      .init(id: uid(2), startYear: 2026, createdAt: at(2)),
      .init(id: uid(1), startYear: 2026, createdAt: at(1)),
      .init(id: uid(3), startYear: 2027, createdAt: at(3)),
    ])
    #expect(CoursePlanMerger.plan(for: snapshot).deletions == [uid(2)])
  }

  @Test("Nichts doppelt → leerer Plan")
  func nothingToMerge() {
    let snapshot = Snap(
      years: [.init(id: uid(1), startYear: 2026, createdAt: at(1))],
      plans: [.init(id: uid(2), key: key, createdAt: at(1))],
      weeks: [.init(id: uid(3), planID: uid(2), monday: monday, createdAt: at(1), updatedAt: at(1))])
    #expect(CoursePlanMerger.plan(for: snapshot).isEmpty)
  }
}

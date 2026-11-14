import Foundation
import FrontstageCore
import SwiftData
import Testing

@testable import Frontstage

@MainActor @Suite struct CoursePlanMergeTests {
  private let early = Date(timeIntervalSince1970: 1_800_000_000)
  private let late = Date(timeIntervalSince1970: 1_800_003_600)

  @discardableResult
  private func addPlan(_ context: ModelContext, createdAt: Date) -> CoursePlanRecord {
    let plan = CoursePlanRecord()
    plan.createdAt = createdAt
    plan.subjectText = "Englisch"
    plan.gradeLevel = 8
    plan.startYear = 2026
    context.insert(plan)
    return plan
  }

  @discardableResult
  private func addWeek(
    _ context: ModelContext, to plan: CoursePlanRecord, monday: String, topic: String?,
    createdAt: Date, updatedAt: Date
  ) -> PlanWeekRecord {
    let week = PlanWeekRecord()
    week.coursePlan = plan
    week.mondayText = monday
    week.topic = topic
    week.createdAt = createdAt
    week.updatedAt = updatedAt
    context.insert(week)
    return week
  }

  @Test("Zwei Jahrespläne Englisch 8 2026 nach dem Abgleich → einer, beide Wochen daran")
  func mergeDuplicatesCollapsesCoursePlans() throws {
    let store = try makeStore()
    let context = store.modelContext
    let keeper = addPlan(context, createdAt: early)
    let dropped = addPlan(context, createdAt: late)
    addWeek(context, to: keeper, monday: "2026-11-16", topic: "A", createdAt: early, updatedAt: early)
    addWeek(context, to: dropped, monday: "2026-11-23", topic: "B", createdAt: late, updatedAt: late)
    try context.save()

    try store.mergeDuplicates()

    let plans = try context.fetch(FetchDescriptor<CoursePlanRecord>())
    #expect(plans.map(\.id) == [keeper.id])
    let weeks = try context.fetch(FetchDescriptor<PlanWeekRecord>())
    #expect(weeks.count == 2)
    #expect(weeks.allSatisfy { $0.coursePlan?.id == keeper.id })
  }

  @Test("Gleiche Woche zweimal → eine, Thema der zuletzt geänderten")
  func mergeDuplicatesTakesLatestWeekContent() throws {
    let store = try makeStore()
    let context = store.modelContext
    let keeper = addPlan(context, createdAt: early)
    let dropped = addPlan(context, createdAt: late)
    addWeek(context, to: keeper, monday: "2026-11-16", topic: "Alt", createdAt: early, updatedAt: early)
    addWeek(context, to: dropped, monday: "2026-11-16", topic: "Neu", createdAt: late, updatedAt: late)
    try context.save()

    try store.mergeDuplicates()

    let weeks = try context.fetch(FetchDescriptor<PlanWeekRecord>())
    #expect(weeks.count == 1)
    #expect(weeks.first?.topic == "Neu")
    #expect(weeks.first?.updatedAt == late)
    #expect(weeks.first?.coursePlan?.id == keeper.id)
  }

  @Test("Nur Jahrespläne doppelt: Zusammenführen läuft trotz leerem MergePlan")
  func coursePlanMergeRunsWhenTimetableMergeIsEmpty() throws {
    let store = try makeStore()
    let context = store.modelContext
    addPlan(context, createdAt: early)
    addPlan(context, createdAt: late)
    try context.save()

    let plan = try store.mergeDuplicates()

    #expect(plan.isEmpty)
    #expect(try context.fetchCount(FetchDescriptor<CoursePlanRecord>()) == 1)
  }
}

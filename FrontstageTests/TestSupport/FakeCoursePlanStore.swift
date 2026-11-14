import Foundation
import FrontstageCore

@testable import Frontstage

/// Attrappe der Jahresplanung für die Modell-Tests (Teilplan 09). Hält alles im Speicher und prüft
/// Schuljahre wie `DataStore` (`SchoolYear.issue(among:)`). Die Tests setzen `classes`, `subjects`,
/// `weeks` und `years` direkt.
@MainActor final class FakeCoursePlanStore: CoursePlanStore {
  private(set) var revision = 0
  var years: [SchoolYear] = []
  var classes: [SchoolClass] = []
  var subjects: [Subject] = []
  /// Unterrichtswochen je Startjahr.
  var weeks: [Int: [TeachingWeek]] = [:]
  private(set) var plans: [UUID: CoursePlanContent] = [:]
  /// Rückgabe von `copyCoursePlan`; `CopyResult` hat keinen öffentlichen Initialisierer, daher
  /// kommt der Vorgabewert aus dem Kopierer mit leeren Eingaben.
  var copyResult = CoursePlanCopier.copy(
    sourceWeeks: [], sourcePlanWeeks: [], sourceAssessments: [], sourceNote: nil,
    targetWeeks: [], targetPlanWeeks: [], targetAssessments: [], targetNote: nil,
    nextUnassignedPosition: 0, now: Date(timeIntervalSince1970: 0), makeID: { UUID() })
  /// Klassen je Schlüssel für „gilt für …“.
  var followers: [CoursePlanKey: [SchoolClass]] = [:]

  private func bump() { revision += 1 }

  func schoolYears() throws -> [SchoolYear] { years.sorted { $0.startYear < $1.startYear } }

  func saveSchoolYear(_ year: SchoolYear) throws {
    if let issue = year.issue(among: years) { throw CoursePlanError.invalidSchoolYear(issue) }
    years.removeAll { $0.startYear == year.startYear }
    years.append(year)
    bump()
  }

  func removeSchoolYear(startYear: Int) throws {
    years.removeAll { $0.startYear == startYear }
    bump()
  }

  func setGradeOverride(_ grade: GradeLevel?, for schoolClass: SchoolClass, startYear: Int) throws {
    guard let index = years.firstIndex(where: { $0.startYear == startYear }) else {
      throw CoursePlanError.schoolYearMissing(startYear: startYear)
    }
    if let grade {
      years[index].gradeOverrides[schoolClass.normalized] = grade.value
    } else {
      years[index].gradeOverrides.removeValue(forKey: schoolClass.normalized)
    }
    bump()
  }

  func timetableClasses() throws -> [SchoolClass] { classes }
  func timetableSubjects() throws -> [Subject] { subjects }
  func teachingWeeks(startYear: Int) throws -> [TeachingWeek] { weeks[startYear] ?? [] }

  func coursePlanSummaries() throws -> [CoursePlanSummary] {
    plans.values.map { CoursePlanSummary(id: $0.id, key: $0.key) }.sorted { lhs, rhs in
      if lhs.key.startYear != rhs.key.startYear { return lhs.key.startYear > rhs.key.startYear }
      if lhs.key.subject.normalized != rhs.key.subject.normalized {
        return lhs.key.subject.normalized < rhs.key.subject.normalized
      }
      return lhs.key.gradeLevel < rhs.key.gradeLevel
    }
  }

  func coursePlan(id: UUID) throws -> CoursePlanContent? { plans[id] }

  func createCoursePlan(_ key: CoursePlanKey) throws -> UUID {
    if let existing = plans.values.first(where: { $0.key == key }) { return existing.id }
    let id = UUID()
    plans[id] = CoursePlanContent(id: id, key: key, notes: nil, planWeeks: [], assessments: [])
    bump()
    return id
  }

  func setPlanNote(_ notes: String?, planID: UUID) throws {
    guard plans[planID] != nil else { throw CoursePlanError.planMissing(planID) }
    plans[planID]?.notes = notes
    bump()
  }

  func savePlanWeek(_ week: PlanWeek, planID: UUID) throws {
    guard var plan = plans[planID] else { throw CoursePlanError.planMissing(planID) }
    plan.planWeeks.removeAll { $0.id == week.id }
    if !week.isEmpty { plan.planWeeks.append(week) }
    plan.planWeeks.sort { $0.position < $1.position }
    plans[planID] = plan
    bump()
  }

  func assignPlanWeek(id: UUID, to monday: CalendarDay) throws {
    for planID in plans.keys {
      guard var plan = plans[planID],
        let index = plan.planWeeks.firstIndex(where: { $0.id == id })
      else { continue }
      if plan.planWeeks.contains(where: { $0.monday == monday && !$0.isEmpty }) {
        throw CoursePlanError.weekOccupied
      }
      plan.planWeeks[index].monday = monday
      plans[planID] = plan
      bump()
      return
    }
    throw CoursePlanError.planMissing(id)
  }

  func saveAssessment(_ assessment: Assessment, planID: UUID) throws {
    guard var plan = plans[planID] else { throw CoursePlanError.planMissing(planID) }
    plan.assessments.removeAll { $0.id == assessment.id }
    plan.assessments.append(assessment)
    plans[planID] = plan
    bump()
  }

  func removeAssessment(id: UUID) throws {
    for planID in plans.keys {
      guard var plan = plans[planID], plan.assessments.contains(where: { $0.id == id }) else {
        continue
      }
      plan.assessments.removeAll { $0.id == id }
      plans[planID] = plan
      bump()
    }
  }

  func assignAssessment(id: UUID, to week: TeachingWeek) throws {
    for planID in plans.keys {
      guard var plan = plans[planID],
        let index = plan.assessments.firstIndex(where: { $0.id == id })
      else { continue }
      plan.assessments[index].monday = week.monday
      plan.assessments[index].day = nil
      plans[planID] = plan
      bump()
      return
    }
    throw CoursePlanError.planMissing(id)
  }

  func copyCoursePlan(from sourceID: UUID, to targetID: UUID) throws -> CopyResult { copyResult }

  func classes(following key: CoursePlanKey) throws -> [SchoolClass] { followers[key] ?? [] }
}

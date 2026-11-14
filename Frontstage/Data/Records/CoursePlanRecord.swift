import Foundation
import SwiftData

/// Jahresplan (Glossar): Fach und Jahrgang je Schuljahr, mit Planwochen und Leistungsnachweisen.
@Model
final class CoursePlanRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  var subjectText: String = ""
  var gradeLevel: Int = 0
  var startYear: Int = 0
  var notes: String?
  @Relationship(deleteRule: .cascade, inverse: \PlanWeekRecord.coursePlan)
  var planWeeks: [PlanWeekRecord]? = []
  @Relationship(deleteRule: .cascade, inverse: \AssessmentRecord.coursePlan)
  var assessments: [AssessmentRecord]? = []

  init() {}
}

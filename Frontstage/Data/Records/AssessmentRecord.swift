import Foundation
import SwiftData

/// Leistungsnachweis eines Jahresplans (Test oder Klassenarbeit).
@Model
final class AssessmentRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  var coursePlan: CoursePlanRecord?
  var mondayText: String?
  var dayText: String?
  /// `AssessmentKind.rawValue`.
  var kindRaw: String = "test"
  var title: String = ""
  var updatedAt: Date = Date.now

  init() {}
}

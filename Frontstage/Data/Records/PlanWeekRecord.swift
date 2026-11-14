import Foundation
import SwiftData

/// Planwoche eines Jahresplans; ohne Montag (`mondayText == nil`) ist sie „nicht zugeordnet“.
@Model
final class PlanWeekRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  var coursePlan: CoursePlanRecord?
  var mondayText: String?
  var position: Int = 0
  var topic: String?
  var notes: String?
  var updatedAt: Date = Date.now

  init() {}
}

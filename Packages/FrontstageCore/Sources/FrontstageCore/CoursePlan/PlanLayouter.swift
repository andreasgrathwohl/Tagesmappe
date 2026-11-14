import Foundation

public struct PlanLayoutWeek: Hashable, Sendable {
  public let week: TeachingWeek
  public let planWeek: PlanWeek?
  public let assessments: [Assessment]
}

public struct PlanLayout: Hashable, Sendable {
  public let first: [PlanLayoutWeek]
  public let second: [PlanLayoutWeek]
  public let unassignedWeeks: [PlanWeek]
  public let unassignedAssessments: [Assessment]
}

/// Ordnet Planwochen und Leistungsnachweise den Unterrichtswochen zu (FR-15.2).
public enum PlanLayouter {
  public static func layout(
    weeks: [TeachingWeek], planWeeks: [PlanWeek], assessments: [Assessment]
  ) -> PlanLayout {
    let mondays = Set(weeks.map(\.monday))

    // Je Montag steht die zuletzt geänderte Planwoche in der Woche; bei Gleichstand die mit
    // kleinerer Position, dann kleinerer ID (stabil).
    var shown: [CalendarDay: PlanWeek] = [:]
    var unassignedWeeks: [PlanWeek] = []
    for planWeek in planWeeks {
      guard let monday = planWeek.monday, mondays.contains(monday) else {
        unassignedWeeks.append(planWeek)
        continue
      }
      if let current = shown[monday] {
        if wins(planWeek, over: current) {
          unassignedWeeks.append(current)
          shown[monday] = planWeek
        } else {
          unassignedWeeks.append(planWeek)
        }
      } else {
        shown[monday] = planWeek
      }
    }
    unassignedWeeks.sort(by: unassignedWeekOrder)

    var byMonday: [CalendarDay: [Assessment]] = [:]
    var unassignedAssessments: [Assessment] = []
    for assessment in assessments {
      if let monday = assessment.monday, mondays.contains(monday) {
        byMonday[monday, default: []].append(assessment)
      } else {
        unassignedAssessments.append(assessment)
      }
    }
    unassignedAssessments.sort { lhs, rhs in
      switch (lhs.monday, rhs.monday) {
      case (nil, nil): return assessmentOrder(lhs, rhs)
      case (nil, _?): return true
      case (_?, nil): return false
      case let (l?, r?): return l == r ? assessmentOrder(lhs, rhs) : l < r
      }
    }

    let layoutWeeks = weeks.map { week in
      PlanLayoutWeek(
        week: week, planWeek: shown[week.monday],
        assessments: (byMonday[week.monday] ?? []).sorted(by: assessmentOrder))
    }
    return PlanLayout(
      first: layoutWeeks.filter { $0.week.term == .first },
      second: layoutWeeks.filter { $0.week.term == .second },
      unassignedWeeks: unassignedWeeks, unassignedAssessments: unassignedAssessments)
  }

  /// Zuweisen: setzt `monday`; der Tag bleibt als gleicher Wochentag, wenn der in `week`
  /// Unterrichtstag ist, sonst `nil`.
  public static func assign(_ assessment: Assessment, to week: TeachingWeek) -> Assessment {
    var result = assessment
    result.monday = week.monday
    if let day = assessment.day {
      let candidate = week.monday.adding(days: day.weekday.rawValue - 1)
      result.day = isValidDay(candidate, for: week) ? candidate : nil
    }
    return result
  }

  public static func isValidDay(_ day: CalendarDay, for week: TeachingWeek) -> Bool {
    week.teachingDays.contains(day)
  }

  private static func wins(_ candidate: PlanWeek, over current: PlanWeek) -> Bool {
    if candidate.updatedAt != current.updatedAt { return candidate.updatedAt > current.updatedAt }
    return (candidate.position, candidate.id.uuidString)
      < (current.position, current.id.uuidString)
  }

  /// Ohne Montag zuerst (nach Position), dann Montage ohne Unterrichtswoche (nach Datum).
  private static func unassignedWeekOrder(_ lhs: PlanWeek, _ rhs: PlanWeek) -> Bool {
    switch (lhs.monday, rhs.monday) {
    case (nil, nil):
      return (lhs.position, lhs.id.uuidString) < (rhs.position, rhs.id.uuidString)
    case (nil, _?): return true
    case (_?, nil): return false
    case let (l?, r?):
      if l != r { return l < r }
      return (lhs.position, lhs.id.uuidString) < (rhs.position, rhs.id.uuidString)
    }
  }

  /// Mit Tag aufsteigend, dann ohne Tag, dann nach Titel; zuletzt nach ID (stabil).
  private static func assessmentOrder(_ lhs: Assessment, _ rhs: Assessment) -> Bool {
    switch (lhs.day, rhs.day) {
    case let (l?, r?) where l != r: return l < r
    case (_?, nil): return true
    case (nil, _?): return false
    default: break
    }
    if lhs.title != rhs.title { return lhs.title < rhs.title }
    return lhs.id.uuidString < rhs.id.uuidString
  }
}

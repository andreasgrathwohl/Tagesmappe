import Foundation

/// Neu anzulegende Einträge im Ziel; der Quellplan bleibt unberührt.
public struct CopyResult: Equatable, Sendable {
  /// Neue Planwochen mit neuen IDs; `monday == nil` heißt „nicht zugeordnet“.
  public var planWeeks: [PlanWeek]
  public var assessments: [Assessment]
  /// Nur gesetzt, wenn das Ziel keine Notiz hat.
  public var planNote: String?

  /// Planwochen und Leistungsnachweise ohne Woche.
  public var unassignedCount: Int {
    planWeeks.filter { $0.monday == nil }.count + assessments.filter { $0.monday == nil }.count
  }
}

/// Übernimmt den Plan eines Vorjahres Woche für Woche (FR-15.4): Quellwoche Nummer n → Zielwoche n.
public enum CoursePlanCopier {
  public static func copy(
    sourceWeeks: [TeachingWeek], sourcePlanWeeks: [PlanWeek], sourceAssessments: [Assessment],
    sourceNote: String?,
    targetWeeks: [TeachingWeek], targetPlanWeeks: [PlanWeek], targetAssessments: [Assessment],
    targetNote: String?,
    nextUnassignedPosition: Int, now: Date, makeID: () -> UUID
  ) -> CopyResult {
    let sourceNumberByMonday = Dictionary(
      sourceWeeks.map { ($0.monday, $0.number) }, uniquingKeysWith: { first, _ in first })
    let targetByNumber = Dictionary(
      targetWeeks.map { ($0.number, $0) }, uniquingKeysWith: { first, _ in first })
    let occupiedMondays = Set(
      targetPlanWeeks.filter { !$0.isEmpty }.compactMap(\.monday))

    // Planwochen: leere entfallen; zugeordnete nach Wochennummer, je Woche gewinnt die zuletzt
    // geänderte, die übrigen sowie Verwaiste und bisher Nicht-Zugeordnete folgen nach Position.
    var assigned: [(number: Int, planWeek: PlanWeek)] = []
    var leftovers: [PlanWeek] = []
    for planWeek in sourcePlanWeeks where !planWeek.isEmpty {
      if let monday = planWeek.monday, let number = sourceNumberByMonday[monday] {
        assigned.append((number, planWeek))
      } else {
        leftovers.append(planWeek)
      }
    }
    assigned.sort { lhs, rhs in
      if lhs.number != rhs.number { return lhs.number < rhs.number }
      if lhs.planWeek.updatedAt != rhs.planWeek.updatedAt {
        return lhs.planWeek.updatedAt > rhs.planWeek.updatedAt
      }
      return (lhs.planWeek.position, lhs.planWeek.id.uuidString)
        < (rhs.planWeek.position, rhs.planWeek.id.uuidString)
    }
    leftovers.sort { ($0.position, $0.id.uuidString) < ($1.position, $1.id.uuidString) }

    var placed: [PlanWeek] = []
    var overflow: [PlanWeek] = []
    var usedNumbers = Set<Int>()
    for (number, planWeek) in assigned {
      if let week = targetByNumber[number], !occupiedMondays.contains(week.monday),
        usedNumbers.insert(number).inserted
      {
        placed.append(
          PlanWeek(
            id: makeID(), monday: week.monday, position: 0, topic: planWeek.topic,
            notes: planWeek.notes, updatedAt: now))
      } else {
        overflow.append(planWeek)
      }
    }
    overflow.append(contentsOf: leftovers)
    var position = nextUnassignedPosition
    for planWeek in overflow {
      placed.append(
        PlanWeek(
          id: makeID(), monday: nil, position: position, topic: planWeek.topic,
          notes: planWeek.notes, updatedAt: now))
      position += 1
    }

    // Leistungsnachweise: gleiche Wochennummer, sonst ohne Woche und ohne Tag; Gleiches im Ziel entfällt.
    var seen = Set(targetAssessments.map(key))
    var newAssessments: [Assessment] = []
    for assessment in sourceAssessments {
      var copy = assessment
      copy.id = makeID()
      copy.updatedAt = now
      if let monday = assessment.monday, let number = sourceNumberByMonday[monday],
        let week = targetByNumber[number]
      {
        copy = PlanLayouter.assign(copy, to: week)
      } else {
        copy.monday = nil
        copy.day = nil
      }
      if seen.insert(key(copy)).inserted { newAssessments.append(copy) }
    }

    let hasTargetNote = !(targetNote?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty
    let trimmedSource = sourceNote?.trimmingCharacters(in: .whitespacesAndNewlines)
    let note = (!hasTargetNote && !(trimmedSource ?? "").isEmpty) ? trimmedSource : nil

    return CopyResult(planWeeks: placed, assessments: newAssessments, planNote: note)
  }

  private struct AssessmentKey: Hashable {
    let monday: CalendarDay?
    let day: CalendarDay?
    let kind: AssessmentKind
    let title: String
  }

  private static func key(_ assessment: Assessment) -> AssessmentKey {
    AssessmentKey(
      monday: assessment.monday, day: assessment.day, kind: assessment.kind,
      title: assessment.title.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}

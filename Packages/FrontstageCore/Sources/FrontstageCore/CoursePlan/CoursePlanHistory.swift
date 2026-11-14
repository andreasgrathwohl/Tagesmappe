import Foundation

/// Findet frühere Schuljahre desselben Jahresplans (FR-15.3).
public enum CoursePlanHistory {
  /// Gleiches Fach (normalisiert) und gleicher Jahrgang, kleineres `startYear`; neuestes zuerst.
  public static func earlier(than key: CoursePlanKey, among keys: [CoursePlanKey]) -> [CoursePlanKey] {
    keys
      .filter {
        $0.subject == key.subject && $0.gradeLevel == key.gradeLevel && $0.startYear < key.startYear
      }
      .sorted { $0.startYear > $1.startYear }
  }
}

/// Eine Spalte des Vergleichs: ein Schuljahr mit seinen Wochen und Einträgen.
public struct ComparisonColumn: Sendable {
  public let key: CoursePlanKey
  public let weeks: [TeachingWeek]
  public let planWeeks: [PlanWeek]
  public let assessments: [Assessment]

  public init(
    key: CoursePlanKey, weeks: [TeachingWeek], planWeeks: [PlanWeek], assessments: [Assessment]
  ) {
    self.key = key
    self.weeks = weeks
    self.planWeeks = planWeeks
    self.assessments = assessments
  }
}

public struct ComparisonCell: Hashable, Sendable {
  public let week: TeachingWeek
  public let topic: String?
  public let assessments: [Assessment]
  /// Erste Woche des zweiten Halbjahrs in dieser Spalte.
  public let startsSecondTerm: Bool
}

public struct ComparisonRow: Hashable, Sendable {
  public let number: Int
  /// Je Spalte; `nil` heißt: dieses Schuljahr hat diese Woche nicht.
  public let cells: [ComparisonCell?]
}

/// Legt mehrere Schuljahre Woche für Woche nebeneinander (Unterrichtswoche n ↔ Zeile n).
public enum CoursePlanComparison {
  public static func rows(_ columns: [ComparisonColumn]) -> [ComparisonRow] {
    let perColumn: [[Int: ComparisonCell]] = columns.map { column in
      let layout = PlanLayouter.layout(
        weeks: column.weeks, planWeeks: column.planWeeks, assessments: column.assessments)
      let firstSecond = layout.second.first?.week.number
      var cells: [Int: ComparisonCell] = [:]
      for entry in layout.first + layout.second {
        cells[entry.week.number] = ComparisonCell(
          week: entry.week, topic: entry.planWeek?.topic, assessments: entry.assessments,
          startsSecondTerm: entry.week.number == firstSecond)
      }
      return cells
    }
    let maxWeeks = columns.map { $0.weeks.count }.max() ?? 0
    guard maxWeeks > 0 else { return [] }
    return (1...maxWeeks).map { number in
      ComparisonRow(number: number, cells: perColumn.map { $0[number] })
    }
  }
}

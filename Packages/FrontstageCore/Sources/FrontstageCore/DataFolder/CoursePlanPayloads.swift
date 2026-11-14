import Foundation

/// Inhalt eines Schuljahrs (Datenordner, ADR-0012).
public struct SchoolYearPayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var firstDayText: String
  public var secondTermStartText: String
  public var lastDayText: String
  /// Jahrgang von Hand je normalisierter Klasse (zum Beispiel `"ef": 11`).
  public var gradeOverrides: [String: Int]

  public init(
    createdAt: Date, firstDayText: String, secondTermStartText: String, lastDayText: String,
    gradeOverrides: [String: Int]
  ) {
    self.createdAt = createdAt
    self.firstDayText = firstDayText
    self.secondTermStartText = secondTermStartText
    self.lastDayText = lastDayText
    self.gradeOverrides = gradeOverrides
  }
}

/// Inhalt eines Jahresplans (Fach und Jahrgang je Startjahr).
public struct CoursePlanPayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var subjectText: String
  public var gradeLevel: Int
  public var startYear: Int
  public var notes: String?

  public init(createdAt: Date, subjectText: String, gradeLevel: Int, startYear: Int, notes: String?) {
    self.createdAt = createdAt
    self.subjectText = subjectText
    self.gradeLevel = gradeLevel
    self.startYear = startYear
    self.notes = notes
  }
}

/// Inhalt einer Planwoche; `coursePlanID` verweist auf den Jahresplan.
public struct PlanWeekPayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var coursePlanID: UUID?
  public var mondayText: String?
  public var position: Int
  public var topic: String?
  public var notes: String?
  public var updatedAt: Date

  public init(
    createdAt: Date, coursePlanID: UUID?, mondayText: String?, position: Int, topic: String?, notes: String?,
    updatedAt: Date
  ) {
    self.createdAt = createdAt
    self.coursePlanID = coursePlanID
    self.mondayText = mondayText
    self.position = position
    self.topic = topic
    self.notes = notes
    self.updatedAt = updatedAt
  }
}

/// Inhalt eines Leistungsnachweises; `coursePlanID` verweist auf den Jahresplan.
public struct AssessmentPayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var coursePlanID: UUID?
  public var mondayText: String?
  public var dayText: String?
  public var kindRaw: String
  public var title: String
  public var updatedAt: Date

  public init(
    createdAt: Date, coursePlanID: UUID?, mondayText: String?, dayText: String?, kindRaw: String, title: String,
    updatedAt: Date
  ) {
    self.createdAt = createdAt
    self.coursePlanID = coursePlanID
    self.mondayText = mondayText
    self.dayText = dayText
    self.kindRaw = kindRaw
    self.title = title
    self.updatedAt = updatedAt
  }
}

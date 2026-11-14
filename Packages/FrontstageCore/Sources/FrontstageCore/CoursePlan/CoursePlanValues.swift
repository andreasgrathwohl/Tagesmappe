import Foundation

/// Art eines Leistungsnachweises (Glossar): Test oder Klassenarbeit.
public enum AssessmentKind: String, Codable, Sendable, CaseIterable { case test, classTest }

/// Schlüssel eines Jahresplans (ADR-0013): Fach (normalisiert verglichen) + Jahrgang + Schuljahr.
public struct CoursePlanKey: Hashable, Codable, Sendable {
  public let subject: Subject
  public let gradeLevel: GradeLevel
  public let startYear: Int

  public init(subject: Subject, gradeLevel: GradeLevel, startYear: Int) {
    self.subject = subject
    self.gradeLevel = gradeLevel
    self.startYear = startYear
  }
}

/// Planwoche (Glossar); `monday == nil` heißt „nicht zugeordnet“.
public struct PlanWeek: Hashable, Sendable {
  public var id: UUID
  public var monday: CalendarDay?
  public var position: Int
  public var topic: String?
  public var notes: String?
  public var updatedAt: Date

  /// Normalisiert Thema und Notizen wie `LessonInfo` (getrimmt, leer wird `nil`).
  public init(
    id: UUID, monday: CalendarDay?, position: Int, topic: String?, notes: String?,
    updatedAt: Date
  ) {
    self.id = id
    self.monday = monday
    self.position = position
    self.topic = Self.normalize(topic)
    self.notes = Self.normalize(notes)
    self.updatedAt = updatedAt
  }

  /// Weder Thema noch Notizen.
  public var isEmpty: Bool {
    Self.normalize(topic) == nil && Self.normalize(notes) == nil
  }

  private static func normalize(_ text: String?) -> String? {
    guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty
    else { return nil }
    return trimmed
  }
}

/// Leistungsnachweis (Glossar).
public struct Assessment: Hashable, Sendable {
  public var id: UUID
  public var monday: CalendarDay?
  public var day: CalendarDay?
  public var kind: AssessmentKind
  public var title: String
  public var updatedAt: Date

  public init(
    id: UUID, monday: CalendarDay?, day: CalendarDay?, kind: AssessmentKind, title: String,
    updatedAt: Date
  ) {
    self.id = id
    self.monday = monday
    self.day = day
    self.kind = kind
    self.title = title
    self.updatedAt = updatedAt
  }
}

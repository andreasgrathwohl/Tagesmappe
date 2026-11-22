import Foundation

// Reine Wertabbilder der gespeicherten Datensätze für den Abgleich nach der Synchronisierung.
// Sie tragen nur, was die Zusammenführ-Logik braucht; die App füllt sie aus ihren SwiftData-Modellen.

/// Ein Stundenplan-Datensatz.
public struct TimetableSnapshot: Hashable, Sendable {
  public var id: UUID
  public var isActive: Bool
  public var createdAt: Date

  public init(id: UUID, isActive: Bool, createdAt: Date) {
    self.id = id
    self.isActive = isActive
    self.createdAt = createdAt
  }
}

/// Ein Stundenplan-Eintrag samt seinem Stundenplan.
public struct TimetableEntrySnapshot: Hashable, Sendable {
  public var id: UUID
  public var timetableID: UUID?
  public var entry: TimetableEntry
  public var createdAt: Date

  public init(id: UUID, timetableID: UUID?, entry: TimetableEntry, createdAt: Date) {
    self.id = id
    self.timetableID = timetableID
    self.entry = entry
    self.createdAt = createdAt
  }
}

/// Eine Zuordnung einer Datei zu einer Stunde.
public struct MaterialLinkSnapshot: Hashable, Sendable {
  public var id: UUID
  public var lessonKeyText: String
  /// `nil`, solange der Verweis noch nicht abgeglichen ist.
  public var fileIdentity: String?
  public var createdAt: Date
  /// Die Zuordnung trägt eine Lösung (FR-6.3).
  public var hasSolution: Bool

  public init(id: UUID, lessonKeyText: String, fileIdentity: String?, createdAt: Date, hasSolution: Bool = false) {
    self.id = id
    self.lessonKeyText = lessonKeyText
    self.fileIdentity = fileIdentity
    self.createdAt = createdAt
    self.hasSolution = hasSolution
  }
}

/// Eine Stiftnotiz zu einer Seite einer Zuordnung.
public struct PenNoteSnapshot: Hashable, Sendable {
  public var id: UUID
  public var linkID: UUID?
  public var pageIndex: Int
  public var createdAt: Date
  public var updatedAt: Date

  public init(id: UUID, linkID: UUID?, pageIndex: Int, createdAt: Date, updatedAt: Date) {
    self.id = id
    self.linkID = linkID
    self.pageIndex = pageIndex
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}

/// Die Stundenangaben einer Stunde mit dem Änderungszeitpunkt je Feld.
public struct LessonInfoSnapshot: Hashable, Sendable {
  public var id: UUID
  public var lessonKeyText: String
  public var createdAt: Date
  public var fieldUpdatedAt: [LessonInfoField: Date]

  public init(id: UUID, lessonKeyText: String, createdAt: Date, fieldUpdatedAt: [LessonInfoField: Date]) {
    self.id = id
    self.lessonKeyText = lessonKeyText
    self.createdAt = createdAt
    self.fieldUpdatedAt = fieldUpdatedAt
  }
}

/// Eine Abweichung vom Stundenplan.
public struct ScheduleChangeSnapshot: Hashable, Sendable {
  public var id: UUID
  public var change: ScheduleChange
  public var createdAt: Date

  public init(id: UUID, change: ScheduleChange, createdAt: Date) {
    self.id = id
    self.change = change
    self.createdAt = createdAt
  }
}

/// Ein unterrichtsfreier Zeitraum.
public struct NonTeachingPeriodSnapshot: Hashable, Sendable {
  public var id: UUID
  public var period: NonTeachingPeriod
  public var createdAt: Date

  public init(id: UUID, period: NonTeachingPeriod, createdAt: Date) {
    self.id = id
    self.period = period
    self.createdAt = createdAt
  }
}

/// Der gesamte Bestand, den der Abgleich betrachtet.
public struct SyncSnapshot: Sendable {
  public var timetables: [TimetableSnapshot] = []
  public var entries: [TimetableEntrySnapshot] = []
  public var links: [MaterialLinkSnapshot] = []
  public var penNotes: [PenNoteSnapshot] = []
  public var lessonInfos: [LessonInfoSnapshot] = []
  public var scheduleChanges: [ScheduleChangeSnapshot] = []
  public var nonTeachingPeriods: [NonTeachingPeriodSnapshot] = []

  public init(
    timetables: [TimetableSnapshot] = [], entries: [TimetableEntrySnapshot] = [],
    links: [MaterialLinkSnapshot] = [], penNotes: [PenNoteSnapshot] = [],
    lessonInfos: [LessonInfoSnapshot] = [], scheduleChanges: [ScheduleChangeSnapshot] = [],
    nonTeachingPeriods: [NonTeachingPeriodSnapshot] = []
  ) {
    self.timetables = timetables
    self.entries = entries
    self.links = links
    self.penNotes = penNotes
    self.lessonInfos = lessonInfos
    self.scheduleChanges = scheduleChanges
    self.nonTeachingPeriods = nonTeachingPeriods
  }
}

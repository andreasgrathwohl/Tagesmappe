/// Modell eines Datensatzes; `rawValue` ist der Unterordner im Datenordner.
public enum SyncModel: String, Codable, Sendable, CaseIterable {
  case timetable = "Timetable"
  case timetableEntry = "TimetableEntry"
  case nonTeachingPeriod = "NonTeachingPeriod"
  case scheduleChange = "ScheduleChange"
  case materialLink = "MaterialLink"
  case penNote = "PenNote"
  case lessonInfo = "LessonInfo"
  case boardPage = "BoardPage"
  case schoolYear = "SchoolYear"
  case coursePlan = "CoursePlan"
  case planWeek = "PlanWeek"
  case assessment = "Assessment"

  /// Eltern vor Kindern (= Reihenfolge von `allCases`).
  public static var applyOrder: [SyncModel] { allCases }
}

/// Verweis auf eine Anhang-Datei; die Datei heißt `<Kennung>.<field>.<hash>.bin`.
public struct AttachmentRef: Codable, Hashable, Sendable {
  public var hash: String
  public var byteCount: Int

  public init(hash: String, byteCount: Int) {
    self.hash = hash
    self.byteCount = byteCount
  }
}

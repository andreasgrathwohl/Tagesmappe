import Foundation

/// Inhalt eines Stundenplans (ohne Einträge; die sind eigene Datensätze).
public struct TimetablePayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var name: String
  public var validFromText: String?
  public var validToText: String?
  public var sourceKindRaw: String
  public var sourceFetchedAt: Date?
  public var weekVariantCount: Int
  public var referenceWeekAText: String?
  public var bellSchedule: BellSchedule?
  public var isActive: Bool

  public init(
    createdAt: Date, name: String, validFromText: String?, validToText: String?, sourceKindRaw: String,
    sourceFetchedAt: Date?, weekVariantCount: Int, referenceWeekAText: String?, bellSchedule: BellSchedule?,
    isActive: Bool
  ) {
    self.createdAt = createdAt
    self.name = name
    self.validFromText = validFromText
    self.validToText = validToText
    self.sourceKindRaw = sourceKindRaw
    self.sourceFetchedAt = sourceFetchedAt
    self.weekVariantCount = weekVariantCount
    self.referenceWeekAText = referenceWeekAText
    self.bellSchedule = bellSchedule
    self.isActive = isActive
  }
}

public struct TimetableEntryPayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var weekVariantRaw: String?
  public var weekdayRaw: Int
  public var period: Int
  public var schoolClassText: String
  public var subjectText: String
  public var originRaw: String
  public var isManuallyEdited: Bool
  public var timetableID: UUID?

  public init(
    createdAt: Date, weekVariantRaw: String?, weekdayRaw: Int, period: Int, schoolClassText: String,
    subjectText: String, originRaw: String, isManuallyEdited: Bool, timetableID: UUID?
  ) {
    self.createdAt = createdAt
    self.weekVariantRaw = weekVariantRaw
    self.weekdayRaw = weekdayRaw
    self.period = period
    self.schoolClassText = schoolClassText
    self.subjectText = subjectText
    self.originRaw = originRaw
    self.isManuallyEdited = isManuallyEdited
    self.timetableID = timetableID
  }
}

public struct NonTeachingPeriodPayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var fromText: String
  public var toText: String
  public var title: String

  public init(createdAt: Date, fromText: String, toText: String, title: String) {
    self.createdAt = createdAt
    self.fromText = fromText
    self.toText = toText
    self.title = title
  }
}

public struct ScheduleChangePayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var kindRaw: String
  public var originRaw: String
  public var dayText: String
  public var lessonKeyText: String?
  public var period: Int?
  public var schoolClassText: String?
  public var subjectText: String?

  public init(
    createdAt: Date, kindRaw: String, originRaw: String, dayText: String, lessonKeyText: String?,
    period: Int?, schoolClassText: String?, subjectText: String?
  ) {
    self.createdAt = createdAt
    self.kindRaw = kindRaw
    self.originRaw = originRaw
    self.dayText = dayText
    self.lessonKeyText = lessonKeyText
    self.period = period
    self.schoolClassText = schoolClassText
    self.subjectText = subjectText
  }
}

public struct MaterialLinkPayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var lessonKeyText: String
  public var dayText: String
  public var position: Int
  public var folderGrantName: String
  public var relativePath: String
  public var displayName: String
  public var fileKindRaw: String
  public var oneDriveItemID: String?
  public var oneDriveDriveID: String?

  public init(
    createdAt: Date, lessonKeyText: String, dayText: String, position: Int, folderGrantName: String,
    relativePath: String, displayName: String, fileKindRaw: String, oneDriveItemID: String?,
    oneDriveDriveID: String?
  ) {
    self.createdAt = createdAt
    self.lessonKeyText = lessonKeyText
    self.dayText = dayText
    self.position = position
    self.folderGrantName = folderGrantName
    self.relativePath = relativePath
    self.displayName = displayName
    self.fileKindRaw = fileKindRaw
    self.oneDriveItemID = oneDriveItemID
    self.oneDriveDriveID = oneDriveDriveID
  }
}

public struct PenNotePayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var materialLinkID: UUID?
  public var pageIndex: Int
  public var drawing: AttachmentRef?
  public var pageWidth: Double
  public var pageHeight: Double
  public var updatedAt: Date

  public init(
    createdAt: Date, materialLinkID: UUID?, pageIndex: Int, drawing: AttachmentRef?, pageWidth: Double,
    pageHeight: Double, updatedAt: Date
  ) {
    self.createdAt = createdAt
    self.materialLinkID = materialLinkID
    self.pageIndex = pageIndex
    self.drawing = drawing
    self.pageWidth = pageWidth
    self.pageHeight = pageHeight
    self.updatedAt = updatedAt
  }
}

public struct LessonInfoPayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var lessonKeyText: String
  public var topic: String?
  public var toPrepare: String?
  public var homework: String?
  public var updatedAt: Date
  public var topicUpdatedAt: Date?
  public var toPrepareUpdatedAt: Date?
  public var homeworkUpdatedAt: Date?

  public init(
    createdAt: Date, lessonKeyText: String, topic: String?, toPrepare: String?, homework: String?,
    updatedAt: Date, topicUpdatedAt: Date?, toPrepareUpdatedAt: Date?, homeworkUpdatedAt: Date?
  ) {
    self.createdAt = createdAt
    self.lessonKeyText = lessonKeyText
    self.topic = topic
    self.toPrepare = toPrepare
    self.homework = homework
    self.updatedAt = updatedAt
    self.topicUpdatedAt = topicUpdatedAt
    self.toPrepareUpdatedAt = toPrepareUpdatedAt
    self.homeworkUpdatedAt = homeworkUpdatedAt
  }
}

public struct BoardPagePayload: Codable, Hashable, Sendable {
  public var createdAt: Date
  public var lessonKeyText: String
  public var position: Int
  public var backgroundRaw: String
  public var backgroundImage: AttachmentRef?
  public var drawing: AttachmentRef?
  public var updatedAt: Date

  public init(
    createdAt: Date, lessonKeyText: String, position: Int, backgroundRaw: String,
    backgroundImage: AttachmentRef?, drawing: AttachmentRef?, updatedAt: Date
  ) {
    self.createdAt = createdAt
    self.lessonKeyText = lessonKeyText
    self.position = position
    self.backgroundRaw = backgroundRaw
    self.backgroundImage = backgroundImage
    self.drawing = drawing
    self.updatedAt = updatedAt
  }
}

/// Inhalt eines Datensatzes, je Modell eine eigene Struktur.
public enum RecordPayload: Hashable, Sendable {
  case timetable(TimetablePayload)
  case timetableEntry(TimetableEntryPayload)
  case nonTeachingPeriod(NonTeachingPeriodPayload)
  case scheduleChange(ScheduleChangePayload)
  case materialLink(MaterialLinkPayload)
  case penNote(PenNotePayload)
  case lessonInfo(LessonInfoPayload)
  case boardPage(BoardPagePayload)

  public var model: SyncModel {
    switch self {
    case .timetable: .timetable
    case .timetableEntry: .timetableEntry
    case .nonTeachingPeriod: .nonTeachingPeriod
    case .scheduleChange: .scheduleChange
    case .materialLink: .materialLink
    case .penNote: .penNote
    case .lessonInfo: .lessonInfo
    case .boardPage: .boardPage
    }
  }

  /// Feldname → Anhang (nur gesetzte).
  public var attachments: [String: AttachmentRef] {
    var result: [String: AttachmentRef] = [:]
    switch self {
    case .penNote(let note):
      if let drawing = note.drawing { result["drawing"] = drawing }
    case .boardPage(let page):
      if let drawing = page.drawing { result["drawing"] = drawing }
      if let image = page.backgroundImage { result["backgroundImage"] = image }
    default:
      break
    }
    return result
  }

  /// `timetableID` bzw. `materialLinkID`.
  public var parentID: UUID? {
    switch self {
    case .timetableEntry(let entry): entry.timetableID
    case .penNote(let note): note.materialLinkID
    default: nil
    }
  }
}

extension RecordPayload: Encodable {
  /// Kodiert nur den Inhalt (ohne Fallkennung); das Modell steht in der Hülle.
  public func encode(to encoder: any Encoder) throws {
    switch self {
    case .timetable(let value): try value.encode(to: encoder)
    case .timetableEntry(let value): try value.encode(to: encoder)
    case .nonTeachingPeriod(let value): try value.encode(to: encoder)
    case .scheduleChange(let value): try value.encode(to: encoder)
    case .materialLink(let value): try value.encode(to: encoder)
    case .penNote(let value): try value.encode(to: encoder)
    case .lessonInfo(let value): try value.encode(to: encoder)
    case .boardPage(let value): try value.encode(to: encoder)
    }
  }

  /// Liest den Inhalt passend zum Modell.
  init(model: SyncModel, from decoder: any Decoder) throws {
    switch model {
    case .timetable: self = .timetable(try TimetablePayload(from: decoder))
    case .timetableEntry: self = .timetableEntry(try TimetableEntryPayload(from: decoder))
    case .nonTeachingPeriod: self = .nonTeachingPeriod(try NonTeachingPeriodPayload(from: decoder))
    case .scheduleChange: self = .scheduleChange(try ScheduleChangePayload(from: decoder))
    case .materialLink: self = .materialLink(try MaterialLinkPayload(from: decoder))
    case .penNote: self = .penNote(try PenNotePayload(from: decoder))
    case .lessonInfo: self = .lessonInfo(try LessonInfoPayload(from: decoder))
    case .boardPage: self = .boardPage(try BoardPagePayload(from: decoder))
    }
  }
}

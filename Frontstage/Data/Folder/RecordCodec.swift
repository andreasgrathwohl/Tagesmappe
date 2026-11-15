import Foundation
import FrontstageCore
import SwiftData

/// Ein Datensatz mit Inhalt und den Bytes seiner Anhänge (Feldname → Daten).
struct ExportedRecord: Sendable {
  let id: UUID
  let payload: RecordPayload
  let attachmentData: [String: Data]
}

enum RecordCodecError: Error, Equatable {
  /// Der Elterndatensatz (Stundenplan bzw. Zuordnung) fehlt lokal.
  case missingParent(UUID)
  /// Im Inhalt ist ein Anhang genannt, seine Bytes fehlen aber (Feldname).
  case attachmentMissing(String)
}

/// Übersetzt zwischen den SwiftData-Datensätzen und dem Inhalt der Dateien im Datenordner (ADR-0012).
/// Der Codec speichert nie selbst; das tut der Aufrufer nach einer ganzen Übernahme.
///
/// Swift-Hinweis: `@Model`-Klassen sind nicht `Sendable` und an ihren `ModelContext` gebunden;
/// deshalb läuft der Codec auf dem Hauptakteur und reicht nur Werttypen (`ExportedRecord`) heraus.
@MainActor enum RecordCodec {

  // MARK: - Export

  static func exportAll(from context: ModelContext) throws -> [ExportedRecord] {
    var result: [ExportedRecord] = []
    try result += context.fetch(FetchDescriptor<TimetableRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<TimetableEntryRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<NonTeachingPeriodRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<ScheduleChangeRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<MaterialLinkRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<PenNoteRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<LessonInfoRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<BoardPageRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<SchoolYearRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<CoursePlanRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<PlanWeekRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<AssessmentRecord>()).map { export($0) }
    try result += context.fetch(FetchDescriptor<ThemeRecord>()).map { export($0) }
    return result
  }

  /// Nur die genannten Datensätze; unbekannte oder fremde Modelle werden übergangen.
  static func export(_ identifiers: Set<PersistentIdentifier>, from context: ModelContext) throws
    -> [ExportedRecord]
  {
    var result: [ExportedRecord] = []
    for identifier in identifiers {
      let model = context.model(for: identifier)
      switch model {
      case let record as TimetableRecord: result.append(export(record))
      case let record as TimetableEntryRecord: result.append(export(record))
      case let record as NonTeachingPeriodRecord: result.append(export(record))
      case let record as ScheduleChangeRecord: result.append(export(record))
      case let record as MaterialLinkRecord: result.append(export(record))
      case let record as PenNoteRecord: result.append(export(record))
      case let record as LessonInfoRecord: result.append(export(record))
      case let record as BoardPageRecord: result.append(export(record))
      case let record as SchoolYearRecord: result.append(export(record))
      case let record as CoursePlanRecord: result.append(export(record))
      case let record as PlanWeekRecord: result.append(export(record))
      case let record as AssessmentRecord: result.append(export(record))
      case let record as ThemeRecord: result.append(export(record))
      default: continue
      }
    }
    return result
  }

  /// Alle lokalen Kennungen; geladen wird nur das Feld `id`.
  static func liveIDs(in context: ModelContext) throws -> Set<UUID> {
    var ids: Set<UUID> = []
    ids.formUnion(try fetchIDs(TimetableRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(TimetableEntryRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(NonTeachingPeriodRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(ScheduleChangeRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(MaterialLinkRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(PenNoteRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(LessonInfoRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(BoardPageRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(SchoolYearRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(CoursePlanRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(PlanWeekRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(AssessmentRecord.self, \.id, in: context))
    ids.formUnion(try fetchIDs(ThemeRecord.self, \.id, in: context))
    return ids
  }

  private static func fetchIDs<T: PersistentModel>(
    _ type: T.Type, _ keyPath: KeyPath<T, UUID>, in context: ModelContext
  ) throws -> [UUID] {
    var descriptor = FetchDescriptor<T>()
    descriptor.propertiesToFetch = [keyPath]
    return try context.fetch(descriptor).map { $0[keyPath: keyPath] }
  }

  static func state(of record: ExportedRecord) throws -> LocalRecordState {
    LocalRecordState(
      id: record.id, model: record.payload.model,
      payloadHash: try DataFolderCoding.payloadHash(record.payload))
  }

  // MARK: - Datensatz → Inhalt

  /// Verweis samt Bytes; `nil`, wenn kein Anhang gesetzt ist.
  private static func attachment(_ data: Data?, field: String, into files: inout [String: Data])
    -> AttachmentRef?
  {
    guard let data else { return nil }
    files[field] = data
    return AttachmentRef(hash: ContentHash.fnv1a64(data), byteCount: data.count)
  }

  private static func export(_ record: TimetableRecord) -> ExportedRecord {
    // Ein unlesbares Zeitraster wird wie „keines“ behandelt (wie in `makeTimetable()`).
    let bells = record.bellScheduleData.flatMap { try? JSONDecoder().decode(BellSchedule.self, from: $0) }
    let payload = TimetablePayload(
      createdAt: record.createdAt, name: record.name, validFromText: record.validFromText,
      validToText: record.validToText, sourceKindRaw: record.sourceKindRaw,
      sourceFetchedAt: record.sourceFetchedAt, weekVariantCount: record.weekVariantCount,
      referenceWeekAText: record.referenceWeekAText, bellSchedule: bells, isActive: record.isActive)
    return ExportedRecord(id: record.id, payload: .timetable(payload), attachmentData: [:])
  }

  private static func export(_ record: TimetableEntryRecord) -> ExportedRecord {
    let payload = TimetableEntryPayload(
      createdAt: record.createdAt, weekVariantRaw: record.weekVariantRaw, weekdayRaw: record.weekdayRaw,
      period: record.period, schoolClassText: record.schoolClassText, subjectText: record.subjectText,
      originRaw: record.originRaw, isManuallyEdited: record.isManuallyEdited,
      timetableID: record.timetable?.id)
    return ExportedRecord(id: record.id, payload: .timetableEntry(payload), attachmentData: [:])
  }

  private static func export(_ record: NonTeachingPeriodRecord) -> ExportedRecord {
    let payload = NonTeachingPeriodPayload(
      createdAt: record.createdAt, fromText: record.fromText, toText: record.toText, title: record.title)
    return ExportedRecord(id: record.id, payload: .nonTeachingPeriod(payload), attachmentData: [:])
  }

  private static func export(_ record: ScheduleChangeRecord) -> ExportedRecord {
    let payload = ScheduleChangePayload(
      createdAt: record.createdAt, kindRaw: record.kindRaw, originRaw: record.originRaw,
      dayText: record.dayText, lessonKeyText: record.lessonKeyText, period: record.period,
      schoolClassText: record.schoolClassText, subjectText: record.subjectText)
    return ExportedRecord(id: record.id, payload: .scheduleChange(payload), attachmentData: [:])
  }

  private static func export(_ record: MaterialLinkRecord) -> ExportedRecord {
    let payload = MaterialLinkPayload(
      createdAt: record.createdAt, lessonKeyText: record.lessonKeyText, dayText: record.dayText,
      position: record.position, folderGrantName: record.folderGrantName,
      relativePath: record.relativePath, displayName: record.displayName,
      fileKindRaw: record.fileKindRaw, oneDriveItemID: record.oneDriveItemID,
      oneDriveDriveID: record.oneDriveDriveID)
    return ExportedRecord(id: record.id, payload: .materialLink(payload), attachmentData: [:])
  }

  private static func export(_ record: PenNoteRecord) -> ExportedRecord {
    var files: [String: Data] = [:]
    let drawing = attachment(record.drawingData, field: "drawing", into: &files)
    let payload = PenNotePayload(
      createdAt: record.createdAt, materialLinkID: record.materialLink?.id, pageIndex: record.pageIndex,
      drawing: drawing, pageWidth: record.pageWidth, pageHeight: record.pageHeight,
      updatedAt: record.updatedAt)
    return ExportedRecord(id: record.id, payload: .penNote(payload), attachmentData: files)
  }

  private static func export(_ record: LessonInfoRecord) -> ExportedRecord {
    let payload = LessonInfoPayload(
      createdAt: record.createdAt, lessonKeyText: record.lessonKeyText, topic: record.topic,
      toPrepare: record.toPrepare, homework: record.homework, updatedAt: record.updatedAt,
      topicUpdatedAt: record.topicUpdatedAt, toPrepareUpdatedAt: record.toPrepareUpdatedAt,
      homeworkUpdatedAt: record.homeworkUpdatedAt)
    return ExportedRecord(id: record.id, payload: .lessonInfo(payload), attachmentData: [:])
  }

  private static func export(_ record: BoardPageRecord) -> ExportedRecord {
    var files: [String: Data] = [:]
    let image = attachment(record.backgroundImageData, field: "backgroundImage", into: &files)
    let drawing = attachment(record.drawingData, field: "drawing", into: &files)
    let payload = BoardPagePayload(
      createdAt: record.createdAt, lessonKeyText: record.lessonKeyText, position: record.position,
      backgroundRaw: record.backgroundRaw, backgroundImage: image, drawing: drawing,
      updatedAt: record.updatedAt)
    return ExportedRecord(id: record.id, payload: .boardPage(payload), attachmentData: files)
  }

  private static func export(_ record: SchoolYearRecord) -> ExportedRecord {
    // Unlesbare Zuordnung von Hand wird wie „keine“ behandelt.
    let overrides =
      record.gradeOverridesData.flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]
    let payload = SchoolYearPayload(
      createdAt: record.createdAt, firstDayText: record.firstDayText,
      secondTermStartText: record.secondTermStartText, lastDayText: record.lastDayText,
      gradeOverrides: overrides)
    return ExportedRecord(id: record.id, payload: .schoolYear(payload), attachmentData: [:])
  }

  private static func export(_ record: CoursePlanRecord) -> ExportedRecord {
    let payload = CoursePlanPayload(
      createdAt: record.createdAt, subjectText: record.subjectText, gradeLevel: record.gradeLevel,
      startYear: record.startYear, notes: record.notes)
    return ExportedRecord(id: record.id, payload: .coursePlan(payload), attachmentData: [:])
  }

  private static func export(_ record: PlanWeekRecord) -> ExportedRecord {
    let payload = PlanWeekPayload(
      createdAt: record.createdAt, coursePlanID: record.coursePlan?.id, mondayText: record.mondayText,
      position: record.position, topic: record.topic, notes: record.notes, updatedAt: record.updatedAt)
    return ExportedRecord(id: record.id, payload: .planWeek(payload), attachmentData: [:])
  }

  private static func export(_ record: AssessmentRecord) -> ExportedRecord {
    let payload = AssessmentPayload(
      createdAt: record.createdAt, coursePlanID: record.coursePlan?.id, mondayText: record.mondayText,
      dayText: record.dayText, kindRaw: record.kindRaw, title: record.title, updatedAt: record.updatedAt)
    return ExportedRecord(id: record.id, payload: .assessment(payload), attachmentData: [:])
  }

  private static func export(_ record: ThemeRecord) -> ExportedRecord {
    let payload = ThemePayload(
      createdAt: record.createdAt, baseToneRaw: record.baseToneRaw, accentHex: record.accentHex,
      appearanceModeRaw: record.appearanceModeRaw, updatedAt: record.updatedAt)
    return ExportedRecord(id: record.id, payload: .theme(payload), attachmentData: [:])
  }

  // MARK: - Inhalt → Datensatz

  /// Einfügen oder nach `id` überschreiben; Beziehungen über `timetableID`/`materialLinkID`.
  /// Speichert nicht. Wirft vor jeder Änderung, wenn Elterndatensatz oder Anhang fehlt.
  static func upsert(
    _ payload: RecordPayload, id: UUID, attachmentData: [String: Data], into context: ModelContext
  ) throws {
    switch payload {
    case .timetable(let value):
      let record = try existing(TimetableRecord.self, #Predicate<TimetableRecord> { $0.id == id }, in: context)
        ?? insert(TimetableRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.name = value.name
      record.validFromText = value.validFromText
      record.validToText = value.validToText
      record.sourceKindRaw = value.sourceKindRaw
      record.sourceFetchedAt = value.sourceFetchedAt
      record.weekVariantCount = value.weekVariantCount
      record.referenceWeekAText = value.referenceWeekAText
      if let bells = value.bellSchedule {
        record.setBellSchedule(bells)
      } else {
        record.bellScheduleData = nil
      }
      record.isActive = value.isActive

    case .timetableEntry(let value):
      let parent = try timetable(value.timetableID, in: context)
      let record = try existing(TimetableEntryRecord.self, #Predicate<TimetableEntryRecord> { $0.id == id }, in: context)
        ?? insert(TimetableEntryRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.weekVariantRaw = value.weekVariantRaw
      record.weekdayRaw = value.weekdayRaw
      record.period = value.period
      record.schoolClassText = value.schoolClassText
      record.subjectText = value.subjectText
      record.originRaw = value.originRaw
      record.isManuallyEdited = value.isManuallyEdited
      record.timetable = parent

    case .nonTeachingPeriod(let value):
      let record = try existing(NonTeachingPeriodRecord.self, #Predicate<NonTeachingPeriodRecord> { $0.id == id }, in: context)
        ?? insert(NonTeachingPeriodRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.fromText = value.fromText
      record.toText = value.toText
      record.title = value.title

    case .scheduleChange(let value):
      let record = try existing(ScheduleChangeRecord.self, #Predicate<ScheduleChangeRecord> { $0.id == id }, in: context)
        ?? insert(ScheduleChangeRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.kindRaw = value.kindRaw
      record.originRaw = value.originRaw
      record.dayText = value.dayText
      record.lessonKeyText = value.lessonKeyText
      record.period = value.period
      record.schoolClassText = value.schoolClassText
      record.subjectText = value.subjectText

    case .materialLink(let value):
      let record = try existing(MaterialLinkRecord.self, #Predicate<MaterialLinkRecord> { $0.id == id }, in: context)
        ?? insert(MaterialLinkRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.lessonKeyText = value.lessonKeyText
      record.dayText = value.dayText
      record.position = value.position
      record.folderGrantName = value.folderGrantName
      record.relativePath = value.relativePath
      record.displayName = value.displayName
      record.fileKindRaw = value.fileKindRaw
      record.oneDriveItemID = value.oneDriveItemID
      record.oneDriveDriveID = value.oneDriveDriveID

    case .penNote(let value):
      let parent = try materialLink(value.materialLinkID, in: context)
      let drawing = try bytes(of: value.drawing, field: "drawing", in: attachmentData)
      let record = try existing(PenNoteRecord.self, #Predicate<PenNoteRecord> { $0.id == id }, in: context)
        ?? insert(PenNoteRecord(materialLink: nil, pageIndex: 0), id: id, in: context)
      record.createdAt = value.createdAt
      record.materialLink = parent
      record.pageIndex = value.pageIndex
      record.drawingData = drawing
      record.pageWidth = value.pageWidth
      record.pageHeight = value.pageHeight
      record.updatedAt = value.updatedAt

    case .lessonInfo(let value):
      let record = try existing(LessonInfoRecord.self, #Predicate<LessonInfoRecord> { $0.id == id }, in: context)
        ?? insert(LessonInfoRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.lessonKeyText = value.lessonKeyText
      record.topic = value.topic
      record.toPrepare = value.toPrepare
      record.homework = value.homework
      record.updatedAt = value.updatedAt
      record.topicUpdatedAt = value.topicUpdatedAt
      record.toPrepareUpdatedAt = value.toPrepareUpdatedAt
      record.homeworkUpdatedAt = value.homeworkUpdatedAt

    case .boardPage(let value):
      let image = try bytes(of: value.backgroundImage, field: "backgroundImage", in: attachmentData)
      let drawing = try bytes(of: value.drawing, field: "drawing", in: attachmentData)
      let record = try existing(BoardPageRecord.self, #Predicate<BoardPageRecord> { $0.id == id }, in: context)
        ?? insert(BoardPageRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.lessonKeyText = value.lessonKeyText
      record.position = value.position
      record.backgroundRaw = value.backgroundRaw
      record.backgroundImageData = image
      record.drawingData = drawing
      record.updatedAt = value.updatedAt

    case .schoolYear(let value):
      let record = try existing(SchoolYearRecord.self, #Predicate<SchoolYearRecord> { $0.id == id }, in: context)
        ?? insert(SchoolYearRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.firstDayText = value.firstDayText
      record.secondTermStartText = value.secondTermStartText
      record.lastDayText = value.lastDayText
      if value.gradeOverrides.isEmpty {
        record.gradeOverridesData = nil
      } else {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        record.gradeOverridesData = try? encoder.encode(value.gradeOverrides)
      }

    case .coursePlan(let value):
      let record = try existing(CoursePlanRecord.self, #Predicate<CoursePlanRecord> { $0.id == id }, in: context)
        ?? insert(CoursePlanRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.subjectText = value.subjectText
      record.gradeLevel = value.gradeLevel
      record.startYear = value.startYear
      record.notes = value.notes

    case .planWeek(let value):
      let parent = try coursePlan(value.coursePlanID, in: context)
      let record = try existing(PlanWeekRecord.self, #Predicate<PlanWeekRecord> { $0.id == id }, in: context)
        ?? insert(PlanWeekRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.coursePlan = parent
      record.mondayText = value.mondayText
      record.position = value.position
      record.topic = value.topic
      record.notes = value.notes
      record.updatedAt = value.updatedAt

    case .assessment(let value):
      let parent = try coursePlan(value.coursePlanID, in: context)
      let record = try existing(AssessmentRecord.self, #Predicate<AssessmentRecord> { $0.id == id }, in: context)
        ?? insert(AssessmentRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.coursePlan = parent
      record.mondayText = value.mondayText
      record.dayText = value.dayText
      record.kindRaw = value.kindRaw
      record.title = value.title
      record.updatedAt = value.updatedAt

    case .theme(let value):
      let record = try existing(ThemeRecord.self, #Predicate<ThemeRecord> { $0.id == id }, in: context)
        ?? insert(ThemeRecord(), id: id, in: context)
      record.createdAt = value.createdAt
      record.baseToneRaw = value.baseToneRaw
      record.accentHex = value.accentHex
      record.appearanceModeRaw = value.appearanceModeRaw
      record.updatedAt = value.updatedAt
    }
  }

  /// Löscht nach Kennung; ein nicht vorhandener Datensatz ist kein Fehler. Kaskaden wie im Modell
  /// (Stundenplan → Einträge, Zuordnung → Stiftnotizen). Speichert nicht.
  static func delete(id: UUID, model: SyncModel, from context: ModelContext) throws {
    switch model {
    case .timetable:
      if let record = try existing(TimetableRecord.self, #Predicate<TimetableRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .timetableEntry:
      if let record = try existing(TimetableEntryRecord.self, #Predicate<TimetableEntryRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .nonTeachingPeriod:
      if let record = try existing(NonTeachingPeriodRecord.self, #Predicate<NonTeachingPeriodRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .scheduleChange:
      if let record = try existing(ScheduleChangeRecord.self, #Predicate<ScheduleChangeRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .materialLink:
      if let record = try existing(MaterialLinkRecord.self, #Predicate<MaterialLinkRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .penNote:
      if let record = try existing(PenNoteRecord.self, #Predicate<PenNoteRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .lessonInfo:
      if let record = try existing(LessonInfoRecord.self, #Predicate<LessonInfoRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .boardPage:
      if let record = try existing(BoardPageRecord.self, #Predicate<BoardPageRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .schoolYear:
      if let record = try existing(SchoolYearRecord.self, #Predicate<SchoolYearRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .coursePlan:
      if let record = try existing(CoursePlanRecord.self, #Predicate<CoursePlanRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .planWeek:
      if let record = try existing(PlanWeekRecord.self, #Predicate<PlanWeekRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .assessment:
      if let record = try existing(AssessmentRecord.self, #Predicate<AssessmentRecord> { $0.id == id }, in: context) { context.delete(record) }
    case .theme:
      if let record = try existing(ThemeRecord.self, #Predicate<ThemeRecord> { $0.id == id }, in: context) { context.delete(record) }
    }
  }

  // MARK: - Hilfen

  private static func existing<T: PersistentModel>(
    _ type: T.Type, _ predicate: Predicate<T>, in context: ModelContext
  ) throws -> T? {
    var descriptor = FetchDescriptor<T>(predicate: predicate)
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
  }

  /// Fügt ein neues Objekt mit der vorgegebenen Kennung ein; die Kennung wird nie neu erzeugt.
  private static func insert<T: PersistentModel & HasRecordID>(
    _ record: T, id: UUID, in context: ModelContext
  ) -> T {
    record.id = id
    context.insert(record)
    return record
  }

  private static func timetable(_ id: UUID?, in context: ModelContext) throws -> TimetableRecord? {
    guard let id else { return nil }
    guard let parent = try existing(TimetableRecord.self, #Predicate<TimetableRecord> { $0.id == id }, in: context)
    else { throw RecordCodecError.missingParent(id) }
    return parent
  }

  private static func materialLink(_ id: UUID?, in context: ModelContext) throws -> MaterialLinkRecord? {
    guard let id else { return nil }
    guard let parent = try existing(MaterialLinkRecord.self, #Predicate<MaterialLinkRecord> { $0.id == id }, in: context)
    else { throw RecordCodecError.missingParent(id) }
    return parent
  }

  private static func coursePlan(_ id: UUID?, in context: ModelContext) throws -> CoursePlanRecord? {
    guard let id else { return nil }
    guard let parent = try existing(CoursePlanRecord.self, #Predicate<CoursePlanRecord> { $0.id == id }, in: context)
    else { throw RecordCodecError.missingParent(id) }
    return parent
  }

  private static func bytes(of ref: AttachmentRef?, field: String, in files: [String: Data]) throws -> Data? {
    guard ref != nil else { return nil }
    guard let data = files[field] else { throw RecordCodecError.attachmentMissing(field) }
    return data
  }
}

/// Gemeinsamer Zugriff auf die Kennung der dreizehn Datensatz-Klassen (für `insert`).
/// Swift-Hinweis: Ein Protokoll mit `var id` ist nötig, weil `@Model`-Klassen sonst keinen
/// gemeinsamen Typ für die schreibbare Eigenschaft haben.
private protocol HasRecordID: AnyObject {
  var id: UUID { get set }
}

extension TimetableRecord: HasRecordID {}
extension TimetableEntryRecord: HasRecordID {}
extension NonTeachingPeriodRecord: HasRecordID {}
extension ScheduleChangeRecord: HasRecordID {}
extension MaterialLinkRecord: HasRecordID {}
extension PenNoteRecord: HasRecordID {}
extension LessonInfoRecord: HasRecordID {}
extension BoardPageRecord: HasRecordID {}
extension SchoolYearRecord: HasRecordID {}
extension CoursePlanRecord: HasRecordID {}
extension PlanWeekRecord: HasRecordID {}
extension AssessmentRecord: HasRecordID {}
extension ThemeRecord: HasRecordID {}

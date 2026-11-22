import Foundation
import FrontstageCore

/// Wertabbild einer Zuordnung (`MaterialLinkRecord`) für die Oberfläche: Die View-Modelle halten
/// Werte statt SwiftData-Objekten und bleiben so ohne SwiftData-Import testbar.
struct MaterialLinkItem: Identifiable, Hashable, Sendable {
  let id: UUID
  /// `nil` bei Material, dessen Schlüssel sich nicht lesen lässt.
  var lessonKey: LessonKey?
  var position: Int
  var reference: MaterialReference
  /// Lösung neben dem Blatt (FR-6.3); `nil` = keine.
  var solution: MaterialReference? = nil
}

/// Schmale Sicht auf die Daten für Tagesansicht, Vorbereiten und Einrichten.
///
/// Swift-Hinweis: Hat `DataStore` eine Methode schon mit gleichem Namen und gleicher Signatur,
/// erfüllt sie die Protokollanforderung ohne weiteren Code (Standardargumente und
/// `@discardableResult` gehören nicht zur Signatur). Nur die Wert-Methoden unten sind neu und
/// bilden `MaterialLinkRecord` auf `MaterialLinkItem` ab.
@MainActor protocol PreparationStore: AnyObject {
  var revision: Int { get }

  // Stundenplan, Zeiträume, Abweichungen
  func timetable() throws -> Timetable?
  func lessons(on day: CalendarDay) throws -> [Lesson]
  func nextLesson(after key: LessonKey) throws -> LessonKey?
  func manuallyEditedEntries() throws -> Set<TimetableEntry>
  func addEntry(_ entry: TimetableEntry, origin: Origin) throws
  func replaceEntry(_ old: TimetableEntry, with new: TimetableEntry) throws
  func removeEntry(_ entry: TimetableEntry) throws
  func setWeekVariants(count: Int, referenceWeekA: CalendarDay) throws
  func setBellSchedule(_ schedule: BellSchedule) throws
  func nonTeachingPeriods() throws -> [NonTeachingPeriod]
  func addNonTeachingPeriod(_ period: NonTeachingPeriod) throws
  func removeNonTeachingPeriod(_ period: NonTeachingPeriod) throws
  func scheduleChanges() throws -> [ScheduleChange]
  func markCancelled(_ key: LessonKey) throws
  func removeCancellation(_ key: LessonKey) throws -> Bool
  func addSubstituteLesson(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject)
    throws -> LessonKey?
  func removeSubstituteLesson(date: CalendarDay, period: Int, schoolClass: SchoolClass, subject: Subject)
    throws -> Bool

  // Übernehmen und Stundenangaben
  func candidateLessons(for schoolClass: SchoolClass, from day: CalendarDay, maxDays: Int) throws -> [Lesson]
  func selectableClasses(excluding: SchoolClass) throws -> [SchoolClass]
  func copyMaterialLinks(from source: LessonKey, to target: LessonKey) throws -> Int
  func moveLinks(in key: LessonKey, fromOffsets: IndexSet, toOffset: Int) throws
  func moveAllLinksToNextLesson(from key: LessonKey) throws -> LessonKey?
  func folderGrantNames() throws -> Set<String>
  func lessonInfo(for key: LessonKey) throws -> LessonInfo
  func setLessonInfo(_ info: LessonInfo, for key: LessonKey) throws

  // Jahresplan (FR-15.5, FR-15.6); `DataStore` erfüllt beide über `DataStore+CoursePlans`.
  func lessonPlanHint(for lesson: Lesson) throws -> LessonPlanHint?
  func plannedAssessments(inWeekOf monday: CalendarDay) throws -> [PlannedAssessment]

  // Zuordnungen als Werte und über ihre id
  func materialLinkItems(for key: LessonKey) throws -> [MaterialLinkItem]
  func materialLinkItems(from: CalendarDay, through: CalendarDay) throws -> [MaterialLinkItem]
  func orphanedLinkItems(on day: CalendarDay) throws -> [MaterialLinkItem]
  func materialLinkItem(id: UUID) throws -> MaterialLinkItem?
  func assignItem(_ reference: MaterialReference, to key: LessonKey, at index: Int?) throws -> MaterialLinkItem
  func moveLinkToNextLesson(id: UUID) throws -> LessonKey?
  func moveLink(id: UUID, to key: LessonKey) throws
  func removeLink(id: UUID) throws
  /// Lösung setzen oder entfernen (FR-6.3); unbekannte id → nichts geändert.
  func setSolution(_ reference: MaterialReference?, forLinkID id: UUID) throws
}

/// Vorgaben für Test-Attrappen ohne Jahresplan: kein Hinweis, keine Leistungsnachweise.
///
/// Swift-Hinweis: Diese Vorgaben greifen auch über `any PreparationStore` nur, weil beide Methoden als
/// **Anforderung** im Protokoll stehen. `DataStore` liefert eigene Methoden gleicher Signatur und gewinnt.
extension PreparationStore {
  func lessonPlanHint(for lesson: Lesson) throws -> LessonPlanHint? { nil }
  func plannedAssessments(inWeekOf monday: CalendarDay) throws -> [PlannedAssessment] { [] }
}

extension MaterialLinkItem {
  init(_ record: MaterialLinkRecord) {
    self.init(
      id: record.id, lessonKey: record.lessonKey, position: record.position, reference: record.reference,
      solution: record.solution)
  }
}

extension DataStore: PreparationStore {
  func materialLinkItems(for key: LessonKey) throws -> [MaterialLinkItem] {
    try links(for: key).map { MaterialLinkItem($0) }
  }

  func materialLinkItems(from: CalendarDay, through: CalendarDay) throws -> [MaterialLinkItem] {
    try links(from: from, through: through).map { MaterialLinkItem($0) }
  }

  func orphanedLinkItems(on day: CalendarDay) throws -> [MaterialLinkItem] {
    try orphanedLinks(on: day).map { MaterialLinkItem($0) }
  }

  /// Unbekannte id → `nil`.
  func materialLinkItem(id: UUID) throws -> MaterialLinkItem? {
    try link(id: id).map { MaterialLinkItem($0) }
  }

  func assignItem(_ reference: MaterialReference, to key: LessonKey, at index: Int?) throws -> MaterialLinkItem {
    MaterialLinkItem(try assign(reference, to: key, at: index))
  }

  /// Unbekannte id → `nil`, nichts geändert.
  func moveLinkToNextLesson(id: UUID) throws -> LessonKey? {
    guard let record = try link(id: id) else { return nil }
    return try moveLinkToNextLesson(record)
  }

  /// Unbekannte id → nichts geändert.
  func moveLink(id: UUID, to key: LessonKey) throws {
    guard let record = try link(id: id) else { return }
    try moveLink(record, to: key)
  }

  /// Unbekannte id → nichts geändert.
  func removeLink(id: UUID) throws {
    guard let record = try link(id: id) else { return }
    try removeLink(record)
  }
}

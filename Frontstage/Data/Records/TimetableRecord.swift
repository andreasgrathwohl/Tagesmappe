import Foundation
import SwiftData

/// Gespeicherter Stundenplan (Glossar „Stundenplan“). Der Kern-Typ `Timetable` wird daraus berechnet.
/// iCloud-Spiegelung (ADR-0010, vormals ADR-0002): alle Eigenschaften mit Vorgabe oder optional, Beziehungen optional.
@Model
final class TimetableRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  var name: String = ""
  var validFromText: String?
  var validToText: String?
  /// `TimetableSourceKind.rawValue` (Teilplan 05): `manual` oder `schulmanager`.
  var sourceKindRaw: String = "manual"
  /// Glossar „Stand“: Zeitpunkt des letzten Abrufs der Quelle, gespiegelt.
  var sourceFetchedAt: Date?
  var weekVariantCount: Int = 1
  var referenceWeekAText: String?
  /// JSON von `BellSchedule`.
  var bellScheduleData: Data?
  var isActive: Bool = false
  @Relationship(deleteRule: .cascade, inverse: \TimetableEntryRecord.timetable)
  var entries: [TimetableEntryRecord]? = []

  init(
    name: String = "", sourceKindRaw: String = "manual", weekVariantCount: Int = 1,
    referenceWeekAText: String? = nil, isActive: Bool = false
  ) {
    self.name = name
    self.sourceKindRaw = sourceKindRaw
    self.weekVariantCount = weekVariantCount
    self.referenceWeekAText = referenceWeekAText
    self.isActive = isActive
  }
}

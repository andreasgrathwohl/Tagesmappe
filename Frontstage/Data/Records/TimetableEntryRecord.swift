import Foundation
import SwiftData

/// Eine feste Stunde im gespeicherten Stundenplan.
@Model
final class TimetableEntryRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  /// `WeekVariant.rawValue` (`a`/`b`); `nil` = gilt in jeder Woche.
  var weekVariantRaw: String?
  /// `Weekday.rawValue` (Montag = 1).
  var weekdayRaw: Int = 1
  var period: Int = 1
  var schoolClassText: String = ""
  var subjectText: String = ""
  /// `Origin.rawValue`: `manual` oder `source`.
  var originRaw: String = "manual"
  /// Ein Quell-Eintrag, der von Hand geändert wurde.
  var isManuallyEdited: Bool = false
  /// Gegenseite von `TimetableRecord.entries` (dort steht das `@Relationship`-Makro).
  var timetable: TimetableRecord?

  init(
    weekVariantRaw: String? = nil, weekdayRaw: Int = 1, period: Int = 1, schoolClassText: String = "",
    subjectText: String = "", originRaw: String = "manual", isManuallyEdited: Bool = false,
    timetable: TimetableRecord? = nil
  ) {
    self.weekVariantRaw = weekVariantRaw
    self.weekdayRaw = weekdayRaw
    self.period = period
    self.schoolClassText = schoolClassText
    self.subjectText = subjectText
    self.originRaw = originRaw
    self.isManuallyEdited = isManuallyEdited
    self.timetable = timetable
  }
}

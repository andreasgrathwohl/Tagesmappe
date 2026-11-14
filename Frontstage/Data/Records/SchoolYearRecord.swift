import Foundation
import SwiftData

/// Ein Schuljahr (Glossar): erster Tag, Beginn des zweiten Halbjahrs, letzter Tag.
@Model
final class SchoolYearRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  /// Tage als `yyyy-MM-dd`; ein nicht lesbarer Text macht das Schuljahr unlesbar (siehe `makeSchoolYear()`).
  var firstDayText: String = ""
  var secondTermStartText: String = ""
  var lastDayText: String = ""
  /// JSON `[String: Int]`: Jahrgang von Hand je normalisierter Klasse.
  var gradeOverridesData: Data?

  init() {}
}

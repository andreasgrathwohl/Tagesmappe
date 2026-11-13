import Foundation
import SwiftData

/// Abweichung vom Stundenplan: Ausfall oder Vertretungsstunde.
@Model
final class ScheduleChangeRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  /// `cancellation` oder `substituteLesson`.
  var kindRaw: String = "cancellation"
  var originRaw: String = "manual"
  var dayText: String = ""
  /// Bei einem Ausfall: `LessonKey.storageText` der ausgefallenen Stunde.
  var lessonKeyText: String?
  /// Bei einer Vertretungsstunde: Stundennummer, Klasse und Fach.
  var period: Int?
  var schoolClassText: String?
  var subjectText: String?

  init(
    kindRaw: String = "cancellation", originRaw: String = "manual", dayText: String = "",
    lessonKeyText: String? = nil, period: Int? = nil, schoolClassText: String? = nil,
    subjectText: String? = nil
  ) {
    self.kindRaw = kindRaw
    self.originRaw = originRaw
    self.dayText = dayText
    self.lessonKeyText = lessonKeyText
    self.period = period
    self.schoolClassText = schoolClassText
    self.subjectText = subjectText
  }
}

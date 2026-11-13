import Foundation
import SwiftData

/// Stundenangaben (Thema, Vorzubereiten, Hausaufgabe) zu einer Unterrichtsstunde.
@Model
final class LessonInfoRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  var lessonKeyText: String = ""
  var topic: String?
  var toPrepare: String?
  var homework: String?
  var updatedAt: Date = Date.now
  /// Änderungszeit je Feld, damit das Zusammenführen nach dem Abgleich feldweise entscheiden kann.
  var topicUpdatedAt: Date?
  var toPrepareUpdatedAt: Date?
  var homeworkUpdatedAt: Date?

  init(lessonKeyText: String = "") {
    self.lessonKeyText = lessonKeyText
  }
}

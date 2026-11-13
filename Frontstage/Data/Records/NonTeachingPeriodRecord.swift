import Foundation
import SwiftData

/// Unterrichtsfreier Zeitraum (Ferien, Studientage). `fromText`/`toText` im Format `yyyy-MM-dd`.
@Model
final class NonTeachingPeriodRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  var fromText: String = ""
  var toText: String = ""
  var title: String = ""

  init(fromText: String = "", toText: String = "", title: String = "") {
    self.fromText = fromText
    self.toText = toText
    self.title = title
  }
}

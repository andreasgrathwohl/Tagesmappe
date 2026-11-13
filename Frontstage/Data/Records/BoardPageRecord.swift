import Foundation
import SwiftData

/// Eine Tafelseite einer Unterrichtsstunde.
@Model
final class BoardPageRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  var lessonKeyText: String = ""
  var position: Int = 0
  /// `BoardBackground.rawValue`.
  var backgroundRaw: String = "blank"
  @Attribute(.externalStorage) var backgroundImageData: Data?
  @Attribute(.externalStorage) var drawingData: Data?
  var updatedAt: Date = Date.now

  init(lessonKeyText: String = "", position: Int = 0, backgroundRaw: String = "blank") {
    self.lessonKeyText = lessonKeyText
    self.position = position
    self.backgroundRaw = backgroundRaw
  }
}

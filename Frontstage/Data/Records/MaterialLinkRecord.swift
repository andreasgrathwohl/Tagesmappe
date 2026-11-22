import Foundation
import SwiftData

/// Zuordnung einer Materialdatei zu einer Unterrichtsstunde (oder zu einem Tag ohne Stunde).
/// Ein Verweis, keine Dateikopie (FR-3.4): die Felder von `MaterialReference` stehen direkt hier.
@Model
final class MaterialLinkRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  /// `LessonKey.storageText`; leer bei „Material ohne Stunde“.
  var lessonKeyText: String = ""
  /// Tag als Text (`yyyy-MM-dd`): „Material ohne Stunde“ wird je Tag abgefragt, ohne das Format
  /// von `LessonKey.storageText` in einem `#Predicate` zu zerlegen.
  var dayText: String = ""
  var position: Int = 0
  var folderGrantName: String = ""
  var relativePath: String = ""
  var displayName: String = ""
  /// `MaterialFileKind.rawValue`.
  var fileKindRaw: String = "other"
  var oneDriveItemID: String?
  var oneDriveDriveID: String?
  /// Lösung neben dem Blatt (FR-6.3): ein zweiter Verweis in denselben Feldern wie oben, alle `nil` = keine Lösung.
  /// Optional ohne Vorgabe gemäß ADR-0002; lesen und setzen über `solution`/`setSolution(_:)`.
  var solutionFolderGrantName: String?
  var solutionRelativePath: String?
  var solutionDisplayName: String?
  var solutionFileKindRaw: String?
  var solutionOneDriveItemID: String?
  var solutionOneDriveDriveID: String?
  @Relationship(deleteRule: .cascade, inverse: \PenNoteRecord.materialLink)
  var penNotes: [PenNoteRecord]? = []

  init(
    lessonKeyText: String = "", dayText: String = "", position: Int = 0, folderGrantName: String = "",
    relativePath: String = "", displayName: String = "", fileKindRaw: String = "other",
    oneDriveItemID: String? = nil, oneDriveDriveID: String? = nil
  ) {
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

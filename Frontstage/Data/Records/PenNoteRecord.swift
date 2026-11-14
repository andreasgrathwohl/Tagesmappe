import Foundation
import SwiftData

/// Stiftnotiz zu einer Seite einer zugeordneten Datei. Wird mit ihrer Zuordnung gelöscht.
@Model
final class PenNoteRecord {
  var id: UUID = UUID()
  var createdAt: Date = Date.now
  /// Gegenseite von `MaterialLinkRecord.penNotes` (dort steht das `@Relationship`-Makro).
  var materialLink: MaterialLinkRecord?
  /// 0-basiert; ein Bild ist Seite 0.
  var pageIndex: Int = 0
  /// Serialisierte Zeichnung; große Werte legt SwiftData außerhalb der Datenbank ab.
  @Attribute(.externalStorage) var drawingData: Data?
  /// Seitengröße in PDF-Punkten; 0 = unbekannt.
  var pageWidth: Double = 0
  var pageHeight: Double = 0
  var updatedAt: Date = Date.now

  init(materialLink: MaterialLinkRecord?, pageIndex: Int) {
    self.materialLink = materialLink
    self.pageIndex = pageIndex
  }
}

import Foundation
import PDFKit

/// Notiz-PDF: die Seiten des Dokuments plus je Strich eine Ink-Anmerkung.
///
/// Vorläufer: Teilplan 06 Task 8 ersetzt diesen Rumpf durch die Umsetzung. Bis dahin liefert er `nil`
/// („keine Striche“), damit `ViewerModel.close()` übersetzbar ist.
enum PenNotePDFWriter {
  static func makePDF(document: PDFDocument, notes: [Int: StoredPenNote]) -> Data? {
    nil
  }
}

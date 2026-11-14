import Foundation
import PDFKit
import PencilKit

#if os(iOS)
  import UIKit
  private typealias StrokePath = UIBezierPath
#else
  import AppKit
  private typealias StrokePath = NSBezierPath
#endif

/// Notiz-PDF: die Seiten des Dokuments plus je Strich eine Ink-Anmerkung (ADR-0011, Entscheidung 5).
///
/// Das Ergebnis ist in jedem PDF-Leser les- und druckbar. Maßgeblich bleibt die Notiz-Datei; das PDF wird
/// bei Bedarf neu erzeugt (auch am Mac nach dem Zusammenführen). Kein Zugriff auf UIKit-Ansichten.
///
/// Swift-/PDFKit-Hinweis: `PDFAnnotation.add(_:)` erwartet Pfade in **Anmerkungskoordinaten**, also relativ
/// zur linken unteren Ecke von `bounds`. Weil die Anmerkung die ganze `mediaBox` abdeckt, ist das
/// „Seitenkoordinate minus `bounds.origin`“.
enum PenNotePDFWriter {
  /// - Returns: PDF-Daten, oder `nil`, wenn keine Striche vorhanden sind (dann gibt es kein Notiz-PDF).
  ///   Seiten der Notizen, die im Dokument nicht (mehr) existieren, werden nicht geschrieben; sie bleiben
  ///   in der Notiz-Datei. Das übergebene Dokument wird nie verändert (Arbeit an einer Kopie).
  static func makePDF(document: PDFDocument, notes: [Int: StoredPenNote]) -> Data? {
    let pagesWithStrokes = notes.filter { !$0.value.drawing.strokes.isEmpty }
    guard !pagesWithStrokes.isEmpty,
      let original = document.dataRepresentation(),
      let copy = PDFDocument(data: original)
    else { return nil }

    var wroteAny = false
    for (index, note) in pagesWithStrokes.sorted(by: { $0.key < $1.key }) {
      guard index >= 0, index < copy.pageCount, let page = copy.page(at: index) else { continue }
      let transform = DrawingGeometry.pdfTransform(for: page)
      let bounds = page.bounds(for: .mediaBox)
      for stroke in note.drawing.strokes {
        page.addAnnotation(annotation(for: stroke, pdfTransform: transform, pageBounds: bounds))
        wroteAny = true
      }
    }
    guard wroteAny else { return nil }
    return copy.dataRepresentation()
  }

  /// Ein Strich als Ink-Anmerkung: Linienzug durch die (dichter gesetzten) Punkte, Farbe und mittlere Breite
  /// des Stifts.
  private static func annotation(
    for stroke: PKStroke, pdfTransform: CGAffineTransform, pageBounds: CGRect
  ) -> PDFAnnotation {
    let path = StrokePath()
    var widthSum: CGFloat = 0
    var count = 0
    var last = CGPoint.zero
    for point in stroke.path.interpolatedPoints(by: .distance(2)) {
      // Strichpunkt → Seitenkoordinaten (Strich-Transformation) → PDF-Koordinaten → Anmerkungskoordinaten.
      let pagePoint = point.location.applying(stroke.transform)
      let pdfPoint = pagePoint.applying(pdfTransform)
      let local = CGPoint(x: pdfPoint.x - pageBounds.origin.x, y: pdfPoint.y - pageBounds.origin.y)
      if count == 0 {
        path.move(to: local)
      } else {
        addLine(to: local, in: path)
      }
      last = local
      widthSum += point.size.width
      count += 1
    }
    // Ein einzelner Punkt: als Punkt zeichnen statt als leeren Pfad.
    if count == 1 { addLine(to: last, in: path) }

    let annotation = PDFAnnotation(bounds: pageBounds, forType: .ink, withProperties: nil)
    annotation.add(path)
    annotation.color = stroke.ink.color
    let border = PDFBorder()
    border.lineWidth = max(count > 0 ? widthSum / CGFloat(count) : 1, 1)
    annotation.border = border
    return annotation
  }

  /// Plattformweiche: `UIBezierPath.addLine(to:)` heißt am Mac `NSBezierPath.line(to:)`.
  private static func addLine(to point: CGPoint, in path: StrokePath) {
    #if os(iOS)
      path.addLine(to: point)
    #else
      path.line(to: point)
    #endif
  }
}

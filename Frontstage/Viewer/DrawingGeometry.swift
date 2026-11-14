import CoreGraphics
import FrontstageCore
import PDFKit
import PencilKit

/// Umrechnung zwischen Darstellung (Ansicht), Seitenkoordinaten und PDF-Koordinaten (ADR-0011).
///
/// Gespeichert wird eine Zeichnung immer in **Seitenkoordinaten**: Ursprung oben links, Einheit PDF-Punkt,
/// bezogen auf die Seite so, wie sie angezeigt wird (also nach Drehung). Damit ist die Notiz unabhängig davon,
/// wie groß die Ansicht gerade ist. Die Ansicht rechnet beim Laden und Speichern um.
enum DrawingGeometry {
  /// Größe der angezeigten Seite in PDF-Punkten; bei 90°/270° Drehung sind Breite und Höhe vertauscht.
  static func pageSize(of page: PDFPage) -> PageSize {
    let box = page.bounds(for: .mediaBox)
    let swapped = normalizedRotation(of: page) % 180 != 0
    return PageSize(
      width: Double(swapped ? box.height : box.width), height: Double(swapped ? box.width : box.height))
  }

  /// Ansicht → Seite. Je Achse getrennt skaliert (Seitenverhältnis der Ansicht kann leicht abweichen).
  static func toPageSpace(_ drawing: PKDrawing, viewSize: CGSize, pageSize: PageSize) -> PKDrawing {
    guard let scale = scale(viewSize: viewSize, pageSize: pageSize) else { return drawing }
    return drawing.transformed(using: CGAffineTransform(scaleX: scale.x, y: scale.y))
  }

  /// Seite → Ansicht (Umkehrung von `toPageSpace`).
  static func toViewSpace(_ drawing: PKDrawing, viewSize: CGSize, pageSize: PageSize) -> PKDrawing {
    guard let scale = scale(viewSize: viewSize, pageSize: pageSize) else { return drawing }
    return drawing.transformed(using: CGAffineTransform(scaleX: 1 / scale.x, y: 1 / scale.y))
  }

  /// Seitenkoordinaten (oben links, gedrehte Seite) → PDF-Koordinaten der ungedrehten `mediaBox`
  /// (Ursprung unten links, y nach oben). Je Drehung eine feste Matrix.
  ///
  /// Herleitung für 90° (im Uhrzeigersinn angezeigt): Der Punkt unten links der mediaBox liegt in der
  /// Anzeige oben links; aus Anzeige-`x` wird PDF-`v`, aus Anzeige-`y` wird PDF-`u`.
  static func pdfTransform(for page: PDFPage) -> CGAffineTransform {
    let box = page.bounds(for: .mediaBox)
    let w = box.width
    let h = box.height
    let base: CGAffineTransform
    switch normalizedRotation(of: page) {
    case 90:
      base = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
    case 180:
      base = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: w, ty: 0)
    case 270:
      base = CGAffineTransform(a: 0, b: -1, c: -1, d: 0, tx: w, ty: h)
    default:
      base = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: h)
    }
    return base.concatenating(CGAffineTransform(translationX: box.origin.x, y: box.origin.y))
  }

  private static func normalizedRotation(of page: PDFPage) -> Int {
    ((page.rotation % 360) + 360) % 360
  }

  /// Faktor Seite ÷ Ansicht je Achse; `nil` bei leerer Größe (nichts umzurechnen).
  private static func scale(viewSize: CGSize, pageSize: PageSize) -> (x: CGFloat, y: CGFloat)? {
    guard viewSize.width > 0, viewSize.height > 0, pageSize.width > 0, pageSize.height > 0 else { return nil }
    return (CGFloat(pageSize.width) / viewSize.width, CGFloat(pageSize.height) / viewSize.height)
  }
}

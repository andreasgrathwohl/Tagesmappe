import CoreGraphics
import Foundation

/// Fehler beim Erzeugen des Tafelbild-PDFs.
enum BoardPDFError: Error, Equatable {
  case contextUnavailable
}

/// Macht aus Tafelseiten ein PDF (FR-12.4): eine PDF-Seite je Tafelseite, mit Hintergrund und Zeichnung.
///
/// Die Funktion liest nur Werte (`BoardPageSnapshot`) und schreibt nichts in den Speicher der Tafel.
enum BoardPDFExporter {
  /// Seitengröße in PDF-Punkten, im Seitenverhältnis der Tafel (16:9).
  static let pageSize = CGSize(width: 960, height: 540)

  /// Alle Seiten als PDF-Daten.
  static func makePDF(pages: [BoardPageSnapshot]) throws -> Data {
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
      throw BoardPDFError.contextUnavailable
    }
    // Swift-Hinweis: Der Kontext erwartet einen Zeiger auf das Seitenrechteck; `withUnsafePointer` gibt ihn nur für
    // die Dauer des Aufrufs her.
    var mediaBox = CGRect(origin: .zero, size: pageSize)
    guard let context = withUnsafePointer(to: &mediaBox, { CGContext(consumer: consumer, mediaBox: $0, nil) })
    else { throw BoardPDFError.contextUnavailable }

    for page in pages {
      context.beginPDFPage(nil)
      // PDF-Kontexte haben den Ursprung unten links; `BoardPageRenderer` erwartet oben links.
      context.saveGState()
      context.translateBy(x: 0, y: pageSize.height)
      context.scaleBy(x: 1, y: -1)
      BoardPageRenderer.draw(page, in: context, size: pageSize)
      context.restoreGState()
      context.endPDFPage()
    }
    context.closePDF()
    return data as Data
  }
}

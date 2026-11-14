import Foundation
import FrontstageCore
import PDFKit

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Macht aus den Bytes eines Materials ein `PDFDocument`: PDFs direkt, Bilder als Dokument mit einer Seite.
/// Dadurch zeigt und beschreibt die Anzeige beide Arten gleich (FR-6).
///
/// Bewusst nicht an den Hauptakteur gebunden: Das Notiz-PDF wird auch außerhalb des Hauptthreads gebaut.
enum MaterialDocumentLoader {
  enum LoadError: Error, Equatable {
    /// Daten sind kein lesbares PDF bzw. Bild (oder das PDF hat keine Seite).
    case unreadable
    /// Diese Dateiart wird nicht in der Anzeige geöffnet (Präsentation, Dokument, …).
    case unsupportedKind
  }

  static func makeDocument(from data: Data, kind: MaterialFileKind) throws(LoadError) -> PDFDocument {
    switch kind {
    case .pdf:
      guard let document = PDFDocument(data: data), document.pageCount > 0 else { throw .unreadable }
      return document
    case .image:
      guard let page = imagePage(from: data) else { throw .unreadable }
      let document = PDFDocument()
      document.insert(page, at: 0)
      return document
    default:
      throw .unsupportedKind
    }
  }

  /// Eine PDF-Seite aus dem Bild; `nil`, wenn die Daten kein Bild sind.
  private static func imagePage(from data: Data) -> PDFPage? {
    #if os(iOS)
      guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
      // Swift-/UIKit-Hinweis: `UIImage` trägt die Kameradrehung (EXIF) nur als Flagge. `PDFPage(image:)` wertet sie
      // nicht sicher aus; einmal aufrecht in ein neues Bild zeichnen macht die Drehung zu echten Pixeln.
      let format = UIGraphicsImageRendererFormat.default()
      format.scale = image.scale
      let upright = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
        image.draw(at: .zero)
      }
      return PDFPage(image: upright)
    #else
      guard let image = NSImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
      return PDFPage(image: image)
    #endif
  }
}

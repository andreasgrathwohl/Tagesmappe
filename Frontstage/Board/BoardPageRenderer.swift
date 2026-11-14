import CoreGraphics
import Foundation
import FrontstageCore
import ImageIO
import PencilKit

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Eine Tafelseite als Wert, unabhängig von SwiftData (Anzeige, PDF, Tests).
struct BoardPageSnapshot: Equatable, Sendable {
  var background: BoardBackground
  var backgroundImageData: Data?
  var drawingData: Data?
}

/// Zeichnet eine Tafelseite in einen `CGContext`.
///
/// Swift-Hinweis: Ein `CGContext` hat standardmäßig den Ursprung **unten links**. Diese Funktion erwartet
/// einen Kontext mit Ursprung **oben links** (wie `UIGraphicsPDFRenderer`); wer einen Kontext mit
/// Ursprung unten links hat, spiegelt ihn vorher (`translateBy(x: 0, y: h)`, `scaleBy(x: 1, y: -1)`).
enum BoardPageRenderer {
  /// Weiß füllen, Linien, ggf. Hintergrundbild (einpassend), dann die Zeichnung. Unlesbare Zeichnungsdaten
  /// ergeben eine Seite ohne Zeichnung, nie einen Absturz.
  static func draw(_ page: BoardPageSnapshot, in context: CGContext, size: CGSize) {
    context.saveGState()
    defer { context.restoreGState() }
    let bounds = CGRect(origin: .zero, size: size)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(bounds)

    let scale = size.width / BoardGeometry.canvasSize.width
    context.setStrokeColor(CGColor(gray: BoardGeometry.lineGray, alpha: 1))
    context.setLineWidth(BoardGeometry.lineWidth * scale)
    for (start, end) in BoardGeometry.lines(for: page.background, in: size) {
      context.move(to: start)
      context.addLine(to: end)
      context.strokePath()
    }

    if page.background == .image, let data = page.backgroundImageData, let image = decodeImage(data) {
      let rect = BoardGeometry.fittedRect(
        contentSize: CGSize(width: image.width, height: image.height), in: size)
      drawFlipped(image, in: rect, context: context)
    }

    if let data = page.drawingData, let drawing = try? PKDrawing(data: data),
      let image = drawingImage(drawing, scale: min(max(scale, 1), 3))
    {
      drawFlipped(image, in: bounds, context: context)
    }
  }

  /// Bild aus Dateidaten (JPEG, PNG, HEIC …) mit angewandter Ausrichtung (EXIF), höchstens 3200 Pixel Kantenlänge.
  static func decodeImage(_ data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 3200,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }

  /// Die Zeichnung als Bild der logischen Seitengröße mal `scale` Pixel; immer mit hellem Erscheinungsbild,
  /// damit schwarze Tinte im Dunkelmodus nicht zu weiß wird (die Seite ist weiß). `nil` ohne Striche.
  static func drawingImage(_ drawing: PKDrawing, scale: CGFloat) -> CGImage? {
    guard !drawing.strokes.isEmpty else { return nil }
    let rect = CGRect(origin: .zero, size: BoardGeometry.canvasSize)
    #if os(iOS)
      var result: UIImage?
      UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
        result = drawing.image(from: rect, scale: scale)
      }
      return result?.cgImage
    #else
      var result: NSImage?
      NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
        result = drawing.image(from: rect, scale: scale)
      }
      return result?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    #endif
  }

  /// Zeichnet ein Bild in einen Kontext mit Ursprung oben links, ohne es auf den Kopf zu stellen
  /// (`CGContext.draw` zeichnet für Ursprung unten links).
  private static func drawFlipped(_ image: CGImage, in rect: CGRect, context: CGContext) {
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.maxY)
    context.scaleBy(x: 1, y: -1)
    context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
    context.restoreGState()
  }
}

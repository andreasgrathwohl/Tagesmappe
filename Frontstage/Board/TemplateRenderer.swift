import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

enum TemplateRendererError: Error, Equatable {
  /// Die Datei lässt sich nicht als PDF oder Bild lesen.
  case unreadable
  /// Die Seitenzahl liegt außerhalb des Dokuments.
  case pageOutOfRange
}

/// Rendert eine PDF-Seite oder ein Bild (ganz oder als Ausschnitt) als Tafelhintergrund (FR-12.6).
///
/// Das Ergebnis ist immer ein JPEG mit `2400 × 1350` Pixeln, der Fläche der Tafel (`BoardGeometry`): der Inhalt
/// wird einpassend skaliert, mittig gesetzt, der Rest bleibt weiß. `crop` ist normiert (0…1, Ursprung oben links,
/// bezogen auf die angezeigte Seite bzw. das Bild); `nil` heißt ganze Seite. Die Quelldatei wird nur gelesen.
///
/// Swift-Hinweis: Alle Funktionen sind synchron und ohne Akteur-Bindung; die Aufrufer rufen sie in
/// `Task.detached` auf, damit das Rendern den Hauptthread nicht blockiert. `Data` und `URL` sind `Sendable`.
enum TemplateRenderer {
  static let outputWidth = 2400
  static let outputHeight = 1350

  // MARK: Tafelhintergrund

  static func renderPDFPage(at url: URL, pageIndex: Int, crop: CGRect?) throws -> Data {
    let (page, displaySize) = try pdfPage(at: url, pageIndex: pageIndex)
    guard let pageRef = page.pageRef else { throw TemplateRendererError.unreadable }
    let area = cropArea(crop, in: displaySize)
    let context = try makeContext(width: outputWidth, height: outputHeight)
    fillWhite(context, width: outputWidth, height: outputHeight)

    // Ausschnitt (Seitenpunkte, Ursprung unten links) einpassend auf die Fläche legen.
    let scale = min(CGFloat(outputWidth) / area.width, CGFloat(outputHeight) / area.height)
    context.saveGState()
    context.translateBy(x: CGFloat(outputWidth) / 2, y: CGFloat(outputHeight) / 2)
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: -area.midX, y: -area.midY)
    // Außerhalb des Ausschnitts bleibt der Rand weiß.
    context.clip(to: area)
    // `getDrawingTransform` bildet die Beschnittbox (samt Seitendrehung) auf das Rechteck der Seite ab.
    let pageRect = CGRect(origin: .zero, size: displaySize)
    context.concatenate(pageRef.getDrawingTransform(.cropBox, rect: pageRect, rotate: 0, preserveAspectRatio: true))
    context.drawPDFPage(pageRef)
    context.restoreGState()
    return try jpeg(from: context)
  }

  static func renderImage(at url: URL, crop: CGRect?) throws -> Data {
    guard let source = try loadImage(at: url, maxPixel: 8000) else { throw TemplateRendererError.unreadable }
    let width = CGFloat(source.width)
    let height = CGFloat(source.height)
    // `CGImage.cropping(to:)` rechnet ab oben links in Pixeln, wie `crop` normiert ist.
    var image = source
    if let crop {
      let pixels = clamped(crop)
        .applying(CGAffineTransform(scaleX: width, y: height)).integral
        .intersection(CGRect(x: 0, y: 0, width: width, height: height))
      if pixels.width >= 1, pixels.height >= 1, let cropped = source.cropping(to: pixels) { image = cropped }
    }
    return try renderImage(image)
  }

  /// Ein fertig dekodiertes Bild einpassend auf die Fläche der Tafel (2400 × 1350, Rand weiß) als JPEG; auch für
  /// ein Standbild der Kamera (FR-12.5).
  static func renderImage(_ image: CGImage) throws -> Data {
    let context = try makeContext(width: outputWidth, height: outputHeight)
    fillWhite(context, width: outputWidth, height: outputHeight)
    let scale = min(CGFloat(outputWidth) / CGFloat(image.width), CGFloat(outputHeight) / CGFloat(image.height))
    let drawWidth = CGFloat(image.width) * scale
    let drawHeight = CGFloat(image.height) * scale
    context.interpolationQuality = .high
    context.draw(
      image,
      in: CGRect(
        x: (CGFloat(outputWidth) - drawWidth) / 2, y: (CGFloat(outputHeight) - drawHeight) / 2,
        width: drawWidth, height: drawHeight))
    return try jpeg(from: context)
  }

  // MARK: Vorschau und Seitenzahl

  /// Anzahl der Seiten; `nil`, wenn die Datei kein lesbares PDF ist.
  static func pageCount(ofPDFAt url: URL) -> Int? {
    PDFDocument(url: url)?.pageCount
  }

  /// Ganze Seite, längste Seite `maxSide` Pixel, als JPEG (für Seitenauswahl und Ausschnitt-Ziehen).
  static func previewPDFPage(at url: URL, pageIndex: Int, maxSide: Int) throws -> Data {
    let (page, displaySize) = try pdfPage(at: url, pageIndex: pageIndex)
    guard let pageRef = page.pageRef else { throw TemplateRendererError.unreadable }
    let scale = CGFloat(maxSide) / max(displaySize.width, displaySize.height)
    let width = max(Int((displaySize.width * scale).rounded()), 1)
    let height = max(Int((displaySize.height * scale).rounded()), 1)
    let context = try makeContext(width: width, height: height)
    fillWhite(context, width: width, height: height)
    context.concatenate(
      pageRef.getDrawingTransform(
        .cropBox, rect: CGRect(x: 0, y: 0, width: width, height: height), rotate: 0, preserveAspectRatio: true))
    context.drawPDFPage(pageRef)
    return try jpeg(from: context)
  }

  /// Ganzes Bild, längste Seite höchstens `maxSide` Pixel, als JPEG.
  static func previewImage(at url: URL, maxSide: Int) throws -> Data {
    guard let image = try loadImage(at: url, maxPixel: maxSide) else { throw TemplateRendererError.unreadable }
    let context = try makeContext(width: image.width, height: image.height)
    fillWhite(context, width: image.width, height: image.height)
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    return try jpeg(from: context)
  }

  // MARK: Hilfen

  /// Seite und ihre angezeigte Größe in Punkten (bei 90°/270° vertauscht).
  private static func pdfPage(at url: URL, pageIndex: Int) throws -> (PDFPage, CGSize) {
    guard let document = PDFDocument(url: url) else { throw TemplateRendererError.unreadable }
    guard pageIndex >= 0, pageIndex < document.pageCount, let page = document.page(at: pageIndex) else {
      throw TemplateRendererError.pageOutOfRange
    }
    let box = page.bounds(for: .cropBox)
    guard box.width > 0, box.height > 0 else { throw TemplateRendererError.unreadable }
    let turned = abs(page.rotation) % 180 == 90
    return (page, turned ? CGSize(width: box.height, height: box.width) : box.size)
  }

  /// Der Ausschnitt in Seitenpunkten mit Ursprung unten links (so rechnet `CGContext`); ohne `crop` die ganze Seite.
  private static func cropArea(_ crop: CGRect?, in size: CGSize) -> CGRect {
    guard let crop else { return CGRect(origin: .zero, size: size) }
    let unit = clamped(crop)
    let area = CGRect(
      x: unit.minX * size.width, y: (1 - unit.maxY) * size.height,
      width: unit.width * size.width, height: unit.height * size.height)
    // Ein entarteter Ausschnitt (Breite oder Höhe fast null) zeigt die ganze Seite.
    guard area.width >= 1, area.height >= 1 else { return CGRect(origin: .zero, size: size) }
    return area
  }

  /// Begrenzt einen normierten Ausschnitt auf 0…1.
  private static func clamped(_ rect: CGRect) -> CGRect {
    rect.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
  }

  /// Liest ein Bild mit angewandter Ausrichtung (EXIF), höchstens `maxPixel` lang.
  private static func loadImage(at url: URL, maxPixel: Int) throws -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw TemplateRendererError.unreadable }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxPixel,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }

  private static func makeContext(width: Int, height: Int) throws -> CGContext {
    guard
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { throw TemplateRendererError.unreadable }
    return context
  }

  private static func fillWhite(_ context: CGContext, width: Int, height: Int) {
    context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
  }

  private static func jpeg(from context: CGContext) throws -> Data {
    guard let image = context.makeImage() else { throw TemplateRendererError.unreadable }
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(
        data, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw TemplateRendererError.unreadable }
    CGImageDestinationAddImage(
      destination, image, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw TemplateRendererError.unreadable }
    return data as Data
  }
}

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

/// Bereitet Bildschirmfotos für die Rückmeldung auf: verkleinern, Zeichnung und Schwärzung einrechnen, als JPEG.
enum FeedbackImageEncoder {
  /// Verkleinert nach `FeedbackAttachmentPolicy.scaledSize` (nie vergrößert) und kodiert JPEG mit Güte 0,85.
  /// Transparenz wird auf Weiß gelegt. `nil`, wenn kein Bild entsteht.
  static func preparedJPEG(from image: CGImage) -> Data? {
    let size = FeedbackAttachmentPolicy.scaledSize(width: image.width, height: image.height)
    guard let context = makeContext(width: size.width, height: size.height) else { return nil }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
    guard let result = context.makeImage() else { return nil }
    return jpegData(result)
  }

  /// Aus Dateidaten der Mediathek (HEIC, PNG, JPEG über ImageIO), mit angewandter Ausrichtung.
  static func preparedJPEG(fromImageData data: Data) -> Data? {
    guard let image = decode(data) else { return nil }
    return preparedJPEG(from: image)
  }

  /// Bild, darauf die Zeichnung (Raum der Bildpixel), darüber deckend schwarze Schwärzungen → JPEG.
  /// Die Schwärzung wird nach außen auf ganze Pixel gerundet, damit am Rand nichts durchscheint.
  static func flattened(imageData: Data, markup: PKDrawing?, redactions: [NormalizedRect]) -> Data? {
    guard let base = decode(imageData) else { return nil }
    let width = base.width
    let height = base.height
    guard let context = makeContext(width: width, height: height) else { return nil }
    context.interpolationQuality = .high
    let bounds = CGRect(x: 0, y: 0, width: width, height: height)
    context.draw(base, in: bounds)

    if let markup, !markup.strokes.isEmpty, let overlay = markupImage(markup, width: width, height: height) {
      context.draw(overlay, in: bounds)
    }

    context.setFillColor(CGColor(gray: 0, alpha: 1))
    for redaction in redactions {
      // `NormalizedRect` hat den Ursprung oben links, der `CGContext` unten links.
      let rect = CGRect(
        x: redaction.x * Double(width),
        y: Double(height) - (redaction.y + redaction.height) * Double(height),
        width: redaction.width * Double(width),
        height: redaction.height * Double(height))
      context.fill(rect.integral)
    }
    guard let result = context.makeImage() else { return nil }
    return jpegData(result)
  }

  // MARK: Hilfen

  /// RGB, 8 Bit, undurchsichtig, weiß gefüllt.
  private static func makeContext(width: Int, height: Int) -> CGContext? {
    guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    else { return nil }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context
  }

  private static func jpegData(_ image: CGImage) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
      return nil
    }
    let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: FeedbackAttachmentPolicy.jpegQuality]
    CGImageDestinationAddImage(destination, image, options as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return data as Data
  }

  /// Dekodiert mit angewandter Ausrichtung, längste Kante höchstens `maxPixelLength`, nie vergrößert.
  private static func decode(_ data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0 else {
      return nil
    }
    var longest = FeedbackAttachmentPolicy.maxPixelLength
    if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let width = properties[kCGImagePropertyPixelWidth] as? Int,
      let height = properties[kCGImagePropertyPixelHeight] as? Int
    {
      longest = min(max(width, height), FeedbackAttachmentPolicy.maxPixelLength)
    }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: longest,
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
  }

  /// Die Zeichnung als Bild in Pixelgröße; mit hellem Erscheinungsbild, damit schwarze Tinte im Dunkelmodus
  /// nicht weiß wird.
  private static func markupImage(_ drawing: PKDrawing, width: Int, height: Int) -> CGImage? {
    let rect = CGRect(x: 0, y: 0, width: width, height: height)
    #if os(iOS)
      var result: UIImage?
      UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
        result = drawing.image(from: rect, scale: 1)
      }
      return result?.cgImage
    #else
      var result: NSImage?
      NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
        result = drawing.image(from: rect, scale: 1)
      }
      return result?.cgImage(forProposedRect: nil, context: nil, hints: nil)
    #endif
  }
}

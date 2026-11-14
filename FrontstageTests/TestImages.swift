import Foundation
import ImageIO
import CoreGraphics

/// Hilfen für Bildprüfungen in Tests.
enum TestImages {
  /// Anteil der Pixel, die nicht (fast) weiß sind (Grauwert unter 250 von 255).
  static func nonWhiteRatio(_ image: CGImage) -> Double {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return 0 }
    var pixels = [UInt8](repeating: 255, count: width * height)
    let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue)
      else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard drawn else { return 0 }
    return Double(pixels.filter { $0 < 250 }.count) / Double(pixels.count)
  }
}

// MARK: Tafel-Abdeckung (Aufgabe 11)

extension TestImages {
  /// Die Grauwerte (0…255), Zeile für Zeile von oben nach unten.
  private static func grayPixels(_ image: CGImage) -> [UInt8] {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { return [] }
    var pixels = [UInt8](repeating: 255, count: width * height)
    pixels.withUnsafeMutableBytes { buffer in
      guard
        let context = CGContext(
          data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
          bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
          bitmapInfo: CGImageAlphaInfo.none.rawValue)
      else { return }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return pixels
  }

  /// Ein JPEG (2400 × 1350, weiß) mit drei schwarzen, vollbreiten Balken, deren Mitte bei 20 %, 50 % und 80 % der
  /// Höhe liegt (von oben gemessen); jeder Balken ist 6 % hoch.
  static func threeBars() -> Data {
    let width = 2400
    let height = 1350
    guard
      let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
    else { return Data() }
    context.setFillColor(gray: 1, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(gray: 0, alpha: 1)
    let barHeight = Double(height) * 0.06
    for center in [0.2, 0.5, 0.8] {
      // Swift-Hinweis: Der CGContext hat den Ursprung unten links, daher von unten gemessen.
      let y = Double(height) * (1 - center) - barHeight / 2
      context.fill(CGRect(x: 0, y: y, width: Double(width), height: barHeight))
    }
    guard let image = context.makeImage() else { return Data() }
    let data = NSMutableData()
    guard
      let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil)
    else { return Data() }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
  }

  /// Ist die Mittelzeile bei der relativen Höhe `y` (0 oben, 1 unten) dunkel (Grauwert im Mittel unter 64)?
  static func isDark(_ image: CGImage, atY y: Double) -> Bool {
    let pixels = grayPixels(image)
    guard !pixels.isEmpty else { return false }
    let row = min(max(Int(Double(image.height) * y), 0), image.height - 1)
    let slice = pixels[(row * image.width)..<((row + 1) * image.width)]
    let mean = slice.reduce(0.0) { $0 + Double($1) } / Double(slice.count)
    return mean < 64
  }

  /// Ist das Höhenband von `from` bis `to` (relativ, 0 oben) einfarbig (Standardabweichung der Grauwerte unter 2)?
  static func isUniform(_ image: CGImage, from: Double, to: Double) -> Bool {
    let pixels = grayPixels(image)
    guard !pixels.isEmpty else { return false }
    let firstRow = min(max(Int((Double(image.height) * from).rounded(.up)), 0), image.height - 1)
    let lastRow = min(max(Int(Double(image.height) * to), firstRow + 1), image.height)
    let band = pixels[(firstRow * image.width)..<(lastRow * image.width)]
    let mean = band.reduce(0.0) { $0 + Double($1) } / Double(band.count)
    let variance = band.reduce(0.0) { $0 + ($1.asDouble - mean) * ($1.asDouble - mean) } / Double(band.count)
    return variance.squareRoot() < 2
  }
}

private extension UInt8 {
  var asDouble: Double { Double(self) }
}

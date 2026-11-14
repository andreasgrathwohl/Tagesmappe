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

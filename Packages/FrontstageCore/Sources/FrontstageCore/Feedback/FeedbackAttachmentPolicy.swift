import Foundation

/// Grenzen für Bildschirmfotos in einer Rückmeldung (FR-17.4).
public enum FeedbackAttachmentPolicy {
  public static let maxCount = 5
  public static let maxPixelLength = 2048
  public static let jpegQuality = 0.85

  public static func remaining(currentCount: Int) -> Int { max(0, maxCount - currentCount) }

  /// Längste Kante höchstens `maxPixelLength`, nie vergrößert, Seitenverhältnis erhalten, gerundet, mindestens 1.
  public static func scaledSize(width: Int, height: Int) -> (width: Int, height: Int) {
    let longest = max(width, height)
    guard longest > maxPixelLength else { return (max(1, width), max(1, height)) }
    let scale = Double(maxPixelLength) / Double(longest)
    return (max(1, Int((Double(width) * scale).rounded())), max(1, Int((Double(height) * scale).rounded())))
  }

  /// Index 0 ergibt „Bildschirmfoto-1.jpg“.
  public static func fileName(index: Int) -> String { "Bildschirmfoto-\(index + 1).jpg" }
}

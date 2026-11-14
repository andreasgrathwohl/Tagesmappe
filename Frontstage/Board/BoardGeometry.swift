import CoreGraphics
import FrontstageCore

/// Maße und Linien einer Tafelseite (FR-12). Die Seite hat eine feste logische Größe; Zeichnungen
/// liegen in diesem Koordinatenraum, Anzeige und PDF skalieren daraus. SwiftUI-`Canvas` und
/// `BoardPageRenderer` benutzen dieselben Linien.
enum BoardGeometry {
  /// Logische Größe der Seite (16:9).
  static let canvasSize = CGSize(width: 1600, height: 900)
  /// Abstand der Linien auf „liniert“ (logische Einheiten). Platzhalter, Design-Runde offen.
  static let lineSpacing: CGFloat = 60
  /// Abstand der Linien auf „kariert“ (logische Einheiten). Platzhalter, Design-Runde offen.
  static let gridSpacing: CGFloat = 50
  /// Graustufe der Linien. Die Seite ist immer weiß, daher ein fester Wert statt `.secondary`, der im
  /// Dunkelmodus hell würde. Platzhalter, Design-Runde offen.
  static let lineGray: CGFloat = 0.78
  /// Strichstärke der Linien (logische Einheiten).
  static let lineWidth: CGFloat = 1.5

  /// Seitenverhältnis (Breite durch Höhe).
  static var aspectRatio: CGFloat { canvasSize.width / canvasSize.height }

  /// Linien des Hintergrunds für eine Fläche der Größe `size`, aus der logischen Seite skaliert.
  /// `blank` und `image` haben keine Linien.
  static func lines(for background: BoardBackground, in size: CGSize) -> [(CGPoint, CGPoint)] {
    let scaleX = size.width / canvasSize.width
    let scaleY = size.height / canvasSize.height
    var result: [(CGPoint, CGPoint)] = []
    func horizontal(every spacing: CGFloat) {
      for y in stride(from: spacing, to: canvasSize.height, by: spacing) {
        result.append((CGPoint(x: 0, y: y * scaleY), CGPoint(x: size.width, y: y * scaleY)))
      }
    }
    func vertical(every spacing: CGFloat) {
      for x in stride(from: spacing, to: canvasSize.width, by: spacing) {
        result.append((CGPoint(x: x * scaleX, y: 0), CGPoint(x: x * scaleX, y: size.height)))
      }
    }
    switch background {
    case .blank, .image: break
    case .lined: horizontal(every: lineSpacing)
    case .grid:
      horizontal(every: gridSpacing)
      vertical(every: gridSpacing)
    }
    return result
  }

  /// Rechteck, in dem ein Inhalt der Größe `contentSize` einpassend (ohne Verzerrung, zentriert) in `size` liegt.
  static func fittedRect(contentSize: CGSize, in size: CGSize) -> CGRect {
    guard contentSize.width > 0, contentSize.height > 0, size.width > 0, size.height > 0 else {
      return CGRect(origin: .zero, size: size)
    }
    let factor = min(size.width / contentSize.width, size.height / contentSize.height)
    let fitted = CGSize(width: contentSize.width * factor, height: contentSize.height * factor)
    return CGRect(
      x: (size.width - fitted.width) / 2, y: (size.height - fitted.height) / 2,
      width: fitted.width, height: fitted.height)
  }
}

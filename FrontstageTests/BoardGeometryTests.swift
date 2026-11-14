import CoreGraphics
import Testing

@testable import Frontstage

@Suite struct BoardGeometryTests {
  @Test("Liniert: waagerechte Linien im Abstand, ohne Rand")
  func linedHasHorizontalLines() {
    let lines = BoardGeometry.lines(for: .lined, in: BoardGeometry.canvasSize)
    #expect(lines.count == 14)
    #expect(lines.allSatisfy { $0.0.y == $0.1.y })
    #expect(lines[0].0.y == BoardGeometry.lineSpacing)
  }

  @Test("Kariert: waagerechte und senkrechte Linien")
  func gridHasBothDirections() {
    let lines = BoardGeometry.lines(for: .grid, in: BoardGeometry.canvasSize)
    #expect(lines.filter { $0.0.y == $0.1.y }.count == 17)
    #expect(lines.filter { $0.0.x == $0.1.x }.count == 31)
  }

  @Test("Leer und Bild haben keine Linien")
  func blankAndImageHaveNoLines() {
    #expect(BoardGeometry.lines(for: .blank, in: BoardGeometry.canvasSize).isEmpty)
    #expect(BoardGeometry.lines(for: .image, in: BoardGeometry.canvasSize).isEmpty)
  }

  @Test("Linien skalieren mit der Fläche")
  func linesScale() {
    let half = CGSize(width: 800, height: 450)
    let lines = BoardGeometry.lines(for: .lined, in: half)
    #expect(lines[0].0.y == BoardGeometry.lineSpacing / 2)
    #expect(lines[0].1.x == 800)
  }

  @Test("Einpassen: breiteres Bild wird oben und unten zentriert")
  func fittedRectCentersWideContent() {
    let rect = BoardGeometry.fittedRect(contentSize: CGSize(width: 200, height: 50), in: CGSize(width: 100, height: 100))
    #expect(rect == CGRect(x: 0, y: 37.5, width: 100, height: 25))
  }
}

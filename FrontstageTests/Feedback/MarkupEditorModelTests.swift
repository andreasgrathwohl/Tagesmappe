import CoreGraphics
import Foundation
import FrontstageCore
import PencilKit
import Testing

@testable import Frontstage

@MainActor @Suite struct MarkupEditorModelTests {
  private func makeModel() -> MarkupEditorModel {
    MarkupEditorModel(pixelSize: CGSize(width: 400, height: 300), drawing: PKDrawing(), redactions: [])
  }

  private func stroke() -> PKStroke {
    let points = [CGPoint(x: 10, y: 10), CGPoint(x: 60, y: 40)].enumerated().map { index, point in
      PKStrokePoint(
        location: point, timeOffset: TimeInterval(index) * 0.01, size: CGSize(width: 6, height: 6),
        opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
    }
    return PKStroke(
      ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
  }

  private let rect = NormalizedRect(x: 0.1, y: 0.1, width: 0.3, height: 0.2)

  @Test("Schwärzung hinzufügen und rückgängig")
  func undoRemovesRedaction() {
    let model = makeModel()
    model.addRedaction(rect)
    #expect(model.redactions == [rect])
    #expect(model.canUndo)
    model.undo()
    #expect(model.redactions.isEmpty)
    #expect(!model.canUndo)
  }

  @Test("Strich rückgängig stellt die vorige Zeichnung her")
  func undoRestoresDrawing() {
    let model = makeModel()
    model.addStroke(stroke())
    #expect(model.drawing.strokes.count == 1)
    model.undo()
    #expect(model.drawing.strokes.isEmpty)
  }

  @Test("Gemischte Reihenfolge: Rückgängig nimmt das Letzte")
  func undoIsChronological() {
    let model = makeModel()
    model.addStroke(stroke())
    model.addRedaction(rect)
    model.undo()
    #expect(model.redactions.isEmpty)
    #expect(model.drawing.strokes.count == 1)
    model.undo()
    #expect(model.drawing.strokes.isEmpty)
  }

  @Test("Alles löschen ist ein Schritt")
  func clearIsUndoable() {
    let model = makeModel()
    model.addStroke(stroke())
    model.addRedaction(rect)
    model.clear()
    #expect(model.drawing.strokes.isEmpty)
    #expect(model.redactions.isEmpty)
    model.undo()
    #expect(model.drawing.strokes.count == 1)
    #expect(model.redactions == [rect])
  }

  @Test("Ohne Schritte nichts rückgängig")
  func cannotUndoInitially() {
    let model = makeModel()
    #expect(!model.canUndo)
    model.undo()
    #expect(model.drawing.strokes.isEmpty)
    #expect(model.redactions.isEmpty)
    #expect(model.mode == .draw)
  }
}

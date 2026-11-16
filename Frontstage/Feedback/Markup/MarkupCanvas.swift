#if os(iOS)
  import FrontstageCore
  import PencilKit
  import SwiftUI
  import UIKit

  /// Zeichenfläche des Bildeditors (iPad): transparente `PKCanvasView` über dem Bild, Zeichnung in Bildpixeln.
  ///
  /// Nutzt `PageCanvasView` (Viewer): Sie rechnet die Pixelzeichnung per `DrawingGeometry` in die aktuelle
  /// Ansichtsgröße um und erkennt das Echo des Delegates. Werkzeugpalette nur im Zeichnen-Modus.
  struct MarkupCanvas: UIViewRepresentable {
    let model: MarkupEditorModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> PageCanvasView {
      let canvas = PageCanvasView()
      canvas.backgroundColor = .clear
      canvas.isOpaque = false
      canvas.drawingPolicy = .anyInput
      // Die Tinte soll im Dunkelmodus nicht umgefärbt werden.
      canvas.overrideUserInterfaceStyle = .light
      canvas.delegate = context.coordinator
      return canvas
    }

    func updateUIView(_ canvas: PageCanvasView, context: Context) {
      context.coordinator.model = model
      canvas.pageSize = PageSize(width: model.pixelSize.width, height: model.pixelSize.height)
      let drawing = model.mode == .draw
      canvas.isUserInteractionEnabled = drawing
      if canvas.pageDrawing != model.drawing { canvas.setPageDrawing(model.drawing) }
      context.coordinator.updateToolPicker(for: canvas, visible: drawing)
    }

    @MainActor final class Coordinator: NSObject, @preconcurrency PKCanvasViewDelegate {
      var model: MarkupEditorModel
      private let toolPicker = PKToolPicker()
      private var observed = false

      init(model: MarkupEditorModel) { self.model = model }

      func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard let canvas = canvasView as? PageCanvasView, let changed = canvas.takeChangedPageDrawing() else {
          return
        }
        model.replaceDrawing(changed)
      }

      func updateToolPicker(for canvas: PageCanvasView, visible: Bool) {
        if !observed {
          toolPicker.addObserver(canvas)
          observed = true
        }
        toolPicker.setVisible(visible, forFirstResponder: canvas)
        if visible {
          // Erst wenn die Ansicht im Fenster steht, kann sie erster Responder werden.
          Task { @MainActor in _ = canvas.becomeFirstResponder() }
        }
      }
    }
  }
#endif

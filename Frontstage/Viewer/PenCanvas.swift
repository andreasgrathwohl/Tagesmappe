#if os(iOS)
  import FrontstageCore
  import PencilKit
  import SwiftUI
  import UIKit

  /// `PKCanvasView`, die ihre Zeichnung in **Seitenkoordinaten** hält und sie je nach aktueller Größe der Ansicht
  /// umgerechnet anzeigt (`DrawingGeometry`, ADR-0011).
  ///
  /// Warum eine Unterklasse: Die Überlagerung einer PDF-Seite bekommt ihre Größe erst nach dem Erzeugen und
  /// ändert sie beim Drehen oder Zoomen. `layoutSubviews` rechnet die gemerkte Seitenzeichnung dann neu in die
  /// Ansicht um. Eine Zuweisung von `drawing` löst den Delegate aus; `takeChangedPageDrawing()` erkennt dieses
  /// Echo am gemerkten Stand und liefert dann `nil`.
  final class PageCanvasView: PKCanvasView {
    /// Größe der Seite in PDF-Punkten (Koordinatenraum der gespeicherten Zeichnung).
    var pageSize = PageSize(width: 0, height: 0) {
      didSet { if pageSize != oldValue { applyPageDrawing() } }
    }
    private(set) var pageDrawing = PKDrawing()
    private var appliedSize: CGSize = .zero
    private var appliedDrawing: PKDrawing?

    /// Setzt die Zeichnung (Seitenkoordinaten) und zeigt sie in der aktuellen Größe an.
    func setPageDrawing(_ drawing: PKDrawing) {
      pageDrawing = drawing
      applyPageDrawing()
    }

    /// Hat die Lehrkraft etwas gezeichnet? Dann die neue Zeichnung in Seitenkoordinaten, sonst `nil` (Echo).
    func takeChangedPageDrawing() -> PKDrawing? {
      guard bounds.width > 0, bounds.height > 0 else { return nil }
      if let appliedDrawing, drawing == appliedDrawing { return nil }
      let converted = DrawingGeometry.toPageSpace(drawing, viewSize: bounds.size, pageSize: pageSize)
      pageDrawing = converted
      appliedDrawing = drawing
      return converted
    }

    private func applyPageDrawing() {
      guard bounds.width > 0, bounds.height > 0 else { return }
      appliedSize = bounds.size
      let shown = DrawingGeometry.toViewSpace(pageDrawing, viewSize: bounds.size, pageSize: pageSize)
      appliedDrawing = shown
      drawing = shown
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      if bounds.size != appliedSize { applyPageDrawing() }
    }
  }

  /// `PKCanvasView` als SwiftUI-Ansicht; Werkzeuge über `PKToolPicker`. Auch die Tafel (Teilplan 07) nutzt sie.
  ///
  /// Die Zeichnung liegt im Koordinatenraum `contentSize`; die Ansicht skaliert sie auf ihre tatsächliche Größe.
  ///
  /// Swift-Hinweis: `UIViewRepresentable` bettet eine UIKit-Ansicht ein; der `Coordinator` nimmt die
  /// UIKit-Rückrufe (Delegate) entgegen und gibt sie an SwiftUI weiter.
  struct PenCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    let isEditable: Bool
    let contentSize: CGSize
    let onStrokeEnded: () -> Void

    init(
      drawing: Binding<PKDrawing>, isEditable: Bool, contentSize: CGSize,
      onStrokeEnded: @escaping () -> Void = {}
    ) {
      _drawing = drawing
      self.isEditable = isEditable
      self.contentSize = contentSize
      self.onStrokeEnded = onStrokeEnded
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PageCanvasView {
      let canvas = PageCanvasView()
      canvas.backgroundColor = .clear
      canvas.isOpaque = false
      canvas.drawingPolicy = .default
      // Tinte soll im Dunkelmodus nicht umgefärbt werden: Das Material ist eine helle Fläche.
      canvas.overrideUserInterfaceStyle = .light
      canvas.delegate = context.coordinator
      context.coordinator.parent = self
      return canvas
    }

    func updateUIView(_ canvas: PageCanvasView, context: Context) {
      context.coordinator.parent = self
      canvas.pageSize = PageSize(width: contentSize.width, height: contentSize.height)
      canvas.isUserInteractionEnabled = isEditable
      if canvas.pageDrawing != drawing { canvas.setPageDrawing(drawing) }
      context.coordinator.updateToolPicker(for: canvas, visible: isEditable)
    }

    @MainActor final class Coordinator: NSObject, @preconcurrency PKCanvasViewDelegate {
      var parent: PenCanvas?
      private let toolPicker = PKToolPicker()
      private var observed = false

      func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard let canvas = canvasView as? PageCanvasView, let changed = canvas.takeChangedPageDrawing() else {
          return
        }
        parent?.drawing = changed
      }

      func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        parent?.onStrokeEnded()
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

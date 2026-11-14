import FrontstageCore
import PDFKit
import PencilKit
import SwiftUI

/// Baut das `PDFDocument` für `PDFDisplayView` aus den Rohdaten (PDF oder Bild).
enum PDFDisplayDocument {
  /// Eigenes Dokument je Anzeige: ein `PDFDocument` wird nicht zwischen mehreren `PDFView`s geteilt.
  static func make(from data: Data) -> PDFDocument? {
    if let pdf = PDFDocument(data: data), pdf.pageCount > 0 { return pdf }
    return try? MaterialDocumentLoader.makeDocument(from: data, kind: .image)
  }
}

#if os(iOS)
  import UIKit

  /// Zeigt eine Seite des Materials mit der Zeichnung darüber – nur anzeigen, keine Eingabe (Zweitbildschirm).
  /// `documentData`: PDF oder Bild; `visibleRect`: Ausschnitt in PDFKit-Seitenkoordinaten (ungedreht, Ursprung
  /// unten links), `nil` = ganze Seite; `drawing`: Seitenkoordinaten (oben links, PDF-Punkt).
  ///
  /// Swift-Hinweis: `UIViewRepresentable` bettet eine UIKit-Ansicht ein. Hier ein Container aus `PDFView` und einer
  /// nicht bedienbaren `PKCanvasView`, die genau über der Seite liegt.
  struct PDFDisplayView: UIViewRepresentable {
    let documentData: Data
    let pageIndex: Int
    let drawing: PKDrawing?
    let visibleRect: CGRect?

    func makeUIView(context: Context) -> DisplayContainerView { DisplayContainerView() }

    func updateUIView(_ view: DisplayContainerView, context: Context) {
      view.update(data: documentData, pageIndex: pageIndex, drawing: drawing, visibleRect: visibleRect)
    }

    static func dismantleUIView(_ view: DisplayContainerView, coordinator: ()) {
      view.detach()
    }
  }

  final class DisplayContainerView: UIView {
    private let pdfView = PDFView()
    private let overlay = PageCanvasView()
    private var loadedData: Data?
    private var pageIndex = 0
    private var visibleRect: CGRect?
    private var observers: [NSObjectProtocol] = []

    override init(frame: CGRect) {
      super.init(frame: frame)
      clipsToBounds = true
      pdfView.displayMode = .singlePage
      pdfView.autoScales = true
      pdfView.isUserInteractionEnabled = false
      addSubview(pdfView)
      overlay.backgroundColor = .clear
      overlay.isOpaque = false
      overlay.isUserInteractionEnabled = false
      overlay.isScrollEnabled = false
      overlay.overrideUserInterfaceStyle = .light
      addSubview(overlay)
      for name in [Notification.Name.PDFViewScaleChanged, .PDFViewPageChanged] {
        let token = NotificationCenter.default.addObserver(forName: name, object: pdfView, queue: .main) {
          [weak self] _ in
          MainActor.assumeIsolated { self?.setNeedsLayout() }
        }
        observers.append(token)
      }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

    func detach() {
      for token in observers { NotificationCenter.default.removeObserver(token) }
      observers = []
    }

    func update(data: Data, pageIndex: Int, drawing: PKDrawing?, visibleRect: CGRect?) {
      if loadedData != data {
        loadedData = data
        pdfView.document = PDFDisplayDocument.make(from: data)
      }
      self.pageIndex = pageIndex
      self.visibleRect = visibleRect
      overlay.setPageDrawing(drawing ?? PKDrawing())
      showPage()
      setNeedsLayout()
    }

    private func showPage() {
      guard let document = pdfView.document, let page = document.page(at: pageIndex) else { return }
      if let visibleRect {
        pdfView.go(to: visibleRect, on: page)
      } else {
        pdfView.go(to: page)
      }
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      pdfView.frame = bounds
      guard let document = pdfView.document, let page = document.page(at: pageIndex) else {
        overlay.frame = .zero
        return
      }
      // Die Seite so, wie die `PDFView` sie gerade zeichnet (Zoom, Ausschnitt, Drehung eingerechnet).
      let rect = pdfView.convert(page.bounds(for: .mediaBox), from: page)
      overlay.pageSize = DrawingGeometry.pageSize(of: page)
      overlay.frame = rect
    }
  }
#else
  import AppKit

  /// Zeigt eine Seite des Materials mit der Zeichnung darüber – nur anzeigen (Anzeige am Mac, Zweitbildschirm).
  /// Parameter wie in der iOS-Fassung.
  ///
  /// Swift-Hinweis: `NSViewRepresentable` ist das AppKit-Gegenstück zu `UIViewRepresentable`. PencilKit hat am Mac
  /// keine Zeichenfläche, aber `PKDrawing` lässt sich als Bild rendern – das liegt hier über der Seite.
  struct PDFDisplayView: NSViewRepresentable {
    let documentData: Data
    let pageIndex: Int
    let drawing: PKDrawing?
    let visibleRect: CGRect?

    func makeNSView(context: Context) -> DisplayContainerView { DisplayContainerView() }

    func updateNSView(_ view: DisplayContainerView, context: Context) {
      view.update(data: documentData, pageIndex: pageIndex, drawing: drawing, visibleRect: visibleRect)
    }

    static func dismantleNSView(_ view: DisplayContainerView, coordinator: ()) {
      view.detach()
    }
  }

  final class DisplayContainerView: NSView {
    private let pdfView = PDFView()
    private let overlay = NSImageView()
    private var loadedData: Data?
    private var pageIndex = 0
    private var drawing = PKDrawing()
    private var observers: [NSObjectProtocol] = []

    override init(frame: NSRect) {
      super.init(frame: frame)
      pdfView.displayMode = .singlePage
      pdfView.autoScales = true
      pdfView.displaysPageBreaks = false
      addSubview(pdfView)
      overlay.imageScaling = .scaleAxesIndependently
      addSubview(overlay)
      for name in [Notification.Name.PDFViewScaleChanged, .PDFViewPageChanged] {
        let token = NotificationCenter.default.addObserver(forName: name, object: pdfView, queue: .main) {
          [weak self] _ in
          MainActor.assumeIsolated { self?.needsLayout = true }
        }
        observers.append(token)
      }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) wird nicht benutzt") }

    /// Die Überlagerung soll keine Mausklicks abfangen.
    override func hitTest(_ point: NSPoint) -> NSView? { pdfView.hitTest(point) }

    func detach() {
      for token in observers { NotificationCenter.default.removeObserver(token) }
      observers = []
    }

    func update(data: Data, pageIndex: Int, drawing: PKDrawing?, visibleRect: CGRect?) {
      if loadedData != data {
        loadedData = data
        pdfView.document = PDFDisplayDocument.make(from: data)
      }
      self.pageIndex = pageIndex
      self.drawing = drawing ?? PKDrawing()
      if let page = pdfView.document?.page(at: pageIndex) {
        if let visibleRect {
          pdfView.go(to: visibleRect, on: page)
        } else {
          pdfView.go(to: page)
        }
      }
      needsLayout = true
    }

    override func layout() {
      super.layout()
      pdfView.frame = bounds
      guard let page = pdfView.document?.page(at: pageIndex) else {
        overlay.image = nil
        return
      }
      let inPDFView = pdfView.convert(page.bounds(for: .mediaBox), from: page)
      let rect = convert(inPDFView, from: pdfView)
      overlay.frame = rect
      guard !drawing.strokes.isEmpty, rect.width > 0, rect.height > 0 else {
        overlay.image = nil
        return
      }
      let scaled = DrawingGeometry.toViewSpace(
        drawing, viewSize: rect.size, pageSize: DrawingGeometry.pageSize(of: page))
      let scale = window?.backingScaleFactor ?? 2
      overlay.image = scaled.image(from: CGRect(origin: .zero, size: rect.size), scale: scale)
    }
  }
#endif

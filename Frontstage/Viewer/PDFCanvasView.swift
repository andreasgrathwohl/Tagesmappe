#if os(iOS)
  import FrontstageCore
  import PDFKit
  import PencilKit
  import SwiftUI
  import UIKit

  /// Zeigt das Material einseitig und legt je Seite eine Zeichenfläche darüber (ADR-0011, FR-6).
  ///
  /// Swift-Hinweis: `UIViewRepresentable` bettet eine UIKit-Ansicht (`PDFView`) in SwiftUI ein; der `Coordinator`
  /// ist das Objekt, das UIKit-Rückrufe (Delegates, Benachrichtigungen) entgegennimmt. `PDFView` fragt über
  /// `pageOverlayViewProvider` für jede sichtbare Seite eine Überlagerung an und skaliert sie mit der Seite mit.
  struct PDFCanvasView: UIViewRepresentable {
    let model: ViewerModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeUIView(context: Context) -> PDFView {
      let view = PDFView()
      view.displayMode = .singlePage
      view.autoScales = true
      view.usePageViewController(true)
      // iOS 16: Markup-Modus überlässt Stifteingaben der Überlagerung statt PDFKits eigener Auswahl.
      view.isInMarkupMode = true
      // Der Anbieter muss vor dem Dokument gesetzt sein, sonst fehlen die Überlagerungen der ersten Seite.
      view.pageOverlayViewProvider = context.coordinator
      view.document = model.document
      context.coordinator.attach(to: view)
      return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
      context.coordinator.update(view, canDraw: model.canDraw, requestedPage: model.pageIndex)
    }

    static func dismantleUIView(_ view: PDFView, coordinator: Coordinator) {
      coordinator.detach()
    }

    @MainActor final class Coordinator: NSObject {
      private let model: ViewerModel
      private weak var pdfView: PDFView?
      private var canvases: [Int: PageCanvasView] = [:]
      private let toolPicker = PKToolPicker()
      private var canDraw = false
      /// Zuletzt gesehener Wunsch des Modells (Knöpfe vor/zurück). Nur eine Änderung des Modells blättert die
      /// Ansicht – sonst würde ein Wischen vom noch alten Modellstand zurückgesetzt.
      private var lastRequestedPage = 0
      private var observers: [NSObjectProtocol] = []

      init(model: ViewerModel) {
        self.model = model
      }

      func attach(to view: PDFView) {
        pdfView = view
        let center = NotificationCenter.default
        for name in [Notification.Name.PDFViewPageChanged, .PDFViewScaleChanged] {
          let token = center.addObserver(forName: name, object: view, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.viewportChanged() }
          }
          observers.append(token)
        }
      }

      func detach() {
        for token in observers { NotificationCenter.default.removeObserver(token) }
        observers = []
      }

      func update(_ view: PDFView, canDraw: Bool, requestedPage: Int) {
        if view.document !== model.document { view.document = model.document }
        self.canDraw = canDraw
        for canvas in canvases.values { canvas.isUserInteractionEnabled = canDraw }
        if requestedPage != lastRequestedPage {
          lastRequestedPage = requestedPage
          if let document = view.document, let page = document.page(at: requestedPage),
            view.currentPage.map({ document.index(for: $0) }) != requestedPage
          {
            view.go(to: page)
          }
        }
        activateTools()
      }

      // MARK: Blättern und Zoomen

      private func viewportChanged() {
        guard let view = pdfView, let document = view.document, let page = view.currentPage else { return }
        let index = document.index(for: page)
        // Sichtbarer Ausschnitt in PDFKit-Seitenkoordinaten (ungedreht, Ursprung unten links); `nil`, wenn die
        // ganze Seite zu sehen ist.
        let visible = view.convert(view.bounds, to: page)
        let box = page.bounds(for: .mediaBox)
        let rect: CGRect? = visible.insetBy(dx: -1, dy: -1).contains(box) ? nil : visible
        Task { await model.pageChanged(to: index, visibleRect: rect) }
        activateTools()
      }

      // MARK: Werkzeuge

      /// Werkzeugpalette an die Zeichenfläche der aktuellen Seite hängen.
      private func activateTools() {
        guard let view = pdfView, let document = view.document, let page = view.currentPage,
          let canvas = canvases[document.index(for: page)]
        else { return }
        toolPicker.addObserver(canvas)
        toolPicker.setVisible(canDraw, forFirstResponder: canvas)
        if canDraw, !canvas.isFirstResponder {
          Task { @MainActor in _ = canvas.becomeFirstResponder() }
        }
      }
    }
  }

  // Swift-Hinweis: `@preconcurrency` – die PDFKit- und PencilKit-Protokolle sind je nach SDK nicht als
  // `@MainActor` gekennzeichnet, werden aber immer auf dem Hauptthread gerufen.
  extension PDFCanvasView.Coordinator: @preconcurrency PDFPageOverlayViewProvider {
    func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
      guard let document = view.document else { return nil }
      let index = document.index(for: page)
      let canvas = PageCanvasView()
      canvas.backgroundColor = .clear
      canvas.isOpaque = false
      // `.default` folgt der Systemeinstellung „Nur mit Apple Pencil zeichnen“.
      canvas.drawingPolicy = .default
      // Die Seite ist weiß: Tinte darf im Dunkelmodus nicht umgefärbt werden.
      canvas.overrideUserInterfaceStyle = .light
      canvas.isUserInteractionEnabled = model.canDraw
      canvas.pageSize = DrawingGeometry.pageSize(of: page)
      canvas.delegate = self
      if let stored = model.drawing(forPage: index) { canvas.setPageDrawing(stored) }
      canvases[index] = canvas
      return canvas
    }

    func pdfView(_ view: PDFView, willDisplayOverlayView overlayView: UIView, for page: PDFPage) {
      activateTools()
    }

    func pdfView(_ view: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
      // Die verlassene Seite wird sofort geschrieben; ihre Zeichenfläche wird nicht mehr gebraucht.
      if let document = view.document {
        canvases[document.index(for: page)] = nil
      }
      Task { await model.flushNow() }
    }
  }

  extension PDFCanvasView.Coordinator: @preconcurrency PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
      guard let canvas = canvasView as? PageCanvasView,
        let index = canvases.first(where: { $0.value === canvas })?.key,
        let changed = canvas.takeChangedPageDrawing()
      else { return }
      model.drawingChanged(changed, pageIndex: index)
    }
  }
#endif

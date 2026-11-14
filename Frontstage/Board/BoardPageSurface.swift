import FrontstageCore
import PencilKit
import SwiftUI

/// Eine Tafelseite als Fläche: Hintergrund, Zeichnung, Abdeckung; 16:9, einpassend (FR-12).
///
/// Am Tablet (iOS, `audience == .tablet`) liegt darüber `PenCanvas` zum Zeichnen; am Mac und am Zweitbildschirm
/// wird die Zeichnung als Bild gezeigt. Mit `isEditable == false` lässt sich nicht zeichnen (frühere Tafelbilder, Mac).
///
/// Swift-Hinweis: `drawing` ist eine `Binding`, weil `PenCanvas` Änderungen darüber zurückmeldet; wer nur anzeigt,
/// übergibt `.constant(…)`. Eine `@State`-Eigenschaft macht den automatischen `init` privat, daher der eigene.
struct BoardPageSurface: View {
  let page: BoardPageSnapshot
  let drawing: Binding<PKDrawing>
  let isEditable: Bool
  let cover: BoardCover?
  let audience: BoardCover.Audience

  /// Das dekodierte Hintergrundbild; wird beim Seitenwechsel neu gelesen.
  @State private var backgroundImage: CGImage?

  init(
    page: BoardPageSnapshot, drawing: Binding<PKDrawing>, isEditable: Bool = false, cover: BoardCover?,
    audience: BoardCover.Audience
  ) {
    self.page = page
    self.drawing = drawing
    self.isEditable = isEditable
    self.cover = cover
    self.audience = audience
  }

  var body: some View {
    ZStack {
      Color.white
      BoardBackgroundCanvas(background: page.background, image: backgroundImage)
      drawingLayer
      coverLayer
    }
    .aspectRatio(BoardGeometry.aspectRatio, contentMode: .fit)
    .clipped()
    // Swift-Hinweis: `.task(id:)` läuft neu, sobald sich `id` ändert; hier beim Wechsel des Hintergrundbilds.
    .task(id: page.backgroundImageData) {
      backgroundImage = page.backgroundImageData.flatMap { BoardPageRenderer.decodeImage($0) }
    }
  }

  @ViewBuilder private var drawingLayer: some View {
    #if os(iOS)
      if audience == .tablet {
        PenCanvas(drawing: drawing, isEditable: isEditable, contentSize: BoardGeometry.canvasSize)
      } else {
        drawingImage
      }
    #else
      drawingImage
    #endif
  }

  /// Die Zeichnung als Bild; doppelte Pixeldichte, damit sie auf einem großen Bildschirm scharf bleibt.
  @ViewBuilder private var drawingImage: some View {
    if let image = BoardPageRenderer.drawingImage(drawing.wrappedValue, scale: 2) {
      Image(decorative: image, scale: 2)
        .resizable()
        .scaledToFit()
    }
  }

  /// Abdeckung von unten: 0 = ganz verdeckt, 1 = ganz frei; der freie Teil liegt oben (FR-12.7).
  @ViewBuilder private var coverLayer: some View {
    if let cover {
      GeometryReader { proxy in
        VStack(spacing: 0) {
          Spacer(minLength: 0)
          // Platzhalter-Farbe, Gestaltung offen.
          Rectangle()
            .fill(Color.black.opacity(BoardCover.opacity(for: audience)))
            .frame(height: proxy.size.height * (1 - cover.revealedFraction))
        }
      }
      .allowsHitTesting(false)
    }
  }
}

/// Linien und Hintergrundbild der Seite, mit denselben Linien wie das PDF (`BoardGeometry.lines`).
private struct BoardBackgroundCanvas: View {
  let background: BoardBackground
  let image: CGImage?

  var body: some View {
    Canvas { context, size in
      let scale = size.width / BoardGeometry.canvasSize.width
      for (start, end) in BoardGeometry.lines(for: background, in: size) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(
          path, with: .color(Color(white: BoardGeometry.lineGray)),
          lineWidth: BoardGeometry.lineWidth * scale)
      }
      if background == .image, let image {
        let rect = BoardGeometry.fittedRect(
          contentSize: CGSize(width: image.width, height: image.height), in: size)
        context.draw(Image(decorative: image, scale: 1), in: rect)
      }
    }
    .accessibilityHidden(true)
  }
}

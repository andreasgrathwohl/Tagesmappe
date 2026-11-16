#if os(macOS)
  import AppKit
  import PencilKit
  import SwiftUI

  /// Werkzeug der Mac-Zeichenfläche.
  enum MacMarkupTool: Hashable { case pen, marker }

  /// Zeichenfläche des Bildeditors (Mac): PencilKit bietet dort keine Zeichenansicht, also sammelt eine
  /// `DragGesture` Punkte und baut beim Loslassen einen `PKStroke` in Bildpixeln.
  struct MacMarkupCanvas: View {
    let model: MarkupEditorModel
    let tool: MacMarkupTool

    @State private var points: [CGPoint] = []

    private var screenWidth: CGFloat { tool == .marker ? 18 : 6 }

    var body: some View {
      GeometryReader { proxy in
        let size = proxy.size
        let factor = size.width > 0 ? model.pixelSize.width / size.width : 1
        Canvas { context, canvasSize in
          if !model.drawing.strokes.isEmpty, canvasSize.width > 0 {
            let scale = canvasSize.width / model.pixelSize.width
            let image = model.drawing.image(from: CGRect(origin: .zero, size: model.pixelSize), scale: scale)
            context.draw(Image(nsImage: image), in: CGRect(origin: .zero, size: canvasSize))
          }
          if points.count > 1 {
            var path = Path()
            path.addLines(points)
            let color: Color = tool == .marker ? Color.yellow.opacity(0.5) : Color.red
            context.stroke(
              path, with: .color(color),
              style: StrokeStyle(lineWidth: screenWidth, lineCap: .round, lineJoin: .round))
          }
        }
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { points.append($0.location) }
            .onEnded { value in
              points.append(value.location)
              if let stroke = makeStroke(from: points, factor: factor) { model.addStroke(stroke) }
              points = []
            }
        )
      }
      .allowsHitTesting(model.mode == .draw)
    }

    /// Ansichtspunkte → Strich in Bildpixeln. Die Stiftgröße folgt der Bildschirmgröße (`factor` = Pixel je
    /// Punkt), damit der Strich bei jeder Bildgröße gleich dick wirkt.
    private func makeStroke(from points: [CGPoint], factor: CGFloat) -> PKStroke? {
      guard !points.isEmpty else { return nil }
      let width = screenWidth * factor
      let controlPoints = points.enumerated().map { index, point in
        PKStrokePoint(
          location: CGPoint(x: point.x * factor, y: point.y * factor), timeOffset: TimeInterval(index) * 0.01,
          size: CGSize(width: width, height: width), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
      }
      let ink = PKInk(tool == .marker ? .marker : .pen, color: tool == .marker ? .systemYellow : .systemRed)
      return PKStroke(ink: ink, path: PKStrokePath(controlPoints: controlPoints, creationDate: .now))
    }
  }
#endif

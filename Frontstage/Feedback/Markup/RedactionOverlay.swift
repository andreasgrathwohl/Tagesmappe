import FrontstageCore
import SwiftUI

/// Zeigt Schwärzungen als deckend schwarze Rechtecke und nimmt im Modus Schwärzen das Ziehen eines neuen
/// Rechtecks an. Liegt in gleicher Größe über dem Bild; Schwärzungen laufen nie über PencilKit.
struct RedactionOverlay: View {
  let redactions: [NormalizedRect]
  let isActive: Bool
  let onAdd: (NormalizedRect) -> Void

  @State private var dragStart: CGPoint?
  @State private var dragCurrent: CGPoint?

  var body: some View {
    GeometryReader { proxy in
      let size = proxy.size
      ZStack(alignment: .topLeading) {
        ForEach(Array(redactions.enumerated()), id: \.offset) { _, rect in
          Rectangle()
            .fill(Color.black)
            .frame(width: rect.width * size.width, height: rect.height * size.height)
            .offset(x: rect.x * size.width, y: rect.y * size.height)
        }
        if let start = dragStart, let current = dragCurrent {
          let frame = CGRect(
            x: min(start.x, current.x), y: min(start.y, current.y),
            width: abs(start.x - current.x), height: abs(start.y - current.y))
          Rectangle()
            .fill(Color.black.opacity(0.35))
            .overlay(Rectangle().stroke(Color.white, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
            .overlay(
              Rectangle().stroke(Color.black, style: StrokeStyle(lineWidth: 1, dash: [6, 4], dashPhase: 5))
            )
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
        }
      }
      .frame(width: size.width, height: size.height, alignment: .topLeading)
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 4)
          .onChanged { value in
            dragStart = value.startLocation
            dragCurrent = value.location
          }
          .onEnded { value in
            defer {
              dragStart = nil
              dragCurrent = nil
            }
            if let rect = NormalizedRect.spanning(
              // Ausdrücklich `Double`: `CGFloat` wird in Tupeln nicht verlässlich still umgewandelt.
              from: (Double(value.startLocation.x), Double(value.startLocation.y)),
              to: (Double(value.location.x), Double(value.location.y)),
              in: (Double(size.width), Double(size.height)))
            {
              onAdd(rect)
            }
          },
        isEnabled: isActive
      )
    }
    .allowsHitTesting(isActive)
    .accessibilityHidden(true)
  }
}

import FrontstageCore
import SwiftUI

/// Ziehgriff der Abdeckung (FR-12.7), nur am Tablet: liegt auf der Kante, bis zu der die Tafel schon frei ist, und setzt
/// beim Ziehen `BoardCover.reveal(to:)` aus der Fingerposition relativ zur Seitenhöhe.
///
/// Wird als `overlay` über `BoardPageSurface` gelegt und hat damit dessen Größe. Die Kante ist eine Platzhalter-Gestaltung;
/// die Trefferfläche ist mit 44 pt hoch genug für den Finger.
struct BoardCoverHandle: View {
  @Binding var cover: BoardCover?

  /// Höhe der Trefferfläche in Punkten.
  private static let touchHeight: CGFloat = 44

  var body: some View {
    GeometryReader { proxy in
      if let current = cover, proxy.size.height > 0 {
        let height = proxy.size.height
        ZStack {
          Capsule()
            .fill(.secondary)
            .frame(width: 96, height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.touchHeight)
        .contentShape(Rectangle())
        .position(x: proxy.size.width / 2, y: height * current.revealedFraction)
        // Swift-Hinweis: Die Geste liefert die Position im Koordinatensystem der umgebenden `GeometryReader`-Fläche
        // (`.local` des Elternteils wäre hier der Griff selbst), deshalb ein benannter Raum.
        .gesture(
          DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
              var updated = cover ?? BoardCover()
              updated.reveal(to: value.location.y / height)
              cover = updated
            }
        )
        .accessibilityLabel(Text("board.cover.handle"))
        .accessibilityAdjustableAction { direction in
          var updated = cover ?? BoardCover()
          let step = 0.1
          updated.reveal(to: updated.revealedFraction + (direction == .increment ? step : -step))
          cover = updated
        }
      }
    }
    .coordinateSpace(name: Self.space)
  }

  private static let space = "boardCoverHandle"
}

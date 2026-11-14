import SwiftUI

/// Tafel des Zweitbildschirms: zeigt die aktuelle Seite der `BoardSession` ohne Bedienelemente (FR-12).
/// Ohne Kauf eine neutrale Fläche (FR-13).
///
/// Ist die Kamera der Tafel an (`BoardSession.isCameraLive`, FR-12.5), zeigt der Zweitbildschirm das Livebild statt
/// der Seite.
struct BoardView: View {
  @Environment(Unlock.self) private var unlock
  @Environment(BoardSession.self) private var session: BoardSession?

  var body: some View {
    switch SecondScreenRendering.resolve(.board, isUnlocked: unlock.isUnlocked) {
    case .board:
      if let session, session.isCameraLive {
        cameraLive
      } else if let session, let page = session.currentPage {
        ZStack {
          // Streifen neben der Seite, wenn der Bildschirm nicht 16:9 ist. Platzhalter, Gestaltung offen.
          Color.black
          BoardPageSurface(
            page: page, drawing: .constant(session.liveDrawing), cover: session.cover, audience: .secondScreen)
        }
      } else {
        SystemBackground()
      }
    default:
      SystemBackground()
    }
  }

  /// Das Livebild der Kamera; am Mac gibt es keine Tafel-Kamera (`isCameraLive` wird dort nie gesetzt).
  @ViewBuilder private var cameraLive: some View {
    #if os(iOS)
      CameraLiveView()
    #else
      SystemBackground()
    #endif
  }
}

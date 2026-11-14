import SwiftUI

/// Tafel des Zweitbildschirms: zeigt die aktuelle Seite der `BoardSession` ohne Bedienelemente (FR-12).
/// Ohne Kauf eine neutrale Fläche (FR-13).
///
/// Das Livebild der Kamera (`BoardSession.isCameraLive`) schaltet Aufgabe 13 hier dazu.
struct BoardView: View {
  @Environment(Unlock.self) private var unlock
  @Environment(BoardSession.self) private var session: BoardSession?

  var body: some View {
    switch SecondScreenRendering.resolve(.board, isUnlocked: unlock.isUnlocked) {
    case .board:
      if let session, let page = session.currentPage {
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
}

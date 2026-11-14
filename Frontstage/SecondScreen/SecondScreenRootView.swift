import SwiftUI

/// Oberfläche der nicht bedienbaren Szene des Zweitbildschirms: zeigt nur an, nimmt keine Eingabe an.
struct SecondScreenRootView: View {
  let state: SecondScreenState

  var body: some View {
    ZStack {
      content
      if state.content != .dark {
        ClassScreenOverlay()
      }
    }
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }

  @ViewBuilder private var content: some View {
    switch state.content {
    case .classScreen:
      ClassScreenView()
    case .material:
      // Ohne Material nie eine leere Fläche: dann der Klassenbildschirm.
      if let material = state.material {
        PDFDisplayView(
          documentData: material.documentData, pageIndex: material.pageIndex,
          drawing: material.drawings[material.pageIndex], visibleRect: material.visibleRect)
      } else {
        ClassScreenView()
      }
    case .board:
      BoardView()
    case .dark:
      Color.black
    }
  }
}
